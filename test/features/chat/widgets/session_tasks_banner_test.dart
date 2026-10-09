// Contract tests for the per-session tasks banner in chat.
//
// Pinned invariants:
//   1. The banner is empty (zero-sized) when no tasks exist for the
//      active session.
//   2. The banner's "X of Y complete" header is sourced from the
//      session-scoped bucket, not the union across sessions.
//   3. Tapping the header expands the list; tapping again collapses it.
//   4. Tasks pushed under a different sessionId never leak into the
//      current banner.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/chat/widgets/session_tasks_banner.dart';

class _StubSessionsNotifier extends SessionsNotifier {
  @override
  Map<String, Session> build() => {};

  void replace(Session session) {
    state = {session.id: session};
  }

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionTasksBanner', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          sessionsNotifierProvider.overrideWith(_StubSessionsNotifier.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget wrap(Widget child) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          // _ToggleButton reads context.l10n; without the delegates the
          // lookup null-checks and every expanded-list test dies.
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Column(children: [child])),
        ),
      );
    }

    TodoItem item(
      String id,
      TodoState status, {
      String? content,
      String? description,
      String? parentId,
      String? agentId,
    }) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return TodoItem(
        id: id,
        content: content ?? 'item-$id',
        status: status,
        priority: 'medium',
        order: 0,
        description: description,
        parentId: parentId,
        agentId: agentId,
        createdAt: now,
        updatedAt: now,
      );
    }

    testWidgets('renders nothing when no tasks for the session', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      // Banner is hidden — no header, no list.
      expect(find.textContaining('complete'), findsNothing);
      expect(find.byIcon(Icons.checklist_rounded), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('shows task title and progress for the active session', (
      tester,
    ) async {
      container
          .read(todoStateNotifierProvider.notifier)
          .setItemsForSession('s1', [
            item('a', TodoState.completed),
            item('b', TodoState.inProgress),
            item('c', TodoState.pending),
          ]);

      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('1 of 3 complete · 1 running'), findsOneWidget);
      // Segmented meter: one pill per task, gradient-filled pills equal the
      // completed count (1 of 3 here).
      bool isSegment(Widget w) =>
          w is DecoratedBox &&
          (w.decoration as BoxDecoration).borderRadius != null;
      final segments = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byKey(const ValueKey('session-tasks-progress')),
              matching: find.byWidgetPredicate(isSegment),
            ),
          )
          .toList();
      expect(segments.length, 3);
      final filled = segments
          .where((s) => (s.decoration as BoxDecoration).gradient != null)
          .length;
      expect(filled, 1);
      // "View all" link is visible.
      expect(find.text('View all'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tasks, 1 of 3 complete · 1 running'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('View all'), findsOneWidget);

      final viewAllSize = tester.getSize(
        find.widgetWithText(TextButton, 'View all'),
      );
      expect(viewAllSize.height, greaterThanOrEqualTo(AppControlSize.sm));
    });

    testWidgets('expands on header tap and reveals only active rows', (
      tester,
    ) async {
      container
          .read(todoStateNotifierProvider.notifier)
          .setItemsForSession('s1', [
            item('a', TodoState.completed, content: 'First task'),
            item('b', TodoState.inProgress, content: 'Second task'),
            item('c', TodoState.canceled, content: 'Canceled task'),
          ]);

      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      // Collapsed: per-item text is NOT in the tree.
      expect(find.text('First task'), findsNothing);
      expect(find.text('Second task'), findsNothing);

      // Tap the header to expand.
      await tester.tap(find.textContaining('complete'));
      await tester.pumpAndSettle();

      expect(find.text('First task'), findsNothing);
      expect(find.text('Second task'), findsOneWidget);
      expect(find.text('Canceled task'), findsNothing);
      expect(find.text('1 of 3 complete · 1 running'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
    });

    testWidgets('nests children and shows inherited agent', (tester) async {
      container
          .read(todoStateNotifierProvider.notifier)
          .setItemsForSession('s1', [
            item(
              'child',
              TodoState.pending,
              content: 'Child task',
              parentId: 'parent',
            ),
            item(
              'parent',
              TodoState.pending,
              content: 'Parent task',
              agentId: 'agent-a',
            ),
          ]);
      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('complete'));
      await tester.pumpAndSettle();
      expect(find.text('Assigned to agent-a'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Parent task')).dy,
        lessThan(tester.getTopLeft(find.text('Child task')).dy),
      );
    });

    testWidgets('completion removes a row while canonical progress remains', (
      tester,
    ) async {
      final notifier = container.read(todoStateNotifierProvider.notifier);
      notifier.setItemsForSession('s1', [
        item('a', TodoState.pending, content: 'Finish now'),
        item('b', TodoState.pending, content: 'Still active'),
      ]);
      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('complete'));
      await tester.pumpAndSettle();

      notifier.markComplete('a');
      await tester.pumpAndSettle();

      expect(find.text('Finish now'), findsNothing);
      expect(find.text('Still active'), findsOneWidget);
      expect(find.text('1 of 2 complete'), findsOneWidget);
      expect(
        container.read(todoStateNotifierProvider).bySession['s1'],
        hasLength(2),
      );
    });

    testWidgets('hides a live snapshot containing only terminal rows', (
      tester,
    ) async {
      container.read(todoStateNotifierProvider.notifier).setItemsForSession(
        's1',
        [
          item('done', TodoState.completed),
          item('canceled', TodoState.canceled),
        ],
      );
      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsNothing);
      expect(find.text('View all'), findsNothing);
      expect(
        find.byKey(const ValueKey('session-tasks-progress')),
        findsNothing,
      );
    });

    testWidgets(
      'persisted active child inherits its hidden parent assignment',
      (tester) async {
        final todos = TodoItem.listFromJson([
          {
            'id': 'parent',
            'content': 'Completed parent',
            'status': 'completed',
            'agentId': 'agent-a',
          },
          {
            'id': 'child',
            'content': 'Active child',
            'status': 'pending',
            'parentId': 'parent',
          },
          {'id': 'peer', 'content': 'Active peer', 'status': 'pending'},
          {'id': 'canceled', 'content': 'Canceled row', 'status': 'canceled'},
        ])!;
        final sessions =
            container.read(sessionsNotifierProvider.notifier)
                as _StubSessionsNotifier;
        sessions.replace(_session(todos));
        await tester.pumpWidget(
          wrap(const SessionTasksBanner(sessionId: 's1')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('complete'));
        await tester.pumpAndSettle();

        expect(find.text('Completed parent'), findsNothing);
        expect(find.text('Canceled row'), findsNothing);
        expect(find.text('Active child'), findsOneWidget);
        expect(find.text('Assigned to agent-a'), findsOneWidget);
        expect(find.text('1 of 4 complete'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Active child')).dx,
          tester.getTopLeft(find.text('Active peer')).dx,
        );

        sessions.replace(
          _session([
            for (final todo in todos)
              todo.copyWith(status: TodoState.completed),
          ]),
        );
        await tester.pumpAndSettle();
        expect(find.text('Tasks'), findsNothing);
        expect(find.text('Active child'), findsNothing);
      },
    );

    testWidgets('does not leak tasks from other sessions', (tester) async {
      container.read(todoStateNotifierProvider.notifier).setItemsForSession(
        's1',
        [item('a', TodoState.pending)],
      );
      container
          .read(todoStateNotifierProvider.notifier)
          .setItemsForSession('s2', [
            item('b', TodoState.pending, content: 'Other session task'),
            item('c', TodoState.pending, content: 'Also other session'),
          ]);

      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      // s1 has 1 task.
      expect(find.textContaining('0 of 1 complete'), findsOneWidget);

      // Tap header to expand and confirm only s1's items render.
      await tester.tap(find.textContaining('complete'));
      await tester.pumpAndSettle();

      expect(find.text('item-a'), findsOneWidget);
      expect(find.text('Other session task'), findsNothing);
      expect(find.text('Also other session'), findsNothing);
    });

    testWidgets('header counts update reactively when todos change', (
      tester,
    ) async {
      final notifier = container.read(todoStateNotifierProvider.notifier);
      notifier.setItemsForSession('s1', [item('a', TodoState.pending)]);

      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('0 of 1 complete'), findsOneWidget);

      // Agent updates the list — new task added, first one completed.
      notifier.setItemsForSession('s1', [
        item('a', TodoState.completed),
        item('b', TodoState.pending),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('1 of 2 complete'), findsOneWidget);
    });

    testWidgets('last completed task hides immediately and can reopen', (
      tester,
    ) async {
      final notifier = container.read(todoStateNotifierProvider.notifier);
      notifier.setItemsForSession('s1', [
        item('a', TodoState.pending, content: 'Toggle me'),
      ]);

      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('0 of 1 complete'), findsOneWidget);

      // Expand and tap the checkbox (not the row, which opens detail).
      await tester.tap(find.textContaining('complete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check_box_outline_blank_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('complete'), findsNothing);
      expect(find.text('Toggle me'), findsNothing);
      expect(
        container
            .read(todoStateNotifierProvider)
            .bySession['s1']!
            .single
            .status,
        TodoState.completed,
      );

      notifier.toggleComplete('a');
      await tester.pumpAndSettle();
      expect(find.textContaining('0 of 1 complete'), findsOneWidget);
      expect(find.text('Toggle me'), findsOneWidget);
    });

    testWidgets('tapping a row opens the detail dialog', (tester) async {
      final notifier = container.read(todoStateNotifierProvider.notifier);
      notifier.setItemsForSession('s1', [
        item(
          'a',
          TodoState.pending,
          content: 'Plan migration',
          description: 'Decide how to split the sync singleton.',
        ),
      ]);

      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('complete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Plan migration'));
      await tester.pumpAndSettle();

      // Dialog shows the full description and a close action.
      expect(
        find.text('Decide how to split the sync singleton.'),
        findsWidgets,
      );
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('abbreviated description is shown in the row', (tester) async {
      final notifier = container.read(todoStateNotifierProvider.notifier);
      notifier.setItemsForSession('s1', [
        item(
          'a',
          TodoState.pending,
          content: 'Short',
          description: 'A'.padLeft(90, 'A'),
        ),
      ]);

      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('complete'));
      await tester.pumpAndSettle();

      // The full 90-char string should not be rendered verbatim.
      expect(find.text('A'.padLeft(90, 'A')), findsNothing);
      // But the truncated form ending with an ellipsis should be present.
      expect(find.textContaining('A'.padLeft(60, 'A')), findsOneWidget);
    });

    testWidgets('toggle button flips completion without opening dialog', (
      tester,
    ) async {
      final notifier = container.read(todoStateNotifierProvider.notifier);
      notifier.setItemsForSession('s1', [
        item(
          'a',
          TodoState.pending,
          content: 'Toggle me',
          description: 'Detail text.',
        ),
      ]);

      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('complete'));
      await tester.pumpAndSettle();

      // Tap the checkbox (outline blank) instead of the row text.
      await tester.tap(find.byIcon(Icons.check_box_outline_blank_rounded));
      await tester.pumpAndSettle();

      // The completed row and banner hide; the dialog did not open.
      expect(find.textContaining('complete'), findsNothing);
      expect(find.text('Toggle me'), findsNothing);
      expect(find.text('Close'), findsNothing);
    });
  });
}

Session _session(List<TodoItem> todos) => Session(
  id: 's1',
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: true,
  activeAt: 1,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: true,
  presence: 'online',
  todos: todos,
  metadata: const Metadata(host: 'localhost', path: '/workspace/project'),
);
