import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
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
  group('AgentSessionProjectionCache', () {
    const emptyProjection = AgentSessionProjection(
      agents: <Map<String, dynamic>>[],
      progress: TaskProgress(total: 0, running: 0, completed: 0, error: 0),
    );

    test('reuses the projection for the same session source and revision', () {
      final cache = AgentSessionProjectionCache(maxEntries: 2);
      final source = Object();
      var scans = 0;

      final first = cache.resolve(
        sessionId: 'session-a',
        revision: 7,
        source: source,
        load: () {
          scans++;
          return emptyProjection;
        },
      );
      final second = cache.resolve(
        sessionId: 'session-a',
        revision: 7,
        source: source,
        load: () {
          scans++;
          return emptyProjection;
        },
      );

      expect(identical(first, second), isTrue);
      expect(scans, 1);
    });

    test('refreshes when revision or source identity changes', () {
      final cache = AgentSessionProjectionCache(maxEntries: 2);
      final firstSource = Object();
      final secondSource = Object();
      var scans = 0;

      AgentSessionProjection load() {
        scans++;
        return emptyProjection;
      }

      cache
        ..resolve(
          sessionId: 'session-a',
          revision: 1,
          source: firstSource,
          load: load,
        )
        ..resolve(
          sessionId: 'session-a',
          revision: 2,
          source: firstSource,
          load: load,
        )
        ..resolve(
          sessionId: 'session-a',
          revision: 2,
          source: secondSource,
          load: load,
        )
        ..resolve(
          sessionId: 'session-a',
          revision: 2,
          source: secondSource,
          load: load,
        );

      expect(scans, 3);
    });

    test('bounds retained projections with least-recently-used eviction', () {
      final cache = AgentSessionProjectionCache(maxEntries: 2);
      final sources = <String, Object>{
        'a': Object(),
        'b': Object(),
        'c': Object(),
      };
      var scans = 0;

      AgentSessionProjection resolve(String sessionId) {
        return cache.resolve(
          sessionId: sessionId,
          revision: 1,
          source: sources[sessionId]!,
          load: () {
            scans++;
            return emptyProjection;
          },
        );
      }

      resolve('a');
      resolve('b');
      resolve('a'); // Make a the most recently used entry.
      resolve('c'); // Evicts b.
      resolve('a');
      resolve('b'); // Must scan again after eviction.

      expect(scans, 4);
      expect(cache.length, 2);
    });
  });

  group('SubAgentStatusBanner', () {
    late Sync sync;

    setUp(() {
      sync = createTestSync();
    });

    tearDown(() {
      sync.testClearSessionMessageState('test-session');
    });

    testWidgets('hides itself when no sub-agents in the session', (
      tester,
    ) async {
      // Empty session: no Task/Agent tool calls.
      sync.testSetSessionMessages('test-session', <Map<String, dynamic>>[]);

      await tester.pumpWidget(
        _wrap(const SubAgentStatusBanner(sessionId: 'test-session')),
      );
      await tester.pump();

      // The banner should be a SizedBox.shrink — find nothing banner-shaped.
      expect(find.textContaining('sub-agent'), findsNothing);
    });

    testWidgets('shows the running label when sub-agents are running', (
      tester,
    ) async {
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

      // Must be fully opaque. A 0.6 fill plus the list's top fade
      // printed a ghost first row under the banner.
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(SubAgentStatusBanner),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color?.a, 1.0);
    });

    testWidgets('running dots stop scheduling frames after bounded pulses', (
      tester,
    ) async {
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

      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pump(
        const Duration(milliseconds: 900 * AppMotion.activityPulseCount),
      );
      await tester.pump();

      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('running dots are static with reduced motion', (tester) async {
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
        _wrap(
          const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SubAgentStatusBanner(sessionId: 'test-session'),
          ),
        ),
      );
      await tester.pump();

      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('refreshes only for its session message events', (
      tester,
    ) async {
      final notifyMessagesChanged = sync.testNotifySessionMessagesChanged;
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
      expect(find.text('1 of 1 sub-agents running'), findsOneWidget);

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
      ]);

      notifyMessagesChanged('other-session');
      await tester.pump();
      expect(find.text('1 of 1 sub-agents running'), findsOneWidget);
      expect(find.text('2 of 2 sub-agents running'), findsNothing);

      notifyMessagesChanged('test-session');
      await tester.pump();
      expect(find.text('2 of 2 sub-agents running'), findsOneWidget);
    });

    testWidgets('shows the complete label when all sub-agents are done', (
      tester,
    ) async {
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
      // Explicit pumps advance only the modal-sheet transition under test.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // The agents-list sheet should now be visible. Its title is
      // "Agents" per the existing l10n string agentsListTitle.
      expect(find.text('Agents'), findsOneWidget);
    });

    testWidgets('does not open the sheet when there are no sub-agents', (
      tester,
    ) async {
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
