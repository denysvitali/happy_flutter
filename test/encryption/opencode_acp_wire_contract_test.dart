import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

void main() {
  test('legacy OpenCode events are tolerated without error rows', () {
    final result = processDecryptedMessages(
      decryptedJsonList: [
        for (final update in [
          {
            'sessionUpdate': 'agent_message_chunk',
            'content': {'type': 'text', 'text': 'Old answer'},
          },
          {
            'sessionUpdate': 'agent_thought_chunk',
            'content': {'type': 'text', 'text': 'Old thought'},
          },
          {'sessionUpdate': 'available_commands_update'},
          {'sessionUpdate': 'usage_update'},
        ])
          {
            'role': 'agent',
            'content': {
              'type': 'event',
              'data': {
                'type': 'opencode-event',
                'update': {'sessionId': 'old', 'update': update},
              },
            },
          },
      ],
      wireMessages: [
        for (var i = 0; i < 4; i++)
          {'id': 'old-$i', 'seq': i + 1, 'createdAt': 1000 + i},
      ],
      sessionId: 'old',
    );
    expect(result.messages.where((m) => m['kind'] == 'error'), isEmpty);
  });

  test(
    'captured OpenCode read turn retains thinking, call ID and wire input',
    () {
      // read_turn.jsonl: pending input is deferred by the CLI until filePath.
      final bodies = <Map<String, dynamic>>[
        {'type': 'thinking', 'text': 'The user wants me to read note.txt'},
        {
          'type': 'tool-call',
          'callId': 'read-1',
          'name': 'read',
          'kind': 'read',
          'input': {'filePath': '/workspace/note.txt'},
          'status': 'in_progress',
        },
        {
          'type': 'tool-result',
          'callId': 'read-1',
          'result': 'hello',
          'status': 'completed',
          'isError': false,
        },
        {'type': 'message', 'message': 'hello'},
      ];
      final result = _process(bodies);
      expect(result.messages, hasLength(3));
      expect(result.messages.first['isThinking'], isTrue);
      final call = result.messages[1];
      expect(call['name'], 'Read');
      expect(call['input']['file_path'], '/workspace/note.txt');
      expect(call['wireInput'], {'filePath': '/workspace/note.txt'});
      expect(call['toolUseId'], 'read-1');
      expect(result.toolResults.single['toolUseId'], call['toolUseId']);
      expect(result.toolResults.single['result'], 'hello');
      expect(result.messages.last['content'], 'hello');
    },
  );

  test('OpenCode built-ins reuse tool cards and kind fallback', () {
    const names = {
      'read': 'Read',
      'bash': 'Bash',
      'edit': 'Edit',
      'write': 'Write',
      'grep': 'Grep',
      'glob': 'Glob',
      'list': 'LS',
      'webfetch': 'WebFetch',
      'task': 'Task',
      'todowrite': 'TodoWrite',
    };
    for (final entry in names.entries) {
      final result = _process([
        {
          'type': 'tool-call',
          'callId': 'call',
          'name': entry.key,
          'input': {
            'filePath': '/a',
            'oldString': 'before',
            'newString': 'after',
          },
          'status': 'in_progress',
        },
      ]);
      expect(result.messages.single['name'], entry.value);
      expect(result.messages.single['input']['old_string'], 'before');
      expect(result.messages.single['wireInput']['oldString'], 'before');
    }
    expect(
      _process([
        {
          'type': 'tool-call',
          'callId': 'call',
          'name': 'Read workspace/note.txt',
          'kind': 'read',
          'input': {'filePath': '/a'},
        },
      ]).messages.single['name'],
      'Read',
    );
    final failure = _process([
      {
        'type': 'tool-result',
        'callId': 'call',
        'result': {'detail': 'failed'},
        'status': 'failed',
        'isError': true,
      },
    ]);
    expect(failure.toolResults.single['isError'], isTrue);
    expect(failure.toolResults.single['result'], {'detail': 'failed'});
  });
}

ProcessedMessages _process(List<Map<String, dynamic>> bodies) =>
    processDecryptedMessages(
      decryptedJsonList: [
        for (final body in bodies)
          {
            'role': 'agent',
            'content': {'type': 'opencode', 'data': body},
          },
      ],
      wireMessages: [
        for (var i = 0; i < bodies.length; i++)
          {'id': 'oc-$i', 'seq': i + 1, 'createdAt': 1000 + i},
      ],
      sessionId: 'opencode-session',
    );
