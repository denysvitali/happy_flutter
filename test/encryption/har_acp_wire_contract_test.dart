import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

void main() {
  test('Har ACP text and delegation match tool lifecycle IDs and failures', () {
    final bodies = <Map<String, dynamic>>[
      {'type': 'message', 'message': 'Har answer'},
      {
        'type': 'tool-call',
        'callId': 'call_1',
        'title': 'delegate',
        'input': {'task': 'inspect'},
        'rawInput': {'task': 'inspect'},
        'status': 'in_progress',
        '_meta': {
          'har': {
            'seq': 1,
            'tool': {
              'id': 'call_1',
              'name': 'delegate',
              'arguments': '{"task":"inspect"}',
            },
          },
        },
      },
      {
        'type': 'tool-result',
        'callId': 'call_1',
        'status': 'failed',
        'isError': true,
        'effect': 'unknown',
        'result': [
          {
            'type': 'content',
            'content': {
              'type': 'text',
              'text': '{"effect":"unknown","failed":true}',
            },
          },
        ],
        '_meta': {
          'har': {
            'seq': 2,
            'tool': {
              'id': 'call_1',
              'name': 'delegate',
              'result': {
                'effect': 'unknown',
                'output': '{"effect":"unknown","failed":true}',
                'failed': true,
              },
            },
          },
        },
      },
    ];
    final result = processDecryptedMessages(
      decryptedJsonList: [
        for (final body in bodies)
          {
            'role': 'agent',
            'content': {'type': 'acp', 'data': body},
            'meta': {
              'model': 'codex/gpt-6-luna',
              'permissionMode': 'bypassPermissions',
            },
          },
      ],
      wireMessages: [
        for (var i = 0; i < bodies.length; i++)
          {'id': 'har-$i', 'seq': i + 1, 'createdAt': 1000 + i},
      ],
      sessionId: 'har-session',
    );
    expect(result.messages, hasLength(2));
    expect(result.messages.first['content'], 'Har answer');
    expect(result.messages.last['name'], 'delegate');
    expect(result.messages.last['state'], 'running');
    expect(result.messages.last['toolUseId'], 'call_1');
    expect(result.messages.where((m) => m['kind'] == 'error'), isEmpty);
    expect(result.toolResults, hasLength(1));
    expect(result.toolResults.single['toolUseId'], 'call_1');
    expect(result.toolResults.single['isError'], isTrue);
    expect(result.toolResults.single['result'].toString(), contains('unknown'));
  });
}
