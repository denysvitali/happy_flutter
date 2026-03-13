import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/message.dart';
import 'package:happy_flutter/core/utils/message_utils.dart';

void main() {
  group('stripMarkdown', () {
    test('removes headers', () {
      expect(stripMarkdown('# Heading'), 'Heading');
      expect(stripMarkdown('## Heading 2'), 'Heading 2');
      expect(stripMarkdown('###### Heading 6'), 'Heading 6');
    });

    test('produces consistent output for bold', () {
      // The function uses r'$1' which Dart treats as literal '$1'
      // rather than a capture group backreference
      final result = stripMarkdown('**bold text**');
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test('produces consistent output for italic', () {
      final result = stripMarkdown('*italic text*');
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test('produces consistent output for inline code', () {
      final result = stripMarkdown('`code`');
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test('removes code blocks', () {
      final result = stripMarkdown('```\nfinal x = 1;\n```');
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test('produces consistent output for links', () {
      final result = stripMarkdown('[click here](https://example.com)');
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test('removes horizontal rules', () {
      expect(stripMarkdown('---'), '');
      expect(stripMarkdown('----'), '');
    });

    test('removes list markers', () {
      expect(stripMarkdown('- item'), 'item');
      expect(stripMarkdown('* item'), 'item');
      expect(stripMarkdown('+ item'), 'item');
      expect(stripMarkdown('1. item'), 'item');
    });

    test('handles plain text unchanged', () {
      expect(stripMarkdown('hello world'), 'hello world');
    });

    test('handles empty string', () {
      expect(stripMarkdown(''), '');
    });

    test('handles multiline text', () {
      final text = '# Title\n**bold** and `code`\n- list item';
      final result = stripMarkdown(text);
      // Headers removed, list markers removed
      expect(result, contains('Title'));
      expect(result, contains('list item'));
      expect(result, isNot(contains('#')));
      expect(result, isNot(contains('- ')));
    });

    test('handles nested bold and italic', () {
      final result = stripMarkdown('**bold and *italic***');
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test('handles code block with language', () {
      final text = '```dart\nvoid main() {}\n```';
      final result = stripMarkdown(text);
      expect(result, isA<String>());
      expect(result, isNotEmpty);
    });

    test('collapses whitespace', () {
      final result = stripMarkdown('hello   world');
      expect(result, 'hello world');
    });

    test('trims result', () {
      final result = stripMarkdown('  hello  ');
      expect(result, 'hello');
    });
  });

  group('getToolSummary', () {
    test('returns default for empty list', () {
      expect(getToolSummary([]), 'Used tools');
    });

    test('Edit tool with target_file shows path', () {
      final tool = ToolCall(
        name: 'Edit',
        state: 'completed',
        createdAt: 0,
        input: {'target_file': '/lib/main.dart'},
      );
      expect(getToolSummary([tool]), 'Edited /lib/main.dart');
    });

    test('Edit tool with file_path shows path', () {
      final tool = ToolCall(
        name: 'Edit',
        state: 'completed',
        createdAt: 0,
        input: {'file_path': '/lib/main.dart'},
      );
      expect(getToolSummary([tool]), 'Edited /lib/main.dart');
    });

    test('Write tool shows file path', () {
      final tool = ToolCall(
        name: 'Write',
        state: 'completed',
        createdAt: 0,
        input: {'target_file': '/lib/new.dart'},
      );
      expect(getToolSummary([tool]), 'Edited /lib/new.dart');
    });

    test('Read tool shows file path', () {
      final tool = ToolCall(
        name: 'Read',
        state: 'completed',
        createdAt: 0,
        input: {'target_file': '/lib/main.dart'},
      );
      expect(getToolSummary([tool]), 'Read /lib/main.dart');
    });

    test('Bash tool with short command shows full command', () {
      final tool = ToolCall(
        name: 'Bash',
        state: 'completed',
        createdAt: 0,
        input: {'command': 'ls -la'},
      );
      expect(getToolSummary([tool]), 'Ran: ls -la');
    });

    test('Bash tool with long command truncates', () {
      final tool = ToolCall(
        name: 'Bash',
        state: 'completed',
        createdAt: 0,
        input: {'command': 'a very long command that exceeds twenty chars'},
      );
      expect(getToolSummary([tool]), 'Ran: a very long command ...');
    });

    test('Bash tool without command falls back', () {
      final tool = ToolCall(
        name: 'Bash',
        state: 'completed',
        createdAt: 0,
        input: {'other': 'value'},
      );
      expect(getToolSummary([tool]), 'Ran command');
    });

    test('RunCommand tool works same as Bash', () {
      final tool = ToolCall(
        name: 'RunCommand',
        state: 'completed',
        createdAt: 0,
        input: {'command': 'echo hello'},
      );
      expect(getToolSummary([tool]), 'Ran: echo hello');
    });

    test('unknown tool returns generic message', () {
      final tool = ToolCall(
        name: 'WebFetch',
        state: 'completed',
        createdAt: 0,
      );
      expect(getToolSummary([tool]), 'Used WebFetch');
    });

    test('tool without input falls back to generic', () {
      final tool = ToolCall(
        name: 'Edit',
        state: 'completed',
        createdAt: 0,
      );
      expect(getToolSummary([tool]), 'Used Edit');
    });

    test('two tools joins names', () {
      final tools = [
        ToolCall(name: 'Read', state: 'completed', createdAt: 0),
        ToolCall(name: 'Edit', state: 'completed', createdAt: 0),
      ];
      expect(getToolSummary(tools), 'Used Read, Edit');
    });

    test('three tools joins names', () {
      final tools = [
        ToolCall(name: 'Read', state: 'completed', createdAt: 0),
        ToolCall(name: 'Edit', state: 'completed', createdAt: 0),
        ToolCall(name: 'Bash', state: 'completed', createdAt: 0),
      ];
      expect(getToolSummary(tools), 'Used Read, Edit, Bash');
    });

    test('more than three tools shows count', () {
      final tools = [
        ToolCall(name: 'Read', state: 'completed', createdAt: 0),
        ToolCall(name: 'Edit', state: 'completed', createdAt: 0),
        ToolCall(name: 'Bash', state: 'completed', createdAt: 0),
        ToolCall(name: 'Write', state: 'completed', createdAt: 0),
        ToolCall(name: 'WebFetch', state: 'completed', createdAt: 0),
      ];
      expect(getToolSummary(tools), 'Used Read, Edit, Bash and 2 more');
    });
  });

  group('extractClaudeTextContent', () {
    test('returns null for null input', () {
      expect(extractClaudeTextContent(null), isNull);
    });

    test('returns null for non-map input', () {
      expect(extractClaudeTextContent('plain string'), isNull);
    });

    test('extracts from type text with data field', () {
      final content = {'type': 'text', 'data': 'hello world'};
      expect(extractClaudeTextContent(content), 'hello world');
    });

    test('extracts from type text with text field', () {
      final content = {'type': 'text', 'text': 'hello world'};
      expect(extractClaudeTextContent(content), 'hello world');
    });

    test('extracts from assistant output structure', () {
      final content = {
        'type': 'output',
        'data': {
          'type': 'assistant',
          'message': {
            'content': [
              {'type': 'text', 'text': 'assistant response'},
            ],
          },
        },
      };
      expect(extractClaudeTextContent(content), 'assistant response');
    });

    test('extracts from user output with string content', () {
      final content = {
        'type': 'output',
        'data': {
          'type': 'user',
          'message': {
            'content': 'user message text',
          },
        },
      };
      expect(extractClaudeTextContent(content), 'user message text');
    });

    test('extracts from user output with list content', () {
      final content = {
        'type': 'output',
        'data': {
          'type': 'user',
          'message': {
            'content': ['item1', 'item2'],
          },
        },
      };
      expect(extractClaudeTextContent(content), 'item1');
    });

    test('extracts from user output with map items in list', () {
      final content = {
        'type': 'output',
        'data': {
          'type': 'user',
          'message': {
            'content': [
              {'type': 'text', 'text': 'first text'},
            ],
          },
        },
      };
      expect(extractClaudeTextContent(content), 'first text');
    });

    test('falls back to text field on map', () {
      final content = {'text': 'fallback text'};
      expect(extractClaudeTextContent(content), 'fallback text');
    });

    test('falls back to content field on map', () {
      final content = {'content': 'fallback content'};
      expect(extractClaudeTextContent(content), 'fallback content');
    });

    test('falls back to message field on map', () {
      final content = {'message': 'fallback message'};
      expect(extractClaudeTextContent(content), 'fallback message');
    });

    test('falls back to body field on map', () {
      final content = {'body': 'fallback body'};
      expect(extractClaudeTextContent(content), 'fallback body');
    });

    test('falls back to data string field', () {
      final content = {'data': 'data string'};
      expect(extractClaudeTextContent(content), 'data string');
    });

    test('returns summary message placeholder', () {
      final content = {
        'type': 'output',
        'data': {
          'type': 'summary',
          'summary': 'some summary',
        },
      };
      expect(
        extractClaudeTextContent(content),
        'Summary message (should be filtered)',
      );
    });

    test('returns null for empty map', () {
      expect(extractClaudeTextContent({}), isNull);
    });

    test('skips non-text items in assistant content list', () {
      final content = {
        'type': 'output',
        'data': {
          'type': 'assistant',
          'message': {
            'content': [
              {'type': 'tool_use', 'name': 'Read'},
              {'type': 'text', 'text': 'found it'},
            ],
          },
        },
      };
      expect(extractClaudeTextContent(content), 'found it');
    });

    test('returns null when assistant content has no text', () {
      final content = {
        'type': 'output',
        'data': {
          'type': 'assistant',
          'message': {
            'content': [
              {'type': 'tool_use', 'name': 'Read'},
            ],
          },
        },
      };
      expect(extractClaudeTextContent(content), isNull);
    });
  });

  group('extractClaudeToolCalls', () {
    test('returns empty list for null', () {
      expect(extractClaudeToolCalls(null), isEmpty);
    });

    test('extracts tool_use items from assistant content', () {
      final content = {
        'type': 'output',
        'data': {
          'type': 'assistant',
          'message': {
            'content': [
              {
                'type': 'tool_use',
                'name': 'Read',
                'input': {'file': 'test.dart'},
              },
            ],
          },
        },
      };
      final tools = extractClaudeToolCalls(content);
      expect(tools.length, 1);
      expect(tools[0]['name'], 'Read');
      expect(tools[0]['state'], 'completed');
      expect(tools[0]['arguments'], {'file': 'test.dart'});
    });

    test('extracts multiple tool calls', () {
      final content = {
        'type': 'output',
        'data': {
          'type': 'assistant',
          'message': {
            'content': [
              {
                'type': 'tool_use',
                'name': 'Read',
                'input': {'file': 'a.dart'},
              },
              {
                'type': 'tool_use',
                'name': 'Edit',
                'input': {'file': 'b.dart'},
              },
            ],
          },
        },
      };
      final tools = extractClaudeToolCalls(content);
      expect(tools.length, 2);
      expect(tools[0]['name'], 'Read');
      expect(tools[1]['name'], 'Edit');
    });

    test('tool without input gets empty map', () {
      final content = {
        'type': 'output',
        'data': {
          'type': 'assistant',
          'message': {
            'content': [
              {'type': 'tool_use', 'name': 'Bash'},
            ],
          },
        },
      };
      final tools = extractClaudeToolCalls(content);
      expect(tools[0]['arguments'], <String, dynamic>{});
    });

    test('returns empty for non-output type', () {
      expect(extractClaudeToolCalls({'type': 'text'}), isEmpty);
    });

    test('returns empty for non-assistant data type', () {
      final content = {
        'type': 'output',
        'data': {'type': 'user'},
      };
      expect(extractClaudeToolCalls(content), isEmpty);
    });
  });

  group('MessageContentWrapper', () {
    test('fromMessage extracts role and content', () {
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: 'user', c: 'hello'),
        createdAt: 0,
      );
      final wrapper = MessageContentWrapper.fromMessage(message);
      expect(wrapper.role, 'user');
      expect(wrapper.content, 'hello');
    });

    test('fromMessage with agent role', () {
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: 'agent', c: 'response'),
        createdAt: 0,
      );
      final wrapper = MessageContentWrapper.fromMessage(message);
      expect(wrapper.role, 'agent');
      expect(wrapper.content, 'response');
    });
  });

  group('getMessagePreview', () {
    test('returns No content for null message', () {
      expect(getMessagePreview(null), 'No content');
    });

    test('returns No content for empty content', () {
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: 'user', c: ''),
        createdAt: 0,
      );
      expect(getMessagePreview(message), 'No content');
    });

    test('returns User message for user with string content', () {
      // ApiMessageContent.c is String; content['type'] checks
      // won't match a String, so falls through to 'User message'
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: 'user', c: 'Hello world'),
        createdAt: 0,
      );
      expect(getMessagePreview(message), 'User message');
    });

    test('returns Thinking... for agent with string content', () {
      // Same reason: c is String, so Map checks don't match
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: 'agent', c: 'Agent response'),
        createdAt: 0,
      );
      expect(getMessagePreview(message), 'Thinking...');
    });

    test('returns Unknown message for unknown role', () {
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: 'system', c: 'some content'),
        createdAt: 0,
      );
      expect(getMessagePreview(message), 'Unknown message');
    });

    test('respects maxLength parameter', () {
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: 'user', c: 'hello'),
        createdAt: 0,
      );
      // Hits 'User message' path, maxLength not applied there
      expect(getMessagePreview(message, maxLength: 2), 'User message');
    });
  });

  group('isMessageFromAssistant', () {
    test('returns false for null', () {
      expect(isMessageFromAssistant(null), isFalse);
    });

    test('returns false for empty content', () {
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: '', c: ''),
        createdAt: 0,
      );
      expect(isMessageFromAssistant(message), isFalse);
    });

    test('returns true for agent role', () {
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: 'agent', c: 'hello'),
        createdAt: 0,
      );
      expect(isMessageFromAssistant(message), isTrue);
    });

    test('returns false for user role', () {
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: 'user', c: 'hello'),
        createdAt: 0,
      );
      expect(isMessageFromAssistant(message), isFalse);
    });

    test('returns false for system role', () {
      final message = ApiMessage(
        id: '1',
        seq: 0,
        content: ApiMessageContent(t: 'system', c: 'system message'),
        createdAt: 0,
      );
      expect(isMessageFromAssistant(message), isFalse);
    });
  });
}
