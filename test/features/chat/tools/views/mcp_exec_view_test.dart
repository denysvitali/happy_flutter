import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/tools/views/mcp_exec_view.dart';

/// Production shape of an `mcp__ssh__ssh_execute` result: the exec record
/// lives *inside* the content block's `text` field as an object, not a string.
Map<String, dynamic> _sshTool({
  String stdout = 'REBOOT_SENT',
  String stderr = '',
  int exitCode = 0,
  bool timedOut = false,
}) {
  return <String, dynamic>{
    'name': 'mcp__ssh__ssh_execute',
    'state': 'completed',
    'input': <String, dynamic>{
      'command': "nohup sh -c 'sleep 1; /sbin/reboot' >/dev/null 2>&1 &",
      'connection_id': 'jagar',
      'max_lines': 5,
    },
    'result': <dynamic>[
      <String, dynamic>{
        'type': 'text',
        'text': <String, dynamic>{
          'binary_output': false,
          'exit_code': exitCode,
          'signal': 0,
          'signal_name': '',
          'stderr': stderr,
          'stdout': stdout,
          'success': exitCode == 0,
          'timed_out': timedOut,
        },
      },
    ],
  };
}

Map<String, dynamic> _bareSshTool() => <String, dynamic>{
  'name': 'ssh_execute',
  'state': 'completed',
  'input': <String, dynamic>{
    'arguments': <String, dynamic>{
      'command': 'id\nuname -srvm\ncat /proc/sys/kernel/random/boot_id',
      'connection_id': 'jagar-wifi',
      'max_bytes': 4096,
      'max_lines': 20,
    },
  },
  'result': <String, dynamic>{
    'content': <dynamic>[
      <String, dynamic>{
        'type': 'text',
        'text': <String, dynamic>{
          'binary_output': false,
          'exit_code': 0,
          'signal': 0,
          'signal_name': '',
          'stderr': '',
          'stdout': 'uid=0(root) gid=0(root)\nLinux jagar 6.12.0',
          'success': true,
          'timed_out': false,
        },
      },
    ],
    'status': 'completed',
  },
};

Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

String _allText(WidgetTester tester) {
  final rich = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((w) => w.text.toPlainText())
      .join('\n');
  final selectable = tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
      .join('\n');
  return '$rich\n$selectable';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('McpExecResult.tryParse', () {
    test('parses an object-valued content block', () {
      final exec = McpExecResult.tryParse(_sshTool()['result']);
      expect(exec, isNotNull);
      expect(exec!.stdout, 'REBOOT_SENT');
      expect(exec.exitCode, 0);
      expect(exec.success, isTrue);
      expect(exec.timedOut, isFalse);
      expect(exec.stderr, isNull); // empty string reads as absent
    });

    test('parses a JSON-string content block', () {
      final result = <dynamic>[
        <String, dynamic>{
          'type': 'text',
          'text': jsonEncode(<String, dynamic>{
            'stdout': 'ok',
            'stderr': 'warn',
            'exit_code': 3,
            'success': false,
          }),
        },
      ];
      final exec = McpExecResult.tryParse(result);
      expect(exec?.exitCode, 3);
      expect(exec?.stderr, 'warn');
    });

    test('parses camelCase and a bare record', () {
      final exec = McpExecResult.tryParse(<String, dynamic>{
        'stdout': 'hi',
        'exitCode': 1,
        'timedOut': true,
      });
      expect(exec?.exitCode, 1);
      expect(exec?.timedOut, isTrue);
    });

    test('rejects ordinary MCP payloads', () {
      expect(McpExecResult.tryParse('plain text'), isNull);
      expect(
        McpExecResult.tryParse(<dynamic>[
          <String, dynamic>{'type': 'text', 'text': '{"items": [1, 2]}'},
        ]),
        isNull,
      );
      expect(
        McpExecResult.tryParse(<String, dynamic>{'stdout': 'no verdict'}),
        isNull,
      );
    });
  });

  group('McpExecView', () {
    testWidgets('renders command, host chip and stdout', (tester) async {
      final tool = _sshTool();
      await tester.pumpWidget(
        _wrap(
          McpExecView(
            tool: tool,
            exec: McpExecResult.tryParse(tool['result'])!,
          ),
        ),
      );
      await tester.pump();

      final text = _allText(tester);
      expect(text, contains('/sbin/reboot'));
      expect(text, contains('REBOOT_SENT'));
      expect(text, contains('jagar'));
      expect(text, contains('exit 0'));
      // The raw wire keys must not leak into the rendered card.
      expect(text, isNot(contains('binary_output')));
    });

    testWidgets('surfaces stderr and a timeout', (tester) async {
      final tool = _sshTool(
        stdout: '',
        stderr: 'connection reset',
        exitCode: 255,
        timedOut: true,
      );
      await tester.pumpWidget(
        _wrap(
          McpExecView(
            tool: tool,
            exec: McpExecResult.tryParse(tool['result'])!,
          ),
        ),
      );
      await tester.pump();

      final text = _allText(tester);
      expect(text, contains('connection reset'));
      expect(text, contains('exit 255'));
      expect(text, contains('timed out'));
    });

    testWidgets('unwraps ssh-mcp arguments', (tester) async {
      final tool = _bareSshTool();
      await tester.pumpWidget(
        _wrap(
          McpExecView(
            tool: tool,
            exec: McpExecResult.tryParse(tool['result'])!,
          ),
        ),
      );
      await tester.pump();

      final text = _allText(tester);
      expect(text, contains('uname -srvm'));
      expect(text, contains('jagar-wifi'));
      expect(text, contains('uid=0(root)'));
      expect(text, isNot(contains('max_bytes')));
    });

    testWidgets('ToolView recognizes bare ssh_execute as a terminal', (
      tester,
    ) async {
      final tool = _bareSshTool();
      await tester.pumpWidget(_wrap(ToolView(tool: tool)));
      await tester.pump();

      expect(find.text('SSH'), findsOneWidget);
      await tester.tap(find.byType(ToolView));
      await tester.pumpAndSettle();

      final text = _allText(tester);
      expect(text, contains('uname -srvm'));
      expect(text, contains('uid=0(root)'));
      expect(text, contains('jagar-wifi'));
      expect(text, isNot(contains('binary_output')));
      expect(text, isNot(contains('max_lines')));
    });
  });
}
