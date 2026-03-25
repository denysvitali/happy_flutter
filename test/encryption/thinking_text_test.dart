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

  test('server_tool_use creates tool-call, redacted_thinking skipped',
      () {
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
                    'input': {'query': 'flutter'},
                  },
                  {
                    'type': 'web_search_tool_result',
                    'tool_use_id': 'st1',
                    'content': [
                      {'type': 'text', 'text': 'results'},
                    ],
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

    // thinking + server_tool_use (tool-call) + text = 3 messages
    // redacted_thinking skipped, web_search_tool_result extracted
    expect(result.messages.length, 3);
    expect(result.messages[0]['isThinking'], true);
    expect(result.messages[1]['kind'], 'tool-call');
    expect(result.messages[1]['name'], 'web_search');
    expect(result.messages[1]['toolUseId'], 'st1');
    expect(result.messages[2]['content'], 'Final answer here.');

    // Tool result extracted for matching
    expect(result.toolResults.length, 1);
    expect(result.toolResults[0]['toolUseId'], 'st1');
  });

  test('mcp_tool_use creates tool-call with result', () {
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
                    'type': 'mcp_tool_use',
                    'id': 'mcp1',
                    'name': 'get_weather',
                    'server_name': 'weather-server',
                    'input': {'city': 'Amsterdam'},
                  },
                  {
                    'type': 'mcp_tool_result',
                    'tool_use_id': 'mcp1',
                    'content': 'Sunny, 20°C',
                  },
                  {
                    'type': 'text',
                    'text': 'The weather is sunny.',
                  },
                ],
              },
            },
          },
        },
      ],
      wireMessages: [
        {'id': 'm2', 'seq': 10, 'createdAt': 1774195704000},
      ],
      sessionId: 's1',
    );

    expect(result.messages.length, 2);
    expect(result.messages[0]['kind'], 'tool-call');
    expect(result.messages[0]['name'], 'get_weather');
    expect(result.messages[0]['toolUseId'], 'mcp1');
    expect(result.messages[1]['content'], 'The weather is sunny.');

    expect(result.toolResults.length, 1);
    expect(result.toolResults[0]['toolUseId'], 'mcp1');
  });
}
