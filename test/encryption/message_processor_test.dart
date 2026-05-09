import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

void main() {
  group('processDecryptedMessages', () {
    group('empty and basic cases', () {
      test('handles empty message list', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [],
          wireMessages: [],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
        expect(result.toolResults, isEmpty);
        expect(result.usageUpdates, isEmpty);
        expect(result.maxSeq, -1);
      });

      test('tracks maxSeq', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [null],
          wireMessages: [
            {'id': 'm1', 'seq': 5},
          ],
          sessionId: 's1',
        );

        expect(result.maxSeq, 5);
      });

      test('handles null decrypted content as decryption error', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [null],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['kind'], 'error');
        expect(result.messages.first['errorType'], 'decryption_failed');
      });

      test('skips null decrypted content when not encrypted', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [null],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
          wasEncrypted: [false],
        );

        expect(result.messages, isEmpty);
      });
    });

    group('user messages', () {
      test('processes user text message', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'user',
              'content': {'type': 'text', 'text': 'Hello'},
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['role'], 'user');
        expect(result.messages.first['kind'], 'text');
        expect(result.messages.first['content'], 'Hello');
      });

      test('handles user message without nested text type', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'user',
              'content': 'Raw user content',
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['role'], 'user');
      });
    });

    group('agent messages', () {
      test('processes agent output with text', () {
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
                      {'type': 'text', 'text': 'Response'},
                    ],
                  },
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
        expect(result.messages.first['role'], 'agent');
        expect(result.messages.first['kind'], 'text');
        expect(result.messages.first['content'], 'Response');
      });

      test('processes plain-text agent message dataType', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {
                  'type': 'message',
                  'message': 'Hello from the agent',
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
        expect(result.messages.first['role'], 'agent');
        expect(result.messages.first['kind'], 'text');
        expect(result.messages.first['content'], 'Hello from the agent');
        expect(result.droppedReasons, isEmpty);
      });

      test('processes plain-text agent message via `text` field alias', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {'type': 'message', 'text': 'alt field'},
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['content'], 'alt field');
      });

      test('skips event thinking and tool-execution-update rows', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'event',
                'data': {'type': 'thinking', 'content': 'part 1'},
              },
            },
            {
              'role': 'agent',
              'content': {
                'type': 'event',
                'data': {'type': 'tool-execution-update'},
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
            {'id': 'm2', 'seq': 2, 'createdAt': 1001},
          ],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
      });

      test('processes agent output with tool_use', () {
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
                        'type': 'tool_use',
                        'id': 'tu1',
                        'name': 'Read',
                        'input': {'path': '/test'},
                      },
                    ],
                  },
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
        expect(result.messages.first['kind'], 'tool-call');
        expect(result.messages.first['name'], 'Read');
        expect(result.messages.first['state'], 'running');
        expect(result.messages.first['toolUseId'], 'tu1');
        // Regression: tool_use messages must keep the JSONL message
        // uuid (`u1`) — NOT the toolu_* block id — so descendant
        // sidechain messages chaining via `parentUuid==<JSONL uuid>`
        // can resolve through this message.  Storing the toolu_*
        // there fragmented long subagent runs into many "Subagent
        // output (recovered)" placeholders.
        expect(result.messages.first['uuid'], 'u1',
            reason: 'tool-call uuid must be the JSONL message uuid '
                "to preserve sidechain chain resolution");
      });

      test('processes agent output with toolCall blocks', () {
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
                        'type': 'toolCall',
                        'id': 'call_function_1',
                        'name': 'read',
                        'arguments': {'path': '/test'},
                      },
                    ],
                  },
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
        expect(result.messages.first['kind'], 'tool-call');
        expect(result.messages.first['name'], 'read');
        expect(result.messages.first['toolUseId'], 'call_function_1');
      });

      test('processes tool results', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {
                  'type': 'user',
                  'message': {
                    'content': [
                      {
                        'type': 'tool_result',
                        'tool_use_id': 'tu1',
                        'content': 'result data',
                        'is_error': false,
                      },
                    ],
                  },
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
        expect(result.toolResults, hasLength(1));
        expect(result.toolResults.first['toolUseId'], 'tu1');
        expect(result.toolResults.first['result'], 'result data');
        expect(result.toolResults.first['isError'], false);
      });

      test('processes top-level tool-result envelope with id field', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {
                  'type': 'tool-result',
                  'id': 'call_function_1',
                  'output': 'done',
                  'isError': false,
                  'parentUuid': 'parent-1',
                  'permissions': {'mode': 'read'},
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
        expect(result.droppedReasons, isEmpty);
        expect(result.toolResults, hasLength(1));
        expect(result.toolResults.first['toolUseId'], 'call_function_1');
        expect(result.toolResults.first['result'], 'done');
        expect(result.toolResults.first['isError'], false);
        expect(result.toolResults.first['parentUuid'], 'parent-1');
        expect(result.toolResults.first['permissions'], {'mode': 'read'});
      });

      test('ignores incomplete top-level tool-result envelope', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {
                  'type': 'tool-result',
                  'output': 'missing call id',
                  'isError': true,
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
        expect(result.toolResults, isEmpty);
        expect(result.droppedReasons, isEmpty);
      });

      test('processes result envelope toolResults list', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {
                  'type': 'result',
                  'toolResults': [
                    {
                      'toolCallId': 'call_function_1',
                      'content': [
                        {'type': 'text', 'text': 'ok'},
                      ],
                      'isError': false,
                    },
                  ],
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.toolResults, hasLength(1));
        expect(result.toolResults.first['toolUseId'], 'call_function_1');
        expect(result.toolResults.first['isError'], false);
      });

      test('processes result envelope output toolCall/toolResult rows', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {
                  'type': 'result',
                  'output': [
                    {
                      'role': 'toolCall',
                      'toolCallId': 'call_function_2',
                      'toolName': 'bash',
                      'arguments': {'command': 'ls'},
                      'status': 'completed',
                    },
                    {
                      'role': 'toolResult',
                      'toolCallId': 'call_function_2',
                      'content': [
                        {'type': 'text', 'text': 'ok'},
                      ],
                      'isError': false,
                    },
                  ],
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
        expect(result.messages.first['kind'], 'tool-call');
        expect(result.messages.first['name'], 'bash');
        expect(result.messages.first['toolUseId'], 'call_function_2');
        expect(result.messages.first['state'], 'completed');

        expect(result.toolResults, hasLength(1));
        expect(result.toolResults.first['toolUseId'], 'call_function_2');
        expect(result.toolResults.first['isError'], false);
      });

      test('processes thinking blocks', () {
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
                      {'type': 'thinking', 'thinking': 'Thinking text'},
                    ],
                  },
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
        expect(result.messages.first['isThinking'], true);
        expect(result.messages.first['content'], contains('Thinking text'));
      });

      test('skips isMeta messages', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {
                  'type': 'assistant',
                  'isMeta': true,
                  'uuid': 'u1',
                  'message': {
                    'content': [
                      {'type': 'text', 'text': 'meta'},
                    ],
                  },
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
      });

      test('emits error for unknown agent content type', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'unknown_type',
                'data': {'foo': 'bar'},
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['kind'], 'error');
        expect(result.messages.first['errorType'], 'unknown_agent_content_type');
      });

      test('emits error for unknown role', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'stranger',
              'content': 'test',
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['kind'], 'error');
        expect(result.messages.first['errorType'], 'unknown_role');
      });
    });

    group('pi content', () {
      test('processes pi assistant with tool_use block', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'pi',
                'data': {
                  'type': 'assistant',
                  'uuid': 'u1',
                  'message': {
                    'content': [
                      {
                        'type': 'tool_use',
                        'id': 'tu1',
                        'name': 'bash',
                        'input': {'command': 'echo hello'},
                      },
                    ],
                  },
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
        expect(result.messages.first['kind'], 'tool-call');
        expect(result.messages.first['name'], 'bash');
        expect(result.messages.first['state'], 'running');
        expect(result.messages.first['toolUseId'], 'tu1');
        expect(result.messages.first['input']['command'], 'echo hello');
      });

      test('processes pi assistant with text block', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'pi',
                'data': {
                  'type': 'assistant',
                  'uuid': 'u1',
                  'message': {
                    'content': [
                      {'type': 'text', 'text': 'Hello, how can I help?'},
                    ],
                  },
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
        expect(result.messages.first['kind'], 'text');
        expect(result.messages.first['content'], 'Hello, how can I help?');
        expect(result.messages.first['isThinking'], isNull);
      });

      test('processes pi assistant with thinking block', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'pi',
                'data': {
                  'type': 'assistant',
                  'uuid': 'u1',
                  'message': {
                    'content': [
                      {
                        'type': 'thinking',
                        'thinking':
                            'The user wants me to check something',
                      },
                    ],
                  },
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
        expect(result.messages.first['isThinking'], true);
        expect(
          result.messages.first['content'],
          contains('The user wants me to check something'),
        );
      });

      test('processes pi assistant with tool_result block', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'pi',
                'data': {
                  'type': 'assistant',
                  'uuid': 'u1',
                  'message': {
                    'content': [
                      {
                        'type': 'tool_result',
                        'tool_use_id': 'tu1',
                        'content': 'output of tool',
                        'is_error': false,
                      },
                    ],
                  },
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
        expect(result.toolResults, hasLength(1));
        expect(result.toolResults.first['toolUseId'], 'tu1');
        expect(result.toolResults.first['result'], 'output of tool');
        expect(result.toolResults.first['isError'], false);
      });

      test('processes pi assistant with mixed content blocks', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'pi',
                'data': {
                  'type': 'assistant',
                  'uuid': 'u1',
                  'message': {
                    'content': [
                      {'type': 'thinking', 'thinking': 'Let me think...'},
                      {
                        'type': 'tool_use',
                        'id': 'tu1',
                        'name': 'readFile',
                        'input': {'path': '/test.txt'},
                      },
                      {'type': 'text', 'text': 'I read the file for you.'},
                    ],
                  },
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        // 3 blocks: thinking, tool_use, text
        expect(result.messages, hasLength(3));
        expect(result.messages[0]['isThinking'], true);
        expect(result.messages[1]['kind'], 'tool-call');
        expect(result.messages[1]['name'], 'readFile');
        expect(result.messages[2]['kind'], 'text');
        expect(result.messages[2]['content'], 'I read the file for you.');
      });

      test('drops pi assistant with unhandled dataType (legacy tool-call)', () {
        // The old 'tool-call' dataType path should still work
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'pi',
                'data': {
                  'type': 'tool-call',
                  'toolName': 'bash',
                  'args': {'command': 'ls'},
                  'callId': 'call1',
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
        expect(result.messages.first['kind'], 'tool-call');
        expect(result.messages.first['name'], 'bash');
      });
    });

    group('event content', () {
      test('processes non-ready events', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'event',
                'data': {'type': 'switch', 'mode': 'remote'},
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['kind'], 'agent-event');
        expect(result.messages.first['event']['type'], 'switch');
      });

      test('skips ready events', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'event',
                'data': {'type': 'ready'},
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
      });
    });

    group('codex content', () {
      test('processes codex message', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'codex',
                'data': {
                  'type': 'message',
                  'message': 'Codex output',
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
        expect(result.messages.first['content'], 'Codex output');
      });

      test('processes codex tool-call', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'codex',
                'data': {
                  'type': 'tool-call',
                  'name': 'bash',
                  'input': {'cmd': 'ls'},
                  'callId': 'call1',
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
        expect(result.messages.first['kind'], 'tool-call');
        expect(result.messages.first['name'], 'bash');
      });

      test('processes codex tool-call-result', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'codex',
                'data': {
                  'type': 'tool-call-result',
                  'callId': 'call1',
                  'output': 'file list',
                  'isError': false,
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.toolResults, hasLength(1));
        expect(result.toolResults.first['toolUseId'], 'call1');
        expect(result.toolResults.first['result'], 'file list');
      });

      test('processes real codex MCP tool-call and structured result', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'codex',
                'data': {
                  'type': 'tool-call',
                  'name': 'list_mcp_resources',
                  'input': {
                    'server': 'codex',
                    'arguments': <String, dynamic>{},
                  },
                  'callId': 'mcp1',
                },
              },
            },
            {
              'role': 'agent',
              'content': {
                'type': 'codex',
                'data': {
                  'type': 'tool-call-result',
                  'callId': 'mcp1',
                  'output': {
                    'content': [
                      {'type': 'text', 'text': '{"resources":[]}'},
                    ],
                    'structuredContent': {
                      'resources': <dynamic>[],
                    },
                  },
                  'isError': false,
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
            {'id': 'm2', 'seq': 2, 'createdAt': 1001},
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['kind'], 'tool-call');
        expect(result.messages.first['name'], 'list_mcp_resources');
        expect(result.messages.first['toolUseId'], 'mcp1');

        expect(result.toolResults, hasLength(1));
        expect(result.toolResults.first['toolUseId'], 'mcp1');
        expect(
          result.toolResults.first['result'],
          {
            'content': [
              {'type': 'text', 'text': '{"resources":[]}'},
            ],
            'structuredContent': {
              'resources': <dynamic>[],
            },
          },
        );
      });
    });

    group('pi content', () {
      test('skips placeholder tool_use rows with empty name/input', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'pi',
                'data': {
                  'type': 'assistant',
                  'id': 'pi-msg-1',
                  'message': {
                    'content': [
                      {
                        'id': 'pi_1_1',
                        'type': 'tool_use',
                        'name': '',
                        'input': null,
                        'inputText': '(map[])',
                      },
                    ],
                  },
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
      });
    });

    group('ACP content', () {
      test('processes ACP message', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'acp',
                'data': {
                  'type': 'message',
                  'message': 'ACP output',
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
        expect(result.messages.first['content'], 'ACP output');
      });

      test('processes ACP thinking', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'acp',
                'data': {
                  'type': 'thinking',
                  'text': 'ACP thinking',
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
        expect(result.messages.first['isThinking'], true);
        expect(result.messages.first['content'], contains('ACP thinking'));
      });

      test('processes ACP file-edit', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'acp',
                'data': {
                  'type': 'file-edit',
                  'id': 'edit1',
                  'filePath': '/test.dart',
                  'description': 'Fix bug',
                  'diff': '-old\n+new',
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
        expect(result.messages.first['kind'], 'tool-call');
        expect(result.messages.first['name'], 'file-edit');
      });
    });

    group('session content', () {
      test('processes session envelope text event', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'session',
                'data': {
                  'id': 'ev1',
                  'time': 1000,
                  'role': 'agent',
                  'ev': {'t': 'text', 'text': 'Session reply'},
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
        expect(result.messages.first['content'], 'Session reply');
      });

      test('processes session tool-call-start event', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'session',
                'data': {
                  'id': 'ev1',
                  'time': 1000,
                  'role': 'agent',
                  'ev': {
                    't': 'tool-call-start',
                    'name': 'Bash',
                    'call': 'tc1',
                    'args': {'cmd': 'ls'},
                  },
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
        expect(result.messages.first['kind'], 'tool-call');
        expect(result.messages.first['name'], 'Bash');
        expect(result.messages.first['state'], 'running');
      });

      test('processes session tool-call-end event', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'session',
                'data': {
                  'id': 'ev2',
                  'time': 1000,
                  'role': 'agent',
                  'ev': {
                    't': 'tool-call-end',
                    'call': 'tc1',
                    'result': 'output',
                    'isError': false,
                  },
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.toolResults, hasLength(1));
        expect(result.toolResults.first['toolUseId'], 'tc1');
        expect(result.toolResults.first['result'], 'output');
      });

      test('skips turn-start and turn-end events', () {
        final startResult = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'session',
                'data': {
                  'id': 'ev1',
                  'time': 1000,
                  'ev': {'t': 'turn-start'},
                },
              },
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        // turn-start is silently skipped
        expect(startResult.messages, isEmpty);
      });
    });

    group('non-map content', () {
      test('handles string content', () {
        final result = processDecryptedMessages(
          decryptedJsonList: ['just a string'],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['kind'], 'text');
        expect(result.messages.first['content'], 'just a string');
      });

      test('handles number content', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [42],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['content'], '42');
      });
    });

    group('wire message fields', () {
      test('preserves id, seq, localId, createdAt', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {'role': 'user', 'content': {'type': 'text', 'text': 'Hi'}},
          ],
          wireMessages: [
            {
              'id': 'msg123',
              'seq': 42,
              'localId': 'local456',
              'createdAt': 1700000000000,
            },
          ],
          sessionId: 's1',
        );

        final msg = result.messages.first;
        expect(msg['id'], 'msg123');
        expect(msg['seq'], 42);
        expect(msg['localId'], 'local456');
        expect(msg['createdAt'], 1700000000000);
      });

      test('parses createdAt from ISO string', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {'role': 'user', 'content': {'type': 'text', 'text': 'Hi'}},
          ],
          wireMessages: [
            {
              'id': 'msg1',
              'seq': 1,
              'createdAt': '2024-01-15T10:30:00.000Z',
            },
          ],
          sessionId: 's1',
        );

        expect(result.messages.first['createdAt'], isA<int>());
      });

      test('uses current time for invalid createdAt', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {'role': 'user', 'content': {'type': 'text', 'text': 'Hi'}},
          ],
          wireMessages: [
            {'id': 'msg1', 'seq': 1, 'createdAt': 'invalid'},
          ],
          sessionId: 's1',
        );

        expect(result.messages.first['createdAt'], isA<int>());
      });
    });

    group('ProcessedMessages', () {
      test('stores all fields', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'user',
              'content': {'type': 'text', 'text': 'test'},
            },
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 5, 'createdAt': 1000},
          ],
          sessionId: 's1',
        );

        expect(result.messages, isNotEmpty);
        expect(result.toolResults, isEmpty);
        expect(result.usageUpdates, isEmpty);
        expect(result.maxSeq, 5);
      });
    });
  });
}
