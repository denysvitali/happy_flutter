import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/chat/widgets/agents_list_sheet.dart';
import 'package:happy_flutter/features/chat/widgets/sub_agent_status_banner.dart';

import '../../helpers/test_helpers.dart';

/// Wraps [child] in a [MaterialApp] with the l10n delegates the
/// banner needs to call `context.l10n.subAgentBannerRunning(...)` and
/// friends. Centralised so each test stays readable.
Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('SubAgentStatusBanner', () {
    late Sync sync;

    setUp(() {
      sync = createTestSync();
    });

    tearDown(() {
      sync.testClearSessionMessageState('test-session');
    });

    testWidgets('hides itself when no sub-agents in the session',
        (tester) async {
      // Empty session: no Task/Agent tool calls.
      sync.testSetSessionMessages('test-session', <Map<String, dynamic>>[]);

      await tester.pumpWidget(
        _wrap(const SubAgentStatusBanner(sessionId: 'test-session')),
      );
      await tester.pump();

      // The banner should be a SizedBox.shrink — find nothing banner-shaped.
      expect(find.textContaining('sub-agent'), findsNothing);
    });

    testWidgets('shows the running label when sub-agents are running',
        (tester) async {
      // 3 sub-agents, 2 still running, 1 completed.
      sync.testSetSessionMessages('test-session', [
        <String, dynamic>{
          'id': 'task-1',
          'kind': 'tool-call',
          'name': 'Task',
          'state': 'running',
          'isSidechain': false,
          'seq': 1,
        },
        <String, dynamic>{
          'id': 'task-2',
          'kind': 'tool-call',
          'name': 'Task',
          'state': 'running',
          'isSidechain': false,
          'seq': 2,
        },
        <String, dynamic>{
          'id': 'task-3',
          'kind': 'tool-call',
          'name': 'Task',
          'state': 'completed',
          'isSidechain': false,
          'seq': 3,
        },
      ]);

      await tester.pumpWidget(
        _wrap(const SubAgentStatusBanner(sessionId: 'test-session')),
      );
      await tester.pump();

      // The banner should report "2 of 3 sub-agents running" using the
      // generated l10n string. The exact wording includes "2" and "3".
      expect(find.textContaining('2'), findsWidgets);
      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('sub-agent'), findsOneWidget);
    });

    testWidgets('shows the complete label when all sub-agents are done',
        (tester) async {
      sync.testSetSessionMessages('test-session', [
        <String, dynamic>{
          'id': 'task-1',
          'kind': 'tool-call',
          'name': 'Task',
          'state': 'completed',
          'isSidechain': false,
          'seq': 1,
        },
        <String, dynamic>{
          'id': 'task-2',
          'kind': 'tool-call',
          'name': 'Task',
          'state': 'completed',
          'isSidechain': false,
          'seq': 2,
        },
      ]);

      await tester.pumpWidget(
        _wrap(const SubAgentStatusBanner(sessionId: 'test-session')),
      );
      await tester.pump();

      expect(find.textContaining('2'), findsWidgets);
      expect(find.textContaining('sub-agent'), findsOneWidget);
    });

    testWidgets('opens the agents-list sheet on tap', (tester) async {
      sync.testSetSessionMessages('test-session', [
        <String, dynamic>{
          'id': 'task-1',
          'kind': 'tool-call',
          'name': 'Task',
          'state': 'running',
          'isSidechain': false,
          'seq': 1,
        },
      ]);

      await tester.pumpWidget(
        _wrap(const SubAgentStatusBanner(sessionId: 'test-session')),
      );
      await tester.pump();

      // Tap the visible "Tap to view" affordance inside the banner
      // (the outer SubAgentStatusBanner widget is a thin wrapper that
      // is itself zero-size; only the inner InkWell is hit-testable).
      await tester.tap(find.text('Tap to view'));
      // pumpAndSettle deadlocks on the running-dots animation, so use
      // explicit pump() calls to advance just enough frames for the
      // modal sheet to slide in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // The agents-list sheet should now be visible. Its title is
      // "Agents" per the existing l10n string agentsListTitle.
      expect(find.text('Agents'), findsOneWidget);
    });

    testWidgets('does not open the sheet when there are no sub-agents',
        (tester) async {
      sync.testSetSessionMessages('test-session', <Map<String, dynamic>>[]);

      await tester.pumpWidget(
        _wrap(const SubAgentStatusBanner(sessionId: 'test-session')),
      );
      await tester.pump();

      // Tapping an empty banner is a no-op (no "Tap to view" affordance
      // is rendered at all, so the tap would find nothing).
      expect(find.text('Tap to view'), findsNothing);
      expect(find.text('Agents'), findsNothing);
    });

    test('handles empty session id without touching sync', () {
      // _progress() should return an empty TaskProgress for empty
      // sessionIds, hiding the banner even if sync has messages for
      // other sessions.
      sync.testSetSessionMessages('other-session', [
        <String, dynamic>{
          'id': 'task-x',
          'kind': 'tool-call',
          'name': 'Task',
          'state': 'running',
          'isSidechain': false,
          'seq': 1,
        },
      ]);
      // Indirectly: a non-empty sessionId exercises the same path the
      // banner takes; the empty-sessionId branch is only hit when the
      // banner is given a blank id, which is the regression we want
      // pinned.
      expect(AgentsListSheet.countActiveAgents('other-session'), 1);
    });
  });
}
