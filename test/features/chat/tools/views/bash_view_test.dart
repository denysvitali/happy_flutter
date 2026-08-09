import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/known_tools.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/tools/views/bash_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Widget _wrapTool(Map<String, dynamic> tool) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ToolView(tool: tool)),
    ),
  );
}

String _richTextContent(WidgetTester tester) {
  final richText = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText())
      .join('\n');
  final selectableText = tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .join('\n');
  return '$richText\n$selectableText';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BashView', () {
    testWidgets('renders command text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BashView(
            tool: {
              'input': {'command': 'ls -la'},
              'state': 'pending',
            },
          ),
        ),
      );

      expect(find.text('ls -la'), findsOneWidget);
      expect(find.text(r'$'), findsOneWidget);
    });

    testWidgets('renders a zsh transport as its inner command', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BashView(
            tool: {
              'input': {'command': "/usr/bin/zsh -lc 'git status --short'"},
              'state': 'pending',
            },
          ),
        ),
      );

      expect(find.text('git status --short'), findsOneWidget);
      expect(find.textContaining('/usr/bin/zsh'), findsNothing);
    });

    testWidgets('renders stdout when completed', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BashView(
            tool: {
              'input': {'command': 'echo hello'},
              'state': 'completed',
              'result': {'stdout': 'hello\nworld', 'exitCode': 0},
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('stdout'), findsOneWidget);
      // The stdout content is rendered within a SelectableText.rich
      // which contains both 'hello' and 'world'.
      expect(find.textContaining('hello'), findsWidgets);
      expect(find.textContaining('world'), findsOneWidget);
    });

    testWidgets('renders stderr when present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BashView(
            tool: {
              'input': {'command': 'bad_cmd'},
              'state': 'completed',
              'result': {
                'stdout': '',
                'stderr': 'command not found',
                'exitCode': 127,
              },
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('stderr'), findsOneWidget);
      expect(find.textContaining('command not found'), findsOneWidget);
    });

    testWidgets('renders exit code badge for success', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BashView(
            tool: {
              'input': {'command': 'true'},
              'state': 'completed',
              'result': {'exitCode': 0},
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('exit 0'), findsOneWidget);
    });

    testWidgets('renders exit code badge for failure', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BashView(
            tool: {
              'input': {'command': 'false'},
              'state': 'completed',
              'result': {'exitCode': 1},
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('exit 1'), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BashView(
            tool: {
              'input': {
                'command': 'npm install',
                'description': 'Install dependencies',
              },
              'state': 'pending',
            },
          ),
        ),
      );

      expect(find.text('Install dependencies'), findsOneWidget);
    });

    testWidgets('renders the bash header when no description is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BashView(
            tool: {
              'input': {'command': 'git status'},
              'state': 'pending',
            },
          ),
        ),
      );

      // Same header as Codex/Gemini shell views — no fabricated description.
      expect(find.text('bash'), findsOneWidget);
      expect(find.text('git status'), findsOneWidget);
      expect(find.text('git command'), findsNothing);
    });

    testWidgets('renders "No output" when stdout is empty and exit is 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BashView(
            tool: {
              'input': {'command': 'mkdir test'},
              'state': 'completed',
              'result': {'exitCode': 0},
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('No output'), findsOneWidget);
    });

    testWidgets('renders command label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BashView(
            tool: {
              'input': {'command': 'echo test'},
              'state': 'pending',
            },
          ),
        ),
      );

      expect(find.byIcon(Icons.terminal), findsOneWidget);
    });
  });

  group('KnownTools terminal summaries', () {
    test('hide zsh transport wrappers', () {
      final definition = KnownTools.get('Bash')!;
      final subtitle = definition.extractSubtitle!({
        'input': {'command': "/usr/bin/zsh -lc 'git status --short'"},
      }, null);

      expect(subtitle, 'git status --short');
    });
  });

  group('CommandView', () {
    testWidgets('renders command with dollar prefix', (tester) async {
      await tester.pumpWidget(_wrap(const CommandView(command: 'npm test')));

      expect(find.text('npm test'), findsOneWidget);
      expect(find.text(r'$'), findsOneWidget);
    });

    testWidgets('renders stdout section', (tester) async {
      await tester.pumpWidget(
        _wrap(const CommandView(command: 'echo hi', stdout: 'hi there')),
      );

      expect(find.text('stdout'), findsOneWidget);
      expect(find.textContaining('hi there'), findsOneWidget);
    });

    testWidgets('renders stderr section with error icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const CommandView(command: 'fail', stderr: 'error message')),
      );

      expect(find.text('stderr'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders exit code badge', (tester) async {
      await tester.pumpWidget(
        _wrap(const CommandView(command: 'some_cmd', exitCode: 42)),
      );

      expect(find.text('exit 42'), findsOneWidget);
    });

    testWidgets('shows "No output" for empty stdout with exit 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CommandView(command: 'touch file', exitCode: 0)),
      );

      expect(find.text('No output'), findsOneWidget);
    });

    testWidgets('truncates long stdout by default', (tester) async {
      final longOutput = List.generate(30, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        _wrap(CommandView(command: 'cat big.txt', stdout: longOutput)),
      );

      expect(find.textContaining('Show'), findsOneWidget);
    });
  });

  group('ExecCommandView', () {
    testWidgets('renders stdout and toggles raw JSON', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ExecCommandView(
            tool: {
              'input': {'cmd': 'go version', 'workdir': '/repo'},
              'state': 'completed',
              'result': {
                'exitCode': 0,
                'output': 'go version go1.23.12 linux/amd64',
                'stdout': 'go version go1.23.12 linux/amd64',
                'status': 'completed',
              },
            },
          ),
        ),
      );

      expect(find.text('go version'), findsOneWidget);
      expect(find.text('/repo'), findsOneWidget);
      expect(find.textContaining('go1.23.12'), findsWidgets);
      expect(find.text('exit 0'), findsOneWidget);
      // Raw JSON is no longer reachable inline; the bash view shows text
      // sections only. Full payload is one long-press away in
      // MessageDetailScreen.
      expect(find.text('Show JSON'), findsNothing);
      expect(find.text('Hide JSON'), findsNothing);
      expect(_richTextContent(tester), isNot(contains('"exitCode"')));
    });

    testWidgets('ToolView activates renderer by function tool name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapTool({
          'name': 'functions.exec_command',
          'toolUseId': 'cmd-1',
          'input': {'cmd': 'printf ok', 'workdir': '/repo'},
          'state': 'completed',
          'result': {
            'exitCode': 0,
            'output': 'ok',
            'stdout': 'ok',
            'status': 'completed',
          },
        }),
      );

      await tester.tap(find.byType(ToolView));
      await tester.pumpAndSettle();

      expect(find.text('printf ok'), findsWidgets);
      expect(find.text('stdout'), findsOneWidget);
      // Raw JSON toggle removed; only the text sections are rendered.
      expect(find.text('Show JSON'), findsNothing);
    });

    testWidgets('hides Codex transport shell wrapper in summary and body', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapTool({
          'name': 'functions.exec_command',
          'toolUseId': 'cmd-wrapper-1',
          'input': {'cmd': "/bin/sh -lc 'printf ok'", 'workdir': '/repo'},
          'state': 'completed',
          'result': {
            'exitCode': 0,
            'output': 'ok',
            'stdout': 'ok',
            'status': 'completed',
          },
        }),
      );

      expect(_richTextContent(tester), contains('Terminal  printf ok'));
      expect(_richTextContent(tester), isNot(contains('/bin/sh -lc')));

      await tester.tap(find.byType(ToolView));
      await tester.pumpAndSettle();

      expect(find.text('printf ok'), findsWidgets);
      expect(find.textContaining('/bin/sh -lc'), findsNothing);
    });

    testWidgets('renders ANSI escape sequences as styled text', (tester) async {
      const output =
          '\x1B[36mINFO\x1B[0m[0000] conditions\r\n'
          '\x1B[31mFATA\x1B[0m[0000] missing file\r\n';

      await tester.pumpWidget(
        _wrap(
          ExecCommandView(
            tool: {
              'input': {'cmd': 'service-shell-command'},
              'state': 'completed',
              'result': {
                'exitCode': 1,
                'output': output,
                'status': 'failed',
                'stdout': output,
              },
            },
          ),
        ),
      );

      final renderedText = _richTextContent(tester);
      expect(renderedText, contains('INFO'));
      expect(renderedText, contains('FATA'));
      expect(renderedText, isNot(contains('\x1B[')));
      expect(find.text('exit 1'), findsOneWidget);
    });
  });

  group('FilePillChip', () {
    testWidgets('renders file path with icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const FilePillChip(path: '/src/main.dart')),
      );

      // Text is inside RichText via TextSpan children.
      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final textSpan = richText.text as TextSpan;
      final spans = textSpan.children!
          .map((s) => (s as TextSpan).text)
          .toList();
      expect(spans, contains('/src/'));
      expect(spans, contains('main.dart'));
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    });

    testWidgets('renders filename without directory', (tester) async {
      await tester.pumpWidget(_wrap(const FilePillChip(path: 'README.md')));

      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final textSpan = richText.text as TextSpan;
      final spans = textSpan.children!
          .map((s) => (s as TextSpan).text)
          .toList();
      expect(spans, contains('README.md'));
    });

    testWidgets('renders deep path correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(const FilePillChip(path: '/home/user/project/lib/main.dart')),
      );

      final richText = tester.widget<RichText>(find.byType(RichText).last);
      final textSpan = richText.text as TextSpan;
      final spans = textSpan.children!
          .map((s) => (s as TextSpan).text)
          .toList();
      expect(spans, contains('main.dart'));
      expect(spans, contains('/home/user/project/lib/'));
    });
  });
}
