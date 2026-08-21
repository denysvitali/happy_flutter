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
import 'package:happy_flutter/core/i18n/app_localizations.dart';
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
      final segments = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(const ValueKey('session-tasks-progress')),
          matching: find.byWidgetPredicate(isSegment),
        ),
      ).toList();
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
      expect(viewAllSize.height, greaterThanOrEqualTo(44));
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
      await tester.tap(find.textContaining('complete'));
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

    testWidgets('toggling a task flips its count', (tester) async {
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

      expect(find.textContaining('1 of 1 complete'), findsOneWidget);
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

      // Completion count updated; dialog did not open.
      expect(find.textContaining('1 of 1 complete'), findsOneWidget);
      expect(find.text('Close'), findsNothing);
    });
  });
}
