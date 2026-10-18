// Zen (tasks) home: what a user depends on — which tasks are listed, how
// they are grouped/ordered, and that tapping a task opens the session that
// task belongs to (never the first or the newest one).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/zen/views/zen_home.dart';

import '../../helpers/session_open_harness.dart';

TodoItem todo(
  String sessionId,
  String content, {
  String priority = 'medium',
  int order = 0,
  TodoState status = TodoState.pending,
}) {
  return TodoItem(
    id: '$sessionId-$content',
    content: content,
    status: status,
    priority: priority,
    order: order,
    createdAt: 1,
    updatedAt: 1,
    sessionId: sessionId,
  );
}

Session sessionWithTodos(
  String id,
  String label,
  List<TodoItem> todos, {
  String path = contractSessionPath,
}) {
  final base = contractSession(id: id, label: label);
  return base.copyWith(
    todos: todos,
    metadata: base.metadata!.copyWith(path: path),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionOpenRecorder recorder;
  late ProviderContainer container;

  Future<void> pumpZen(
    WidgetTester tester,
    Map<String, Session> sessions, {
    String? scopedSessionId,
  }) async {
    container = ProviderContainer(
      overrides: contractListOverrides(
        settings: Settings.new,
        sessions: sessions,
      ),
    );
    final router = buildSessionOpenRouter(
      recorder: recorder,
      home: (_) => ZenHomeScreen(sessionId: scopedSessionId),
    );
    await tester.pumpWidget(
      buildSessionOpenApp(container: container, router: router),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    recorder = SessionOpenRecorder();
  });

  tearDown(() {
    cancelContractChatSwitchMetrics();
    container.dispose();
  });

  group('task list content', () {
    testWidgets('empty state when no session has open tasks', (tester) async {
      await pumpZen(tester, contractSessions());

      expect(find.text('No active tasks'), findsOneWidget);
    });

    testWidgets('lists one row per open task with its session name', (
      tester,
    ) async {
      await pumpZen(tester, {
        contractAlphaId: sessionWithTodos(contractAlphaId, contractAlphaLabel, [
          todo(contractAlphaId, 'Wire the decoder'),
        ]),
        contractBravoId: sessionWithTodos(contractBravoId, contractBravoLabel, [
          todo(contractBravoId, 'Patch the parser'),
        ]),
      });

      expect(find.text('Wire the decoder'), findsOneWidget);
      expect(find.text('Patch the parser'), findsOneWidget);
      expect(find.text(contractAlphaLabel), findsOneWidget);
      expect(find.text(contractBravoLabel), findsOneWidget);
      expect(find.text('No active tasks'), findsNothing);
    });

    testWidgets('completed and cancelled tasks are hidden', (tester) async {
      await pumpZen(tester, {
        contractAlphaId: sessionWithTodos(contractAlphaId, contractAlphaLabel, [
          todo(contractAlphaId, 'Still open'),
          todo(contractAlphaId, 'Done', status: TodoState.completed),
          todo(contractAlphaId, 'Dropped', status: TodoState.canceled),
        ]),
      });

      expect(find.text('Still open'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Dropped'), findsNothing);
    });

    testWidgets('tasks are ordered by their order field, not insertion', (
      tester,
    ) async {
      await pumpZen(tester, {
        contractAlphaId: sessionWithTodos(contractAlphaId, contractAlphaLabel, [
          todo(contractAlphaId, 'Third', order: 3),
          todo(contractAlphaId, 'First', order: 1),
          todo(contractAlphaId, 'Second', order: 2),
        ]),
      });

      final firstY = tester.getTopLeft(find.text('First')).dy;
      final secondY = tester.getTopLeft(find.text('Second')).dy;
      final thirdY = tester.getTopLeft(find.text('Third')).dy;
      expect(firstY, lessThan(secondY));
      expect(secondY, lessThan(thirdY));
    });

    testWidgets('live provider tasks override the session snapshot', (
      tester,
    ) async {
      final sessions = {
        contractAlphaId: sessionWithTodos(contractAlphaId, contractAlphaLabel, [
          todo(contractAlphaId, 'Stale server task'),
        ]),
      };
      container = ProviderContainer(
        overrides: contractListOverrides(
          settings: Settings.new,
          sessions: sessions,
        ),
      );
      container
          .read(todoStateNotifierProvider.notifier)
          .setItemsForSession(contractAlphaId, [
            todo(contractAlphaId, 'Fresh live task'),
          ]);
      final router = buildSessionOpenRouter(
        recorder: recorder,
        home: (_) => const ZenHomeScreen(),
      );
      await tester.pumpWidget(
        buildSessionOpenApp(container: container, router: router),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fresh live task'), findsOneWidget);
      expect(find.text('Stale server task'), findsNothing);
    });
  });

  group('grouping', () {
    testWidgets('unscoped view groups by working directory with counts', (
      tester,
    ) async {
      await pumpZen(tester, {
        contractAlphaId: sessionWithTodos(
          contractAlphaId,
          contractAlphaLabel,
          [todo(contractAlphaId, 'Alpha task')],
          path: '/home/dev/aardvark',
        ),
        contractBravoId: sessionWithTodos(
          contractBravoId,
          contractBravoLabel,
          [
            todo(contractBravoId, 'Bravo task one'),
            todo(contractBravoId, 'Bravo task two', order: 1),
          ],
          path: '/home/dev/zebra',
        ),
      });

      expect(find.textContaining('aardvark'), findsOneWidget);
      expect(find.textContaining('zebra'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // Directory sections are ordered by label.
      expect(
        tester.getTopLeft(find.textContaining('aardvark')).dy,
        lessThan(tester.getTopLeft(find.textContaining('zebra')).dy),
      );
    });

    testWidgets('collapsing a directory hides its tasks', (tester) async {
      await pumpZen(tester, {
        contractAlphaId: sessionWithTodos(contractAlphaId, contractAlphaLabel, [
          todo(contractAlphaId, 'Collapsible task'),
        ]),
      });
      expect(find.text('Collapsible task'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.folder_rounded));
      await tester.pumpAndSettle();

      // AnimatedCrossFade keeps the collapsed body mounted but clipped
      // to zero height, so assert on what the user can actually touch.
      expect(find.text('Collapsible task').hitTestable(), findsNothing);
    });

    testWidgets('scoped view shows only that session, grouped by priority', (
      tester,
    ) async {
      await pumpZen(
        tester,
        {
          contractAlphaId: sessionWithTodos(
            contractAlphaId,
            contractAlphaLabel,
            [
              todo(contractAlphaId, 'Low task', priority: 'low'),
              todo(contractAlphaId, 'Critical task', priority: 'critical'),
            ],
          ),
          contractBravoId: sessionWithTodos(
            contractBravoId,
            contractBravoLabel,
            [todo(contractBravoId, 'Other session task')],
          ),
        },
        scopedSessionId: contractAlphaId,
      );

      expect(find.text('Other session task'), findsNothing);
      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      // Critical outranks low regardless of insertion order.
      expect(
        tester.getTopLeft(find.text('Critical task')).dy,
        lessThan(tester.getTopLeft(find.text('Low task')).dy),
      );
      // The app bar names the scoped session.
      expect(find.text(contractAlphaLabel), findsWidgets);
    });

    testWidgets('unknown priority falls back to the low section', (
      tester,
    ) async {
      await pumpZen(
        tester,
        {
          contractAlphaId: sessionWithTodos(
            contractAlphaId,
            contractAlphaLabel,
            [todo(contractAlphaId, 'Odd task', priority: 'urgent-ish')],
          ),
        },
        scopedSessionId: contractAlphaId,
      );

      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Odd task'), findsOneWidget);
    });
  });

  group('task tap opens its own session', () {
    testWidgets('each row routes to the session that owns the task', (
      tester,
    ) async {
      await pumpZen(tester, {
        contractAlphaId: sessionWithTodos(contractAlphaId, contractAlphaLabel, [
          todo(contractAlphaId, 'Alpha task'),
        ]),
        contractBravoId: sessionWithTodos(contractBravoId, contractBravoLabel, [
          todo(contractBravoId, 'Bravo task'),
        ]),
        contractCharlieId: sessionWithTodos(
          contractCharlieId,
          contractCharlieLabel,
          [todo(contractCharlieId, 'Charlie task')],
        ),
      });

      await tester.tap(find.text('Charlie task'));
      await tester.pumpAndSettle();
      expect(recorder.opened, [contractCharlieId]);
    });

    testWidgets('archived owner still opens its own session', (tester) async {
      final archived = contractSession(
        id: contractDeltaId,
        label: contractDeltaLabel,
        archived: true,
      );
      await pumpZen(tester, {
        contractAlphaId: sessionWithTodos(contractAlphaId, contractAlphaLabel, [
          todo(contractAlphaId, 'Alpha task'),
        ]),
        contractDeltaId: archived.copyWith(
          todos: [todo(contractDeltaId, 'Archived task')],
        ),
      });

      await tester.tap(find.text('Archived task'));
      await tester.pumpAndSettle();
      expect(recorder.opened, [contractDeltaId]);
    });
  });
}
