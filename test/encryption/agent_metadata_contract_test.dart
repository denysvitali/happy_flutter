import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

void main() {
  const metadata = <String, dynamic>{
    'role': 'explorer',
    'model': 'gpt-6-luna',
    'reasoningEffort': 'high',
    'source': 'thread',
    'futureField': 'retained',
  };

  for (final type in [
    'message',
    'reasoning',
    'model-output',
    'thinking',
    'tool-call',
  ]) {
    test('Codex $type retains child metadata and grouping identity', () {
      final data = <String, dynamic>{
        'type': type,
        'message': 'Child response',
        'text': 'Child thought',
        'toolName': 'Read',
        'args': <String, dynamic>{'file_path': 'file.dart'},
        'callId': 'read-call',
        'parentToolUseId': 'agent-call',
        'agentId': 'child-thread',
        'isSidechain': true,
        'agentMetadata': metadata,
      };
      final outer = <String, dynamic>{
        'role': 'agent',
        'content': <String, dynamic>{'type': 'codex', 'data': data},
      };
      final processed = processDecryptedMessages(
        decryptedJsonList: [outer],
        wireMessages: [
          {'id': 'child', 'seq': 1, 'createdAt': 1000},
        ],
        sessionId: 'session',
      );
      final child = processed.messages.single;
      expect(child['agentMetadata'], metadata);
      expect(child['parentToolUseId'], 'agent-call');
      expect(child['agentId'], 'child-thread');
      expect(child['isSidechain'], true);
      expect(child['raw'], outer);
    });
  }

  test('terminal Agent result retains metadata inside result', () {
    final result = <String, dynamic>{
      'status': 'completed',
      'agentMetadata': metadata,
    };
    final processed = processDecryptedMessages(
      decryptedJsonList: [
        {
          'role': 'agent',
          'content': {
            'type': 'codex',
            'data': {
              'type': 'tool-result',
              'callId': 'agent-call',
              'result': result,
            },
          },
        },
      ],
      wireMessages: [
        {'id': 'result', 'seq': 2, 'createdAt': 2000},
      ],
      sessionId: 'session',
    );
    expect(processed.toolResults.single['result'], result);
  });

  test('child tool result retains its metadata snapshot', () {
    final processed = processDecryptedMessages(
      decryptedJsonList: [
        {
          'role': 'agent',
          'content': {
            'type': 'codex',
            'data': {
              'type': 'tool-result',
              'callId': 'read-call',
              'result': 'Contents',
              'agentMetadata': metadata,
              'isSidechain': true,
              'parentToolUseId': 'agent-call',
            },
          },
        },
      ],
      wireMessages: [
        {'id': 'result', 'seq': 1, 'createdAt': 1000},
      ],
      sessionId: 'session',
    );
    expect(processed.toolResults.single['agentMetadata'], metadata);
    expect(processed.toolResults.single['result'], 'Contents');
  });
}
