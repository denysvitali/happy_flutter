import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/code_block_widget.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/tools/views/bash_view.dart';
import 'package:happy_flutter/features/chat/tools/views/glob_view.dart';
import 'package:happy_flutter/features/chat/tools/views/grep_view.dart';
import 'package:happy_flutter/features/chat/tools/views/ls_view.dart';
import 'package:happy_flutter/features/chat/tools/views/python_cell_view.dart';
import 'package:happy_flutter/features/chat/tools/views/terminal_output_section.dart';

Widget _wrap(Map<String, dynamic> tool, {VoidCallback? onPress}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ToolView(tool: tool, onPress: onPress),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cases = <({String name, Type view, Map<String, dynamic> tool})>[
    (
      name: 'Bash',
      view: BashView,
      tool: {
        'name': 'Bash',
        'input': {'command': 'printf ok'},
        'state': 'completed',
        'result': {'stdout': 'ok', 'exitCode': 0},
      },
    ),
    (
      name: 'Glob',
      view: GlobView,
      tool: {
        'name': 'Glob',
        'input': {'pattern': '*.dart'},
        'state': 'completed',
        'result': ['lib/main.dart'],
      },
    ),
    (
      name: 'Grep',
      view: GrepView,
      tool: {
        'name': 'Grep',
        'input': {'pattern': 'main'},
        'state': 'completed',
        'result': 'lib/main.dart:1:void main() {}',
      },
    ),
    (
      name: 'LS',
      view: LSView,
      tool: {
        'name': 'LS',
        'input': {'path': '/repo'},
        'state': 'completed',
        'result': [
          {'name': 'lib', 'isDirectory': true, 'isFile': false},
        ],
      },
    ),
  ];

  // ACP forwards the title verbatim: Prime Agent emits `Python cell`.
  for (final name in [
    'Python cell',
    'Python Cell',
    'ipython',
    'functions.ipython',
  ]) {
    testWidgets('$name starts compact and opens source and output on tap', (
      tester,
    ) async {
      const code =
          'for p in ["config.rs", "config_command.rs"]:\n'
          ' print(p)\n';
      await tester.pumpWidget(
        _wrap({
          'name': name,
          'input': {'code': code},
          'state': 'completed',
          'result': [
            {
              'type': 'content',
              'content': {'type': 'text', 'text': 'config.rs\n'},
            },
            {
              'type': 'content',
              'content': {'type': 'text', 'text': 'config_command.rs'},
            },
          ],
        }),
      );
      expect(find.byType(PythonCellView), findsNothing);
      expect(find.text('config.rs'), findsOneWidget);
      await tester.tap(find.byType(ToolView));
      await tester.pumpAndSettle();
      expect(find.byType(PythonCellView), findsOneWidget);
      final block = tester.widget<CodeBlockWidget>(
        find.byType(CodeBlockWidget),
      );
      expect(block.code, code);
      expect(block.language, 'python');
      final output = tester.widget<TerminalOutputSection>(
        find.byType(TerminalOutputSection),
      );
      expect(output.output, 'config.rs\nconfig_command.rs');
      expect(output.isError, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Python cells decode serialized input and bound long previews', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap({
        'name': 'Python Cell',
        'input': r'{"code":"print(1)\nprint(2)"}',
        'state': 'completed',
        'result': List.generate(100, (i) => '$i').join('\n'),
      }),
    );
    await tester.tap(find.byType(ToolView));
    await tester.pumpAndSettle();
    final block = tester.widget<CodeBlockWidget>(find.byType(CodeBlockWidget));
    expect(block.code, 'print(1)\nprint(2)');
    expect(block.maxVisibleLines, 4);
    final output = tester.widget<TerminalOutputSection>(
      find.byType(TerminalOutputSection),
    );
    expect(output.maxLines, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Python errors render readable tracebacks inline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap({
        'name': 'Python Cell',
        'input': {'code': '1 / 0'},
        'state': 'error',
        'result': 'Traceback\nZeroDivisionError: division by zero',
      }),
    );
    expect(find.text('ZeroDivisionError: division by zero'), findsOneWidget);
    await tester.tap(find.byType(ToolView));
    await tester.pumpAndSettle();
    final output = tester.widget<TerminalOutputSection>(
      find.byType(TerminalOutputSection),
    );
    expect(output.output, contains('ZeroDivisionError'));
    expect(output.isError, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Python completion preserves a manual collapse', (tester) async {
    final tool = <String, dynamic>{
      'name': 'Python Cell',
      'input': {'code': 'print("ok")'},
      'state': 'running',
    };
    await tester.pumpWidget(_wrap(tool));
    expect(find.byType(CodeBlockWidget), findsNothing);
    await tester.tap(find.byType(ToolView));
    await tester.pumpAndSettle();
    expect(find.byType(CodeBlockWidget), findsOneWidget);
    await tester.tap(find.textContaining('Python Cell', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(CodeBlockWidget), findsNothing);
    await tester.pumpWidget(
      _wrap({
        ...tool,
        'state': 'completed',
        'result': {'stdout': 'ok', 'stderr': ''},
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CodeBlockWidget), findsNothing);
    await tester.tap(find.textContaining('Python Cell', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(CodeBlockWidget), findsOneWidget);
    expect(find.byType(TerminalOutputSection), findsOneWidget);
  });

  testWidgets('Python cells expand independently in a narrow transcript', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++)
                      ToolView(
                        key: ValueKey('cell-$i'),
                        tool: {
                          'name': 'Python cell',
                          'input': {
                            'description': 'Inspect file $i',
                            'code': 'print($i)',
                          },
                          'state': 'completed',
                          'result': 'Result $i\nHidden output',
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CodeBlockWidget), findsNothing);
    expect(find.text('Hidden output'), findsNothing);
    expect(find.text('Result 1'), findsOneWidget);
    await tester.tap(find.textContaining('Inspect file 1', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(CodeBlockWidget), findsOneWidget);
    expect(
      tester.widget<CodeBlockWidget>(find.byType(CodeBlockWidget)).code,
      'print(1)',
    );
    expect(find.text('Result 0'), findsOneWidget);
    expect(find.text('Result 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Python completion keeps an explicitly opened cell open', (
    tester,
  ) async {
    final tool = <String, dynamic>{
      'name': 'Python cell',
      'input': {'code': 'print("ok")'},
      'state': 'running',
    };
    await tester.pumpWidget(_wrap(tool));
    await tester.tap(find.byType(ToolView));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _wrap({...tool, 'state': 'completed', 'result': 'ok'}),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CodeBlockWidget), findsOneWidget);
    expect(find.byType(TerminalOutputSection), findsOneWidget);
  });

  testWidgets('Python details opens without expanding the cell', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      _wrap({
        'name': 'Python cell',
        'input': {'code': 'print(1)'},
        'state': 'completed',
        'result': '1',
      }, onPress: () => opened = true),
    );
    await tester.tap(find.byKey(const ValueKey('tool-header-details-action')));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(find.byType(CodeBlockWidget), findsNothing);
  });

  for (final testCase in cases) {
    testWidgets('${testCase.name} mounts its registered rich body', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(testCase.tool));
      expect(find.byType(testCase.view), findsNothing);

      await tester.tap(find.byType(ToolView));
      await tester.pumpAndSettle();

      expect(find.byType(testCase.view), findsOneWidget);
    });
  }
}
