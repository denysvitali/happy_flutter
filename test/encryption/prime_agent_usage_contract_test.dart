import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

void main() {
  test('Prime ACP usage is auxiliary and stamps the wire timestamp', () {
    // Captured Prime 0.10.0 real Luna run, final emitted usage snapshot.
    const usage = <String, dynamic>{
      'cache_creation_input_tokens': 0,
      'cache_read_input_tokens': 60416,
      'context_size': 11949,
      'context_window': 500000,
      'input_tokens': 78496,
      'output_tokens': 883,
      'total_tokens': 139795,
      'total_cost_usd': 0.00889526,
      'scope': 'session',
      'source': 'prime-agent-daemon',
      'context_is_estimate': true,
      'model': 'gpt-6-luna',
      'provider': 'openai-codex',
    };
    final processed = processDecryptedMessages(
      decryptedJsonList: [
        {
          'role': 'agent',
          'content': {
            'type': 'acp',
            'data': {'type': 'usage', 'usage': usage},
          },
        },
      ],
      wireMessages: [
        {'id': 'prime-usage', 'seq': 17, 'createdAt': 123456789},
      ],
      sessionId: 'prime-session',
    );
    expect(processed.messages, isEmpty);
    expect(processed.toolResults, isEmpty);
    expect(processed.droppedReasons, isEmpty);
    expect(processed.maxSeq, 17);
    expect(processed.usageUpdates, [
      {
        'sessionId': 'prime-session',
        'usage': usage,
        'timestamp': 123456789,
        'seq': 17,
      },
    ]);
  });
}
