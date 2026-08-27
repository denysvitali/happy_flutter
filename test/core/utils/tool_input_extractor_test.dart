import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/tool_input_extractor.dart';

void main() {
  group('extractCommand', () {
    test('returns command field when present', () {
      const input = {'command': 'ls -la'};
      expect(extractCommand(input), 'ls -la');
    });

    test('falls back to cmd field', () {
      const input = {'cmd': 'pwd'};
      expect(extractCommand(input), 'pwd');
    });

    test('prefers command over cmd', () {
      const input = {'command': 'ls', 'cmd': 'pwd'};
      expect(extractCommand(input), 'ls');
    });

    test('extracts from parsed_cmd list', () {
      const input = {
        'parsed_cmd': [
          {'type': 'bash', 'cmd': 'echo hello'},
        ],
      };
      expect(extractCommand(input), 'echo hello');
    });

    test('cleans parsed_cmd cmd by default', () {
      const input = {
        'parsed_cmd': [
          {'cmd': '  echo hello  '},
        ],
      };
      expect(extractCommand(input), 'echo hello');
    });

    test('returns raw parsed_cmd cmd when clean is false', () {
      const input = {
        'parsed_cmd': [
          {'cmd': '  echo hello  '},
        ],
      };
      expect(extractCommand(input, clean: false), '  echo hello  ');
    });

    test('joins CodexBash command lists', () {
      const input = {
        'command': ['/bin/bash -lc', 'ls'],
      };
      expect(extractCommand(input), '/bin/bash -lc ls');
    });

    test('returns null when no command found', () {
      const input = {'other': 'value'};
      expect(extractCommand(input), isNull);
    });

    test('ignores empty strings', () {
      const input = {'command': '', 'cmd': ''};
      expect(extractCommand(input), isNull);
    });
  });

  group('extractCommandList', () {
    test('returns command list when present', () {
      const input = {
        'command': ['ls', '-la'],
      };
      expect(extractCommandList(input), ['ls', '-la']);
    });

    test('falls back to parsed_cmd list', () {
      const input = {
        'parsed_cmd': [
          {'cmd': 'echo'},
        ],
      };
      expect(extractCommandList(input), [
        {'cmd': 'echo'},
      ]);
    });

    test('returns null when no list found', () {
      const input = {'command': 'ls'};
      expect(extractCommandList(input), isNull);
    });
  });

  group('extractFilePath', () {
    test('returns file_path field when present', () {
      const input = {'file_path': '/tmp/foo.txt'};
      expect(extractFilePath(input), '/tmp/foo.txt');
    });

    test('falls back to filePath', () {
      const input = {'filePath': '/tmp/foo.txt'};
      expect(extractFilePath(input), '/tmp/foo.txt');
    });

    test('falls back to path', () {
      const input = {'path': '/tmp/foo.txt'};
      expect(extractFilePath(input), '/tmp/foo.txt');
    });

    test('extracts from locations list', () {
      const input = {
        'locations': [
          {'path': '/tmp/foo.txt'},
        ],
      };
      expect(extractFilePath(input), '/tmp/foo.txt');
    });

    test('prefers file_path over locations', () {
      const input = {
        'file_path': '/a.txt',
        'locations': [
          {'path': '/b.txt'},
        ],
      };
      expect(extractFilePath(input), '/a.txt');
    });

    test('returns null when no path found', () {
      const input = {'other': 'value'};
      expect(extractFilePath(input), isNull);
    });
  });

  group('extractGeminiToolCallPath', () {
    test('extracts path from toolCall content', () {
      const input = {
        'toolCall': {
          'content': [
            {'path': '/tmp/foo.txt'},
          ],
        },
      };
      expect(extractGeminiToolCallPath(input), '/tmp/foo.txt');
    });

    test('extracts path from Writing to title', () {
      const input = {
        'toolCall': {'title': 'Writing to /tmp/foo.txt'},
      };
      expect(extractGeminiToolCallPath(input), '/tmp/foo.txt');
    });

    test('returns null when neither present', () {
      const input = {'toolCall': <String, dynamic>{}};
      expect(extractGeminiToolCallPath(input), isNull);
    });
  });

  group('extractPathFromInputList', () {
    test('extracts path from input list', () {
      const input = {
        'input': [
          {'path': '/tmp/foo.txt'},
        ],
      };
      expect(extractPathFromInputList(input), '/tmp/foo.txt');
    });

    test('returns null when list empty', () {
      const input = {'input': <dynamic>[]}; // ignore: use_named_constants
      expect(extractPathFromInputList(input), isNull);
    });
  });

  group('extractContentText', () {
    test('returns string as-is', () {
      expect(extractContentText('hello'), 'hello');
    });

    test('extracts content from map', () {
      const input = {'content': 'hello'};
      expect(extractContentText(input), 'hello');
    });

    test('falls back to text, body, output', () {
      expect(extractContentText({'text': 'a'}), 'a');
      expect(extractContentText({'body': 'b'}), 'b');
      expect(extractContentText({'output': 'c'}), 'c');
    });

    test('returns null when no text found', () {
      expect(extractContentText({'other': 'value'}), isNull);
    });
  });

  group('extractEditTexts', () {
    test('extracts old_string and new_string', () {
      const input = {'old_string': 'old', 'new_string': 'new'};
      final result = extractEditTexts(input);
      expect(result.oldText, 'old');
      expect(result.newText, 'new');
    });

    test('falls back to oldContent and newContent', () {
      const input = {'oldContent': 'old', 'newContent': 'new'};
      final result = extractEditTexts(input);
      expect(result.oldText, 'old');
      expect(result.newText, 'new');
    });

    test('returns nulls when absent', () {
      const input = <String, dynamic>{};
      final result = extractEditTexts(input);
      expect(result.oldText, isNull);
      expect(result.newText, isNull);
    });
  });

  group('extractCwd', () {
    test('extracts cwd', () {
      expect(extractCwd({'cwd': '/tmp'}), '/tmp');
    });

    test('falls back to workdir and working_dir', () {
      expect(extractCwd({'workdir': '/a'}), '/a');
      expect(extractCwd({'working_dir': '/b'}), '/b');
    });

    test('prefers cwd over fallbacks', () {
      expect(extractCwd({'cwd': '/a', 'workdir': '/b'}), '/a');
    });

    test('returns null when absent', () {
      expect(extractCwd({}), isNull);
    });
  });
}
