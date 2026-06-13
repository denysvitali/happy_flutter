// Contract tests for the per-session tasks banner in chat.
//
// Pinned invariants:
//   1. The banner is empty (zero-sized) when no tasks exist for the
//      active session.
//   2. The banner's "X/Y done" header is sourced from the
//      session-scoped bucket, not the union across sessions.
//   3. Tapping the header expands the list; tapping again collapses it.
//   4. Tasks pushed under a different sessionId never leak into the
//      current banner.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/chat/widgets/session_tasks_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionTasksBanner', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    Widget wrap(Widget child) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: Column(children: [child])),
        ),
      );
    }

    TodoItem item(
      String id,
      TodoState status, {
      String? content,
      String? description,
    }) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return TodoItem(
        id: id,
        content: content ?? 'item-$id',
        status: status,
        priority: 'medium',
        order: 0,
        description: description,
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
      expect(find.textContaining('done'), findsNothing);
      expect(find.byIcon(Icons.checklist_rounded), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('shows "X/Y done" header for the active session', (
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

      expect(find.textContaining('1/3 done'), findsOneWidget);
      // "View all" link is visible.
      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('expands on header tap and reveals the full list', (
      tester,
    ) async {
      container
          .read(todoStateNotifierProvider.notifier)
          .setItemsForSession('s1', [
            item('a', TodoState.completed, content: 'First task'),
            item('b', TodoState.inProgress, content: 'Second task'),
          ]);

      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();

      // Collapsed: per-item text is NOT in the tree.
      expect(find.text('First task'), findsNothing);
      expect(find.text('Second task'), findsNothing);

      // Tap the header to expand.
      await tester.tap(find.textContaining('done'));
      await tester.pumpAndSettle();

      expect(find.text('First task'), findsOneWidget);
      expect(find.text('Second task'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
    });

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
      expect(find.textContaining('0/1 done'), findsOneWidget);

      // Tap header to expand and confirm only s1's items render.
      await tester.tap(find.textContaining('done'));
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
      expect(find.textContaining('0/1 done'), findsOneWidget);

      // Agent updates the list — new task added, first one completed.
      notifier.setItemsForSession('s1', [
        item('a', TodoState.completed),
        item('b', TodoState.pending),
      ]);
      await tester.pumpAndSettle();

      expect(find.textContaining('1/2 done'), findsOneWidget);
    });

    testWidgets('toggling a task flips its count', (tester) async {
      final notifier = container.read(todoStateNotifierProvider.notifier);
      notifier.setItemsForSession('s1', [
        item('a', TodoState.pending, content: 'Toggle me'),
      ]);

      await tester.pumpWidget(wrap(const SessionTasksBanner(sessionId: 's1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('0/1 done'), findsOneWidget);

      // Expand and tap the checkbox (not the row, which opens detail).
      await tester.tap(find.textContaining('done'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check_box_outline_blank_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('1/1 done'), findsOneWidget);
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

      await tester.tap(find.textContaining('done'));
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

      await tester.tap(find.textContaining('done'));
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

      await tester.tap(find.textContaining('done'));
      await tester.pumpAndSettle();

      // Tap the checkbox (outline blank) instead of the row text.
      await tester.tap(find.byIcon(Icons.check_box_outline_blank_rounded));
      await tester.pumpAndSettle();

      // Completion count updated; dialog did not open.
      expect(find.textContaining('1/1 done'), findsOneWidget);
      expect(find.text('Close'), findsNothing);
    });
  });
}
