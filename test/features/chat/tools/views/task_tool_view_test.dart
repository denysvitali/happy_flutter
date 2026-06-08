import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/views/task_tool_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskToolView', () {
    testWidgets('TaskCreate renders subject and status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TaskToolView(
            tool: {
              'name': 'TaskCreate',
              'state': 'completed',
              'input': {
                'subject': 'Reverse the binary',
                'activeForm': 'Reversing the binary',
                'status': 'pending',
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reverse the binary'), findsOneWidget);
      expect(find.text('Reversing the binary'), findsOneWidget);
      expect(find.text('pending'), findsOneWidget);
    });

    testWidgets('TaskUpdate renders activeForm and status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TaskToolView(
            tool: {
              'name': 'TaskUpdate',
              'state': 'completed',
              'input': {
                'taskId': '7',
                'activeForm': 'Wrapping up',
                'status': 'in_progress',
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task #7'), findsOneWidget);
      expect(find.text('Wrapping up'), findsOneWidget);
      expect(find.text('in_progress'), findsOneWidget);
    });

    testWidgets('TaskList renders count and subjects from result',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TaskToolView(
            tool: {
              'name': 'TaskList',
              'state': 'completed',
              'result': {
                'tasks': [
                  {'subject': 'First', 'status': 'pending'},
                  {'subject': 'Second', 'status': 'completed'},
                ],
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 tasks'), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('pending'), findsOneWidget);
      expect(find.text('completed'), findsOneWidget);
    });

    testWidgets('TaskList singular count when only one item', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TaskToolView(
            tool: {
              'name': 'TaskList',
              'state': 'completed',
              'result': {
                'tasks': [
                  {'subject': 'Only', 'status': 'pending'},
                ],
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 task'), findsOneWidget);
    });

    testWidgets('TaskList empty result shows hint', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TaskToolView(
            tool: {
              'name': 'TaskList',
              'state': 'completed',
              'result': {'tasks': []},
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tasks in list'), findsOneWidget);
    });

    testWidgets('TaskGet renders subject from result', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TaskToolView(
            tool: {
              'name': 'TaskGet',
              'state': 'completed',
              'result': {
                'subject': 'Audit IPC',
                'status': 'in_progress',
                'activeForm': 'Auditing IPC',
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audit IPC'), findsOneWidget);
      expect(find.text('Auditing IPC'), findsOneWidget);
      expect(find.text('in_progress'), findsOneWidget);
    });

    testWidgets('TaskGet with no result falls back to id hint',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TaskToolView(
            tool: {
              'name': 'TaskGet',
              'state': 'completed',
              'input': {'taskId': '42'},
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No data for #42'), findsOneWidget);
    });

    testWidgets('Unknown task name renders nothing (no crash)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          TaskToolView(
            tool: {
              'name': 'TaskFuture',
              'state': 'completed',
              'input': {'subject': 'noop'},
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaskToolView), findsOneWidget);
    });
  });
}
