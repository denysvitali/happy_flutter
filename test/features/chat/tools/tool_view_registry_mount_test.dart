import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/tools/views/bash_view.dart';
import 'package:happy_flutter/features/chat/tools/views/glob_view.dart';
import 'package:happy_flutter/features/chat/tools/views/grep_view.dart';
import 'package:happy_flutter/features/chat/tools/views/ls_view.dart';

Widget _wrap(Map<String, dynamic> tool) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ToolView(tool: tool)),
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
