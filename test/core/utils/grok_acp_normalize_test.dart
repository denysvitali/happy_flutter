import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/grok_acp_normalize.dart';
import 'package:happy_flutter/core/utils/tool_input_extractor.dart';

void main() {
  group('canonicalizeGrokToolName', () {
    test('maps Grok built-ins to Claude display names', () {
      expect(canonicalizeGrokToolName('list_dir'), 'LS');
      expect(canonicalizeGrokToolName('read_file'), 'Read');
      expect(canonicalizeGrokToolName('run_terminal_command'), 'Bash');
      expect(canonicalizeGrokToolName('search_replace'), 'Edit');
      expect(canonicalizeGrokToolName('todo_write'), 'TodoWrite');
      expect(canonicalizeGrokToolName('unknown_tool'), 'unknown_tool');
    });
  });

  group('normalizeGrokToolInput', () {
    test('maps target_file and target_directory', () {
      final read = normalizeGrokToolInput({'target_file': 'README.md'});
      expect(read['file_path'], 'README.md');
      expect(extractFilePath(read), 'README.md');

      final list = normalizeGrokToolInput({'target_directory': '.'});
      expect(list['path'], '.');
      expect(extractFilePath(list), '.');
    });
  });

  group('normalizeGrokToolResult', () {
    test('extracts text from ACP content blocks', () {
      final result = normalizeGrokToolResult([
        {
          'type': 'content',
          'content': {'type': 'text', 'text': 'hello fixture'},
        },
      ]);
      expect(result, 'hello fixture');
    });

    test('normalizes shell rawOutput', () {
      final result = normalizeGrokToolResult({
        'output': 'capture-ok\n',
        'exit_code': 0,
        'command': 'echo capture-ok',
      });
      expect(result, isA<Map>());
      final map = result as Map;
      expect(map['stdout'], 'capture-ok\n');
      expect(map['exitCode'], 0);
    });

    test('parses ListDir tree into entries', () {
      final result = normalizeGrokToolResult({
        'type': 'ListDir',
        'Content': {
          'content': '- /tmp/fixture/\n  - README.md\n  - probe.txt',
          'absolute_root_path': '/tmp/fixture/.',
        },
      });
      expect(result, isA<Map>());
      final entries = (result as Map)['entries'] as List;
      expect(entries.length, greaterThanOrEqualTo(2));
      final names = entries.map((e) => (e as Map)['name']).toSet();
      expect(names, containsAll(['README.md', 'probe.txt']));
    });
  });
}
