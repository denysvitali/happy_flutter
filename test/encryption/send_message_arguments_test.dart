import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/wire/send_message_arguments.dart';

void main() {
  group('SendMessageArguments', () {
    test('prefers message and recipient in nested JSON arguments', () {
      final args = SendMessageArguments.from(
        '{"arguments":{"content":"legacy","message":"hello",'
        '"to":"old","recipient":"worker"}}',
      );

      expect(args.message, 'hello');
      expect(args.recipient, 'worker');
      expect(args.input['content'], 'legacy');
      expect(args.subtitle, 'worker: hello');
    });

    test('accepts content and to fallbacks', () {
      final args = SendMessageArguments.from({
        'content': 'continue',
        'to': 'agent-2',
      });

      expect(args.message, 'continue');
      expect(args.recipient, 'agent-2');
    });

    test('recognizes qualified provider tool names', () {
      expect(SendMessageArguments.isToolName('SendMessage'), isTrue);
      expect(
        SendMessageArguments.isToolName('mcp__collab__send_message'),
        isTrue,
      );
      expect(SendMessageArguments.isToolName('Bash'), isFalse);
    });

    test('unwraps MCP content blocks in result', () {
      final text = sendMessageResultText([
        {'type': 'text', 'text': '{"success":true,"message":"Message queued"}'},
        {'type': 'resource_link', 'uri': 'happy://agent/abc'},
      ]);

      expect(text, 'Message queued');
    });
    test('handles malformed or non-map input without throwing', () {
      final args = SendMessageArguments.from('["not", "an", "object"]');

      expect(args.input, isEmpty);
      expect(args.message, isNull);
      expect(args.recipient, isNull);
      expect(sendMessageResultText({'status': 'delivered'}), 'delivered');
    });
  });

  test(
    'normalizes Codex SendMessage tool-call input and preserves identity',
    () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          {
            'role': 'agent',
            'content': {
              'type': 'codex',
              'data': {
                'type': 'tool-call',
                'name': 'SendMessage',
                'arguments':
                    '{"arguments":{"to":"reviewer",'
                    '"content":"Check this"}}',
                'callId': 'send-1',
              },
            },
          },
        ],
        wireMessages: [
          {'id': 'm1', 'seq': 1, 'createdAt': 1000},
        ],
        sessionId: 's1',
      );

      expect(result.messages, hasLength(1));
      expect(result.messages.first['name'], 'SendMessage');
      expect(result.messages.first['input'], {
        'to': 'reviewer',
        'content': 'Check this',
      });
      expect(result.messages.first['toolUseId'], 'send-1');
    },
  );
}
