import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/views/bash_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
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

    testWidgets('derives description from known commands',
        (tester) async {
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

      // Falls back to derived description
      expect(find.text('git command'), findsOneWidget);
    });

    testWidgets('renders "No output" when stdout is empty and exit is 0',
        (tester) async {
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

  group('CommandView', () {
    testWidgets('renders command with dollar prefix', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CommandView(command: 'npm test'),
        ),
      );

      expect(find.text('npm test'), findsOneWidget);
      expect(find.text(r'$'), findsOneWidget);
    });

    testWidgets('renders stdout section', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CommandView(
            command: 'echo hi',
            stdout: 'hi there',
          ),
        ),
      );

      expect(find.text('stdout'), findsOneWidget);
      expect(find.textContaining('hi there'), findsOneWidget);
    });

    testWidgets('renders stderr section with error icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CommandView(
            command: 'fail',
            stderr: 'error message',
          ),
        ),
      );

      expect(find.text('stderr'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders exit code badge', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CommandView(
            command: 'some_cmd',
            exitCode: 42,
          ),
        ),
      );

      expect(find.text('exit 42'), findsOneWidget);
    });

    testWidgets('shows "No output" for empty stdout with exit 0',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CommandView(command: 'touch file', exitCode: 0),
        ),
      );

      expect(find.text('No output'), findsOneWidget);
    });

    testWidgets('truncates long stdout by default', (tester) async {
      final longOutput = List.generate(30, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        _wrap(
          CommandView(
            command: 'cat big.txt',
            stdout: longOutput,
          ),
        ),
      );

      expect(find.textContaining('Show'), findsOneWidget);
    });
  });

  group('FilePillChip', () {
    testWidgets('renders file path with icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FilePillChip(path: '/src/main.dart'),
        ),
      );

      // Text is inside RichText via TextSpan children.
      final richText = tester.widget<RichText>(
        find.byType(RichText).last,
      );
      final textSpan = richText.text as TextSpan;
      final spans =
          textSpan.children!.map((s) => (s as TextSpan).text).toList();
      expect(spans, contains('/src/'));
      expect(spans, contains('main.dart'));
      expect(
        find.byIcon(Icons.insert_drive_file_outlined),
        findsOneWidget,
      );
    });

    testWidgets('renders filename without directory', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FilePillChip(path: 'README.md'),
        ),
      );

      final richText = tester.widget<RichText>(
        find.byType(RichText).last,
      );
      final textSpan = richText.text as TextSpan;
      final spans =
          textSpan.children!.map((s) => (s as TextSpan).text).toList();
      expect(spans, contains('README.md'));
    });

    testWidgets('renders deep path correctly', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FilePillChip(
            path: '/home/user/project/lib/main.dart',
          ),
        ),
      );

      final richText = tester.widget<RichText>(
        find.byType(RichText).last,
      );
      final textSpan = richText.text as TextSpan;
      final spans =
          textSpan.children!.map((s) => (s as TextSpan).text).toList();
      expect(spans, contains('main.dart'));
      expect(spans, contains('/home/user/project/lib/'));
    });
  });
}
