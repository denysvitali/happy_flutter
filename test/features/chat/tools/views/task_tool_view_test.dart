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

    testWidgets('TaskList renders count and subjects from result', (
      tester,
    ) async {
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

    testWidgets('TaskGet with no result falls back to id hint', (tester) async {
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

    testWidgets('Unknown task name renders nothing (no crash)', (tester) async {
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
    testWidgets('TaskCreate pushes a single item into the session bucket', (
      tester,
    ) async {
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

    testWidgets('TaskList replaces the session bucket with all listed tasks', (
      tester,
    ) async {
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
      expect(items!.map((e) => e.content).toList(), equals(['A', 'B', 'C']));
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

  group('TaskToolView — production plain-text wire shapes', () {
    // The harness returns task tool results as plain text, not JSON:
    //   TaskCreate → "Task #1 created successfully: <subject>"
    //   TaskList   → "#1 [pending] <subject>" per line
    //   TaskGet    → "Task #1: <subject>\nStatus: <status>\n..."
    // The real task id only exists in the TaskCreate *result*; TaskUpdate
    // then references it via input.taskId. Regression: items used to be
    // stored under a synthetic "toolUseId#create-<subject>" id, so
    // TaskUpdate never matched and the session banner never refreshed.

    late BuildContext ctx;

    Future<ProviderContainer> pumpHost(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
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
      return container;
    }

    testWidgets('TaskCreate text result assigns the harness task id', (
      tester,
    ) async {
      final container = await pumpHost(tester);
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskCreate',
        'toolUseId': 'call-1',
        'state': 'completed',
        'createdAt': 1000,
        'input': {'subject': 'Fix the banner', 'description': 'd'},
        'result': 'Task #1 created successfully: Fix the banner',
      }, 's1');

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items.single.id, '1');
      expect(items.single.content, 'Fix the banner');
    });

    testWidgets(
      'TaskUpdate by harness id flips the item created from text result',
      (tester) async {
        final container = await pumpHost(tester);
        TaskToolView.pushToolToGlobalState(ctx, {
          'name': 'TaskCreate',
          'toolUseId': 'call-1',
          'createdAt': 1000,
          'input': {'subject': 'Fix the banner'},
          'result': 'Task #1 created successfully: Fix the banner',
        }, 's1');
        TaskToolView.pushToolToGlobalState(ctx, {
          'name': 'TaskUpdate',
          'toolUseId': 'call-2',
          'createdAt': 2000,
          'input': {'taskId': '1', 'status': 'in_progress'},
        }, 's1');

        final items = container
            .read(todoStateNotifierProvider)
            .bySession['s1']!;
        expect(items.single.status, TodoState.inProgress);
      },
    );

    testWidgets('TaskCreate running-then-result migrates the synthetic id so a '
        'later TaskUpdate matches', (tester) async {
      final container = await pumpHost(tester);
      // Push while running: no result yet → synthetic id.
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskCreate',
        'toolUseId': 'call-1',
        'state': 'running',
        'createdAt': 1000,
        'input': {'subject': 'Fix the banner'},
      }, 's1');
      // Result arrives → same tool re-pushed with the harness id.
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskCreate',
        'toolUseId': 'call-1',
        'state': 'completed',
        'createdAt': 1000,
        'completedAt': 1500,
        'input': {'subject': 'Fix the banner'},
        'result': 'Task #1 created successfully: Fix the banner',
      }, 's1');
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskUpdate',
        'toolUseId': 'call-2',
        'createdAt': 2000,
        'input': {'taskId': '1', 'status': 'completed'},
      }, 's1');

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items, hasLength(1));
      expect(items.single.id, '1');
      expect(items.single.status, TodoState.completed);
      expect(items.single.completedAt, isNotNull);
    });

    testWidgets('TaskUpdate without status keeps the current status', (
      tester,
    ) async {
      final container = await pumpHost(tester);
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskCreate',
        'toolUseId': 'call-1',
        'createdAt': 1000,
        'input': {'subject': 'Fix the banner', 'status': 'in_progress'},
        'result': 'Task #1 created successfully: Fix the banner',
      }, 's1');
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskUpdate',
        'toolUseId': 'call-2',
        'createdAt': 2000,
        'input': {'taskId': '1', 'owner': 'agent-a'},
      }, 's1');

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items.single.status, TodoState.inProgress);
    });

    testWidgets('TaskUpdate status deleted removes the item', (tester) async {
      final container = await pumpHost(tester);
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskCreate',
        'toolUseId': 'call-1',
        'createdAt': 1000,
        'input': {'subject': 'Obsolete'},
        'result': 'Task #1 created successfully: Obsolete',
      }, 's1');
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskUpdate',
        'toolUseId': 'call-2',
        'createdAt': 2000,
        'input': {'taskId': '1', 'status': 'deleted'},
      }, 's1');

      expect(
        container.read(todoStateNotifierProvider).bySession['s1'],
        isEmpty,
      );
    });

    testWidgets('TaskList plain-text result replaces the bucket', (
      tester,
    ) async {
      final container = await pumpHost(tester);
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskList',
        'toolUseId': 'call-1',
        'createdAt': 1000,
        'result': '#1 [completed] First thing\n#2 [in_progress] Second thing',
      }, 's1');

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items, hasLength(2));
      expect(items[0].id, '1');
      expect(items[0].status, TodoState.completed);
      expect(items[1].id, '2');
      expect(items[1].content, 'Second thing');
      expect(items[1].status, TodoState.inProgress);
    });

    testWidgets('TaskList without result does not wipe known tasks', (
      tester,
    ) async {
      final container = await pumpHost(tester);
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskCreate',
        'toolUseId': 'call-1',
        'createdAt': 1000,
        'input': {'subject': 'Keep me'},
        'result': 'Task #1 created successfully: Keep me',
      }, 's1');
      // TaskList still running — result not yet attached.
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskList',
        'toolUseId': 'call-2',
        'state': 'running',
        'createdAt': 2000,
      }, 's1');

      expect(
        container.read(todoStateNotifierProvider).bySession['s1'],
        hasLength(1),
      );
    });

    testWidgets('TaskGet plain-text result upserts subject and status', (
      tester,
    ) async {
      final container = await pumpHost(tester);
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskGet',
        'toolUseId': 'call-1',
        'createdAt': 1000,
        'input': {'taskId': '3'},
        'result':
            'Task #3: Audit IPC\nStatus: in_progress\nDescription: details',
      }, 's1');

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items.single.id, '3');
      expect(items.single.content, 'Audit IPC');
      expect(items.single.status, TodoState.inProgress);
    });

    testWidgets('reverse-order replay (update before create) converges to the '
        'newest state', (tester) async {
      // Cold load mounts the reversed chat list newest-first, so the
      // TaskUpdate pushes before its TaskCreate.
      final container = await pumpHost(tester);
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskUpdate',
        'toolUseId': 'call-2',
        'createdAt': 2000,
        'input': {'taskId': '1', 'status': 'completed'},
      }, 's1');
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskCreate',
        'toolUseId': 'call-1',
        'createdAt': 1000,
        'input': {'subject': 'Fix the banner', 'status': 'pending'},
        'result': 'Task #1 created successfully: Fix the banner',
      }, 's1');

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items, hasLength(1));
      expect(items.single.id, '1');
      // Subject from the create, status from the (newer) update.
      expect(items.single.content, 'Fix the banner');
      expect(items.single.status, TodoState.completed);
    });

    testWidgets('older TaskList snapshot does not clobber newer item state', (
      tester,
    ) async {
      final container = await pumpHost(tester);
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskUpdate',
        'toolUseId': 'call-3',
        'createdAt': 3000,
        'input': {'taskId': '1', 'status': 'completed'},
      }, 's1');
      // Replayed older snapshot still says pending.
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'TaskList',
        'toolUseId': 'call-2',
        'createdAt': 2000,
        'result': '#1 [pending] Fix the banner',
      }, 's1');

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items.single.status, TodoState.completed);
    });

    testWidgets('Happy MCP todo_add content field creates an item', (
      tester,
    ) async {
      final container = await pumpHost(tester);
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'mcp__happy__todo_add',
        'toolUseId': 'call-mcp-1',
        'createdAt': 1000,
        'input': {'content': 'Ship progress MCP', 'status': 'pending'},
        'result': 'Added #1: Ship progress MCP\n#1 [pending] Ship progress MCP',
      }, 's1');

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items.single.content, 'Ship progress MCP');
      expect(items.single.status, TodoState.pending);
    });

    testWidgets('Happy MCP todo_remove drops the item', (tester) async {
      final container = await pumpHost(tester);
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'mcp__happy__todo_add',
        'toolUseId': 'call-mcp-1',
        'createdAt': 1000,
        'input': {'id': '1', 'content': 'Ship progress MCP'},
      }, 's1');
      TaskToolView.pushToolToGlobalState(ctx, {
        'name': 'mcp__happy__todo_remove',
        'toolUseId': 'call-mcp-2',
        'createdAt': 2000,
        'input': {'id': '1'},
      }, 's1');

      expect(
        container.read(todoStateNotifierProvider).bySession['s1'],
        isEmpty,
      );
    });
  });

  group('TaskToolView — collapsed parent still drives global state', () {
    // Regression: the in-app task list (session banner, Zen home) used to
    // stay stale until the user expanded the inline tool view. Root cause:
    // TaskToolView's body lived inside an AnimatedSize that unmounts when
    // collapsed, so its initState/didUpdateWidget never fired for tools
    // that completed while hidden. The fix is to drive the global notifier
    // push from the always-mounted parent (ToolView) too.

    testWidgets('ToolView pushes task data even when its body never mounts', (
      tester,
    ) async {
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
    });
  });
}
