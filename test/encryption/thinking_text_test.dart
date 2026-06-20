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
                  {'type': 'text', 'text': 'Here is my answer.'},
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
                  {'type': 'thinking', 'thinking': 'Thinking...'},
                  {'type': 'text', 'text': ''},
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

  test('server_tool_use creates tool-call, redacted_thinking skipped', () {
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
                  {'type': 'thinking', 'thinking': 'Let me think...'},
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
                  {'type': 'redacted_thinking', 'data': 'xxxxx'},
                  {'type': 'text', 'text': 'Final answer here.'},
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

  test('top-level web_search_call creates web search tool-call', () {
    final result = processDecryptedMessages(
      decryptedJsonList: [
        {
          'role': 'agent',
          'content': {
            'type': 'output',
            'data': {
              'type': 'web_search_call',
              'id': 'ws1',
              'status': 'completed',
              'action': {
                'type': 'search',
                'queries': ['flutter release notes'],
                'sources': [
                  {
                    'title': 'Flutter docs',
                    'url': 'https://docs.flutter.dev/release',
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

    expect(result.messages.length, 1);
    expect(result.messages[0]['kind'], 'tool-call');
    expect(result.messages[0]['name'], 'web_search');
    expect(result.messages[0]['toolUseId'], 'ws1');
    expect(result.messages[0]['state'], 'completed');
    expect(result.messages[0]['input'], {'query': 'flutter release notes'});
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
                  {'type': 'text', 'text': 'The weather is sunny.'},
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

  group('inline   tags in text blocks', () {
    test('trailing think tag splits into text + thinking messages', () {
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
                      'type': 'text',
                      'text':
                          'Here is my answer. '
                          'Reasoning about the user request.',
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

      final text = result.messages[0];
      expect(text['isThinking'], isNull);
      expect(text['content'], 'Here is my answer.');
      expect(text['id'], 'm1_t0_t0');

      final thinking = result.messages[1];
      expect(thinking['isThinking'], true);
      expect(
        thinking['content'],
        contains('Reasoning about the user request.'),
      );
      expect(thinking['id'], 'm1_t0_k0');
    });

    test('mid-text think tag splits into text + thinking + text', () {
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
                      'type': 'text',
                      'text':
                          'Before.  step one  After.',
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

      expect(result.messages.length, 3);

      expect(result.messages[0]['isThinking'], isNull);
      expect(result.messages[0]['content'], 'Before.');
      expect(result.messages[0]['id'], 'm1_t0_t0');

      expect(result.messages[1]['isThinking'], true);
      expect(result.messages[1]['content'], contains('step one'));
      expect(result.messages[1]['id'], 'm1_t0_k0');

      expect(result.messages[2]['isThinking'], isNull);
      expect(result.messages[2]['content'], 'After.');
      expect(result.messages[2]['id'], 'm1_t0_t1');
    });

    test('multiple think tags each emit a separate thinking message', () {
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
                      'type': 'text',
                      'text':
                          'A.  one  B.  two  C.',
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

      // 5 segments: A. / think(one) / B. / think(two) / C.
      expect(result.messages.length, 5);
      expect(result.messages[0]['content'], 'A.');
      expect(result.messages[0]['id'], 'm1_t0_t0');
      expect(result.messages[1]['isThinking'], true);
      expect(result.messages[1]['content'], contains('one'));
      expect(result.messages[1]['id'], 'm1_t0_k0');
      expect(result.messages[2]['content'], 'B.');
      expect(result.messages[2]['id'], 'm1_t0_t1');
      expect(result.messages[3]['isThinking'], true);
      expect(result.messages[3]['content'], contains('two'));
      expect(result.messages[3]['id'], 'm1_t0_k1');
      expect(result.messages[4]['content'], 'C.');
      expect(result.messages[4]['id'], 'm1_t0_t2');
    });

    test('empty think tag is dropped', () {
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
                      'type': 'text',
                      'text': 'Hello.  World.',
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

      // Empty think tag should be dropped; the two text fragments
      // collapse into a single cleaned text message because both
      // surrounding segments are text-only with no thinking present.
      // (The trim trims the empty think away, leaving only 'Hello.' and
      // 'World.' as separate text segments — both kept.)
      expect(result.messages.length, 2);
      expect(result.messages[0]['isThinking'], isNull);
      expect(result.messages[1]['isThinking'], isNull);
    });

    test('text containing only a think tag emits one thinking message', () {
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
                      'type': 'text',
                      'text': '  only reasoning  ',
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

      expect(result.messages.length, 1);
      expect(result.messages[0]['isThinking'], true);
      expect(result.messages[0]['content'], contains('only reasoning'));
      expect(result.messages[0]['id'], 'm1_t0_k0');
    });

    test('unclosed think tag leaves the literal tag visible', () {
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
                      'type': 'text',
                      'text': 'hello  world',
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

      // Unclosed   → no match → single text message with the raw
      // text preserved so the user still sees the literal tag.
      expect(result.messages.length, 1);
      expect(result.messages[0]['isThinking'], isNull);
      expect(result.messages[0]['content'], 'hello  world');
      expect(result.messages[0]['id'], 'm1_t0');
    });

    test('text without think tags is unchanged (single message)', () {
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
                    {'type': 'text', 'text': 'Plain answer.'},
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

      expect(result.messages.length, 1);
      expect(result.messages[0]['isThinking'], isNull);
      expect(result.messages[0]['content'], 'Plain answer.');
      expect(result.messages[0]['id'], 'm1_t0');
    });

    test('inline think tags in dataType=message plain-text branch', () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          {
            'role': 'agent',
            'content': {
              'type': 'output',
              'data': {
                'type': 'message',
                'message':
                    'Final answer.  wrap up reasoning',
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
      expect(result.messages[0]['isThinking'], isNull);
      expect(result.messages[0]['content'], 'Final answer.');
      expect(result.messages[0]['id'], 'm1_t0');

      expect(result.messages[1]['isThinking'], true);
      expect(result.messages[1]['content'], contains('wrap up reasoning'));
      expect(result.messages[1]['id'], 'm1_k0');
    });
  });
}
