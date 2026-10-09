import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/utils/har_acp_normalize.dart';

Map<String, dynamic> _rootMeta(String name) => {
  'har': {
    'seq': 1,
    'tool': {'id': 'c', 'name': name},
  },
};

List<Map<String, dynamic>> _blocks(String text) => [
  {
    'type': 'content',
    'content': {'type': 'text', 'text': text},
  },
];

void main() {
  group('harToolName', () {
    test('reads root calls and delegated child rows', () {
      expect(harToolName({'_meta': _rootMeta('command')}), 'command');
      expect(
        harToolName({
          '_meta': {
            'har': {
              'progress': {'tool': 'edit_file', 'role': 'worker'},
            },
          },
        }),
        'edit_file',
      );
      expect(harToolName({'name': 'command'}), isNull);
      expect(harToolName({'_meta': <String, dynamic>{}}), isNull);
    });
  });

  group('normalizeHarToolCall', () {
    test('maps host tools to the views that render them', () {
      expect(normalizeHarToolCall('command', {'command': 'ls'})!.name, 'Bash');

      final read = normalizeHarToolCall('read_file', {'path': 'a.go'})!;
      expect(read.name, 'Read');
      expect(read.input['file_path'], 'a.go');

      final edit = normalizeHarToolCall('edit_file', {
        'path': 'a.go',
        'expected_version': 'abc',
        'old_text': 'x',
        'new_text': 'y',
      })!;
      expect(edit.name, 'Edit');
      expect(edit.input['file_path'], 'a.go');
      expect(edit.input['old_string'], 'x');
      expect(edit.input['new_string'], 'y');

      final create = normalizeHarToolCall('edit_file', {
        'path': 'new.go',
        'expected_version': 'absent',
        'old_text': '',
        'new_text': 'package x\n',
      })!;
      expect(create.name, 'Write');
      expect(create.input['content'], 'package x\n');

      expect(normalizeHarToolCall('list_files', {})!.input['path'], '.');

      final grep = normalizeHarToolCall('rg', {'pattern': 'TODO'})!;
      expect(grep.name, 'Grep');
      expect(grep.input['output_mode'], 'content');
    });

    test('leaves delegation, artifacts and MCP tools to the default path', () {
      expect(normalizeHarToolCall('delegate', {'task': 't'}), isNull);
      expect(normalizeHarToolCall('artifact', {'artifact_id': 'a'}), isNull);
      expect(normalizeHarToolCall('mcp_echo', {}), isNull);
    });
  });

  group('normalizeHarToolResult', () {
    test('keeps current plaintext results', () {
      expect(
        normalizeHarToolResult('command', _blocks('ok\n[exit 1]')),
        'ok\n[exit 1]',
      );
      expect(normalizeHarToolResult('read_file', 'package x'), 'package x');
    });

    test('renders a canonical artifact observation as its content', () {
      final raw = jsonEncode({
        'artifact_id': 'output-1',
        'command_effect': 'completed',
        'command_failed': false,
        'content': 'nil {\n\t\t\treturn err\n}\n',
        'effect': 'none',
        'exit_code': 0,
        'failed': false,
        'next_offset': 14999,
        'offset': 8750,
        'process_scope': 'owned_process_group',
        'process_waited': true,
        'termination': 'exited',
        'total_bytes': 14999,
        'truncated': false,
      });
      expect(
        normalizeHarToolResult('artifact', raw),
        'nil {\n\t\t\treturn err\n}',
      );
    });

    test('renders canonical command, edit, read and search observations', () {
      expect(
        normalizeHarToolResult(
          'command',
          jsonEncode({
            'stdout': 'out\n',
            'stderr': 'bad\n',
            'exit_code': 2,
            'termination': 'exited',
            'stdout_truncated': true,
            'artifact_id': 'output-9',
            'effect': 'completed',
            'failed': true,
          }),
        ),
        'out\n--- stderr ---\nbad\n[exit 2]\n[output truncated; artifact output-9]',
      );
      expect(
        normalizeHarToolResult(
          'edit_file',
          jsonEncode({
            'created': false,
            'diff': '- a\n+ b',
            'diff_truncated': false,
            'effect': 'completed',
            'failed': false,
            'new_version': 'd655',
            'path': '/w/a.go',
          }),
        ),
        '- a\n+ b',
      );
      expect(
        normalizeHarToolResult(
          'read_file',
          jsonEncode({
            'content': 'line\n',
            'truncated': true,
            'next_start_line': 2,
            'next_start_column': 0,
            'total_lines': 9,
            'effect': 'none',
            'failed': false,
          }),
        ),
        'line\n[truncated; next line 2 column 0 of 9 lines]',
      );
      expect(
        normalizeHarToolResult(
          'search_files',
          jsonEncode({
            'matches': [
              {'path': 'a.go', 'line': 3, 'content': 'TODO: x'},
            ],
            'truncated': false,
            'effect': 'none',
            'failed': false,
          }),
        ),
        'a.go:3:TODO: x',
      );
      expect(
        normalizeHarToolResult(
          'edit_file',
          '{"effect":"none","error":"stale_version","failed":true}',
        ),
        'error: stale_version',
      );
    });

    test('lists become entries for the LS view', () {
      expect(
        normalizeHarToolResult('list_files', 'cmd/\ngo.mod\n[list truncated]'),
        ['cmd/', 'go.mod'],
      );
      expect(
        normalizeHarToolResult(
          'list_files',
          jsonEncode({
            'entries': [
              {'path': 'cmd', 'directory': true, 'symlink': false},
              {'path': 'go.mod', 'directory': false, 'symlink': false},
            ],
            'truncated': false,
            'effect': 'none',
            'failed': false,
          }),
        ),
        ['cmd/', 'go.mod'],
      );
      expect(normalizeHarToolResult('list_files', '(empty)'), '(empty)');
    });

    test('passes through what it does not recognize', () {
      // A result clipped mid-JSON is not an observation any more.
      expect(
        normalizeHarToolResult('command', '{"stdout":"abc'),
        '{"stdout":"abc',
      );
      expect(normalizeHarToolResult('read_file', '{"a":1}'), '{"a":1}');
      expect(normalizeHarToolResult('delegate', '{"failed":true}'), isNull);
    });
  });

  test('har rows reach tool views with view names and readable results', () {
    final bodies = <Map<String, dynamic>>[
      {
        'type': 'tool-call',
        'callId': 'call_1',
        'name': 'edit_file',
        'status': 'in_progress',
        'input': {
          'path': 'a.go',
          'expected_version': '9afe',
          'old_text': 'x',
          'new_text': 'y',
        },
        '_meta': _rootMeta('edit_file'),
      },
      {
        'type': 'tool-result',
        'callId': 'call_1',
        'status': 'completed',
        'isError': false,
        'result': _blocks(
          '{"created":false,"diff":"- x\\n+ y","diff_truncated":false,'
          '"effect":"completed","failed":false,"new_version":"d655",'
          '"path":"/w/a.go"}',
        ),
        '_meta': _rootMeta('edit_file'),
      },
      {
        'type': 'tool-call',
        'callId': 'call_2',
        'name': 'Agent',
        'status': 'in_progress',
        'input': {'task': 't', 'prompt': 't'},
        '_meta': _rootMeta('delegate'),
      },
    ];
    final result = processDecryptedMessages(
      decryptedJsonList: [
        for (final body in bodies)
          {
            'role': 'agent',
            'content': {'type': 'acp', 'data': body},
          },
      ],
      wireMessages: [
        for (var i = 0; i < bodies.length; i++)
          {'id': 'har-$i', 'seq': i + 1, 'createdAt': 1000 + i},
      ],
      sessionId: 'har-session',
    );
    final edit = result.messages.singleWhere((m) => m['toolUseId'] == 'call_1');
    expect(edit['name'], 'Edit');
    expect(edit['input'], containsPair('old_string', 'x'));
    // The detail screen shows the arguments har was really called with.
    expect(edit['wireInput'], {
      'path': 'a.go',
      'expected_version': '9afe',
      'old_text': 'x',
      'new_text': 'y',
    });
    expect(result.toolResults.single['result'], '- x\n+ y');
    // A delegate stays the Agent anchor happy-cli-go made of it.
    final agent = result.messages.singleWhere(
      (m) => m['toolUseId'] == 'call_2',
    );
    expect(agent['name'], 'Agent');
  });
}
