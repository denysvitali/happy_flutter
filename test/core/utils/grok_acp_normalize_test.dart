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

    test('prefixes bare server__tool MCP names with mcp__', () {
      expect(
        canonicalizeGrokToolName('gh-actions__list_runs'),
        'mcp__gh-actions__list_runs',
      );
      expect(
        canonicalizeGrokToolName('mcp__fly__fly-apps-list'),
        'mcp__fly__fly-apps-list',
      );
    });
  });

  group('unwrapGrokMcpDispatch', () {
    test('unwraps use_tool into mcp__server__tool + tool_input', () {
      final got = unwrapGrokMcpDispatch('use_tool', {
        'tool_name': 'gh-actions__wait_for_commit_checks',
        'tool_input': {
          'owner': 'denysvitali',
          'repo': 'happy_flutter',
          'ref': '5883082643fba88493afa8b34f7b69496d078af3',
          'timeout_minutes': 45,
        },
      });
      expect(got.name, 'mcp__gh-actions__wait_for_commit_checks');
      expect(got.input['owner'], 'denysvitali');
      expect(got.input['repo'], 'happy_flutter');
      expect(got.input['timeout_minutes'], 45);
      expect(got.input.containsKey('tool_name'), isFalse);
    });

    test('unwraps CallMcpTool camelCase fields without double mcp__', () {
      final got = unwrapGrokMcpDispatch('CallMcpTool', {
        'toolName': 'mcp__linear__save_issue',
        'toolInput': {'title': 'x'},
      });
      expect(got.name, 'mcp__linear__save_issue');
      expect(got.input['title'], 'x');
    });

    test('leaves non-dispatcher tools alone', () {
      final got = unwrapGrokMcpDispatch('read_file', {
        'target_file': 'a.go',
      });
      expect(got.name, 'read_file');
      expect(got.input['target_file'], 'a.go');
    });

    test('keeps use_tool when tool_name missing', () {
      final got = unwrapGrokMcpDispatch('use_tool', {
        'tool_input': {'x': 1},
      });
      expect(got.name, 'use_tool');
      expect(got.input['tool_input'], isA<Map>());
    });
  });

  group('normalizeGrokToolCall', () {
    test('full pipeline: unwrap + alias + input keys', () {
      final got = normalizeGrokToolCall('use_tool', {
        'tool_name': 'gh-actions__list_runs',
        'tool_input': {'owner': 'denysvitali', 'repo': 'happy-cli-go'},
      });
      expect(got.name, 'mcp__gh-actions__list_runs');
      expect(got.input['owner'], 'denysvitali');
    });

    test('aliases built-ins after non-dispatch path', () {
      final got = normalizeGrokToolCall('list_dir', {
        'target_directory': '/tmp',
      });
      expect(got.name, 'LS');
      expect(got.input['path'], '/tmp');
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

    test('omits shell fields that are absent from the raw output', () {
      // Regression: the map used `?'stderr': value`, which tests the *key*
      // for null, not the value — so absent fields were emitted as explicit
      // nulls. happy-cli-go omits them, so the client must too.
      final result =
          normalizeGrokToolResult({
                'output': 'capture-ok\n',
                'exit_code': 0,
              })
              as Map;
      expect(result['stdout'], 'capture-ok\n');
      expect(result['exitCode'], 0);
      expect(result.containsKey('stderr'), isFalse);
      expect(result.containsKey('command'), isFalse);
      expect(result.containsKey('description'), isFalse);
      expect(result.containsKey('truncated'), isFalse);
      expect(result.containsKey('timedOut'), isFalse);
    });

    test('keeps shell fields that are present', () {
      final result =
          normalizeGrokToolResult({
                'output': 'oops\n',
                'stderr': 'boom',
                'exit_code': 1,
                'command': 'false',
                'truncated': true,
                'timed_out': false,
              })
              as Map;
      expect(result['stderr'], 'boom');
      expect(result['exitCode'], 1);
      expect(result['command'], 'false');
      expect(result['truncated'], true);
      expect(result['timedOut'], false);
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

    test('unwraps MCP OkayOutput JSON (not shell/stdout wrapper)', () {
      final result = normalizeGrokToolResult({
        'type': 'MCP',
        'tool_name': 'prometheus_query',
        'server_name': 'prometheus',
        'output': {
          'OkayOutput': '''
{
  "data": {
    "result": [
      {
        "metric": {"job": "happy/happy-postgres"},
        "value": [1783546938.579, "456"]
      }
    ],
    "resultType": "vector"
  }
}''',
        },
      });
      expect(result, isA<Map>());
      final map = result as Map;
      expect(map.containsKey('stdout'), isFalse);
      expect(map.containsKey('OkayOutput'), isFalse);
      expect(map['data'], isA<Map>());
      expect((map['data'] as Map)['resultType'], 'vector');
    });

    test('unwraps MCP Error string', () {
      final result = normalizeGrokToolResult({
        'type': 'MCP',
        'tool_name': 'get_run',
        'output': {'Error': 'section matching pattern not found'},
      });
      expect(result, 'section matching pattern not found');
    });

    test('unwraps MCP plain-text OkayOutput', () {
      final result = normalizeGrokToolResult({
        'type': 'MCP',
        'output': {'OkayOutput': 'alloy\nalertmanager\nargocd'},
      });
      expect(result, 'alloy\nalertmanager\nargocd');
    });
  });
}
