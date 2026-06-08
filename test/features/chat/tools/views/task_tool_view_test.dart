import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/chat/tools/views/task_tool_view.dart';

Widget _wrap(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskToolView — rendering', () {
    testWidgets('TaskCreate renders subject and status', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
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

  group('TaskToolView — global todo state side effects', () {
    testWidgets('TaskCreate pushes a single item into the session bucket',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const sessionId = 's1';

      await tester.pumpWidget(
        _wrap(
          container,
          TaskToolView(
            tool: {
              'name': 'TaskCreate',
              'toolUseId': 'call-1',
              'state': 'completed',
              'input': {
                'subject': 'Reverse QtCarVehicle binary',
                'activeForm': 'Reversing the binary',
                'status': 'pending',
              },
            },
            sessionId: sessionId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final items = container
          .read(todoStateNotifierProvider)
          .bySession[sessionId];
      expect(items, isNotNull);
      expect(items, hasLength(1));
      expect(items!.first.content, 'Reverse QtCarVehicle binary');
      expect(items.first.status, TodoState.pending);
    });

    testWidgets('TaskList replaces the session bucket with all listed tasks',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const sessionId = 's1';

      await tester.pumpWidget(
        _wrap(
          container,
          TaskToolView(
            tool: {
              'name': 'TaskList',
              'toolUseId': 'call-list',
              'result': {
                'tasks': [
                  {'id': 'a', 'subject': 'A', 'status': 'pending'},
                  {'id': 'b', 'subject': 'B', 'status': 'in_progress'},
                  {'id': 'c', 'subject': 'C', 'status': 'completed'},
                ],
              },
            },
            sessionId: sessionId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final items = container
          .read(todoStateNotifierProvider)
          .bySession[sessionId];
      expect(items, hasLength(3));
      expect(items!.map((e) => e.content).toList(),
          equals(['A', 'B', 'C']));
      expect(items[0].status, TodoState.pending);
      expect(items[1].status, TodoState.inProgress);
      expect(items[2].status, TodoState.completed);
    });

    testWidgets('TaskUpdate mutates the matching item by id', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const sessionId = 's1';

      // Seed the bucket by mounting a TaskCreate.
      await tester.pumpWidget(
        _wrap(
          container,
          TaskToolView(
            tool: {
              'name': 'TaskCreate',
              'toolUseId': 'call-seed',
              'input': {'id': 'a', 'subject': 'A', 'status': 'pending'},
            },
            sessionId: sessionId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Now mount a TaskUpdate for the same id.
      await tester.pumpWidget(
        _wrap(
          container,
          TaskToolView(
            tool: {
              'name': 'TaskUpdate',
              'toolUseId': 'call-upd',
              'input': {'taskId': 'a', 'status': 'completed'},
            },
            sessionId: sessionId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final items = container
          .read(todoStateNotifierProvider)
          .bySession[sessionId];
      expect(items, hasLength(1));
      expect(items!.first.id, 'a');
      expect(items.first.status, TodoState.completed);
      expect(items.first.completedAt, isNotNull);
    });

    testWidgets('Different sessions do not clobber each other', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pump two views into two separate subtrees by using a Column.
      await tester.pumpWidget(
        _wrap(
          container,
          Column(
            children: [
              TaskToolView(
                tool: {
                  'name': 'TaskCreate',
                  'toolUseId': 'call-A',
                  'input': {'id': 'a', 'subject': 'A'},
                },
                sessionId: 's1',
              ),
              TaskToolView(
                tool: {
                  'name': 'TaskCreate',
                  'toolUseId': 'call-B',
                  'input': {'id': 'b', 'subject': 'B'},
                },
                sessionId: 's2',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = container.read(todoStateNotifierProvider);
      expect(state.bySession['s1']!.first.content, 'A');
      expect(state.bySession['s2']!.first.content, 'B');
    });
  });

  group('TaskToolView — collapsed parent still drives global state', () {
    // Regression: the in-app task list (session banner, Zen home) used to
    // stay stale until the user expanded the inline tool view. Root cause:
    // TaskToolView's body lived inside an AnimatedSize that unmounts when
    // collapsed, so its initState/didUpdateWidget never fired for tools
    // that completed while hidden. The fix is to drive the global notifier
    // push from the always-mounted parent (ToolView) too.

    testWidgets(
      'ToolView pushes task data even when its body never mounts',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        const sessionId = 's-collapsed';

        // Use the static entry point directly — this is what ToolView
        // calls from didUpdateWidget. We bypass the body mount entirely
        // to prove the global state path works without the conditional
        // AnimatedSize subtree.
        final tool = <String, dynamic>{
          'name': 'TaskCreate',
          'toolUseId': 'call-collapsed',
          'state': 'completed',
          'input': {
            'subject': 'Item created while collapsed',
            'status': 'in_progress',
          },
        };

        late BuildContext ctx;
        await tester.pumpWidget(
          _wrap(
            container,
            Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        TaskToolView.pushToolToGlobalState(ctx, tool, sessionId);

        final items = container
            .read(todoStateNotifierProvider)
            .bySession[sessionId];
        expect(items, isNotNull);
        expect(items, hasLength(1));
        expect(items!.first.content, 'Item created while collapsed');
        expect(items.first.status, TodoState.inProgress);
      },
    );
  });
}
