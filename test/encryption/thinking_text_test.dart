import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

void main() {
  test('assistant with thinking + text produces both messages', () {
    final result = processDecryptedMessages(
      decryptedJsonList: [
        {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'u1',
              'message': {
                'content': [
                  {
                    'type': 'thinking',
                    'thinking': 'Let me think about this...',
                  },
                  {
                    'type': 'text',
                    'text': 'Here is my answer.',
                  },
                ],
              },
            },
          },
        },
      ],
      wireMessages: [
        {'id': 'm1', 'seq': 937, 'createdAt': 1774195704000},
      ],
      sessionId: 's1',
    );

    // Should produce 2 messages: thinking + text
    expect(result.messages.length, 2);

    final thinking = result.messages[0];
    expect(thinking['isThinking'], true);
    expect(thinking['id'], 'm1_k0');
    expect(thinking['content'], contains('Let me think'));

    final text = result.messages[1];
    expect(text['isThinking'], isNull);
    expect(text['id'], 'm1_t1');
    expect(text['content'], 'Here is my answer.');
  });

  test('assistant with ONLY thinking, no text block', () {
    final result = processDecryptedMessages(
      decryptedJsonList: [
        {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'u1',
              'message': {
                'content': [
                  {
                    'type': 'thinking',
                    'thinking': 'Let me think about ArgoCD...',
                  },
                ],
              },
            },
          },
        },
      ],
      wireMessages: [
        {'id': 'm1', 'seq': 937, 'createdAt': 1774195704000},
      ],
      sessionId: 's1',
    );

    // Only 1 message: just thinking
    expect(result.messages.length, 1);
    expect(result.messages[0]['isThinking'], true);
  });

  test('text block with empty text still creates message', () {
    final result = processDecryptedMessages(
      decryptedJsonList: [
        {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'u1',
              'message': {
                'content': [
                  {
                    'type': 'thinking',
                    'thinking': 'Thinking...',
                  },
                  {
                    'type': 'text',
                    'text': '',
                  },
                ],
              },
            },
          },
        },
      ],
      wireMessages: [
        {'id': 'm1', 'seq': 937, 'createdAt': 1774195704000},
      ],
      sessionId: 's1',
    );

    expect(result.messages.length, 2);
    expect(result.messages[1]['content'], '');
  });

  test('unrecognized content types are silently skipped', () {
    final result = processDecryptedMessages(
      decryptedJsonList: [
        {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'assistant',
              'uuid': 'u1',
              'message': {
                'content': [
                  {
                    'type': 'thinking',
                    'thinking': 'Let me think...',
                  },
                  {
                    'type': 'server_tool_use',
                    'id': 'st1',
                    'name': 'web_search',
                  },
                  {
                    'type': 'redacted_thinking',
                    'data': 'xxxxx',
                  },
                  {
                    'type': 'text',
                    'text': 'Final answer here.',
                  },
                ],
              },
            },
          },
        },
      ],
      wireMessages: [
        {'id': 'm1', 'seq': 937, 'createdAt': 1774195704000},
      ],
      sessionId: 's1',
    );

    // Only thinking + text, skips server_tool_use and redacted_thinking
    expect(result.messages.length, 2);
    expect(result.messages[0]['isThinking'], true);
    expect(result.messages[1]['content'], 'Final answer here.');
  });
}
