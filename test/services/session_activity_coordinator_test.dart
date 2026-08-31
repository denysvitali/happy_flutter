import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/session_activity_coordinator.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import '../helpers/test_helpers.dart';

Session _makeSession({
  required String id,
  bool thinking = false,
  AgentState? agentState,
  Metadata? metadata,
  int activeAt = 1_700_000_000_000,
  int? thinkingAt,
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: true,
    activeAt: activeAt,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: 'online',
    agentState: agentState,
    metadata: metadata,
    thinkingAt: thinkingAt,
  );
}

void main() {
  group('SessionActivityCoordinator.computeDecision', () {
    test('idle session yields a noop decision', () {
      final c = SessionActivityCoordinator();
      final d = c.computeDecision(_makeSession(id: 's1'));
      expect(d.isNoop, isTrue);
      expect(d.sessionId, 's1');
    });

    test('thinking session yields a show decision with tool name', () {
      final c = SessionActivityCoordinator();
      final session = _makeSession(
        id: 's1',
        thinking: true,
        thinkingAt: 1_700_000_001_000,
        agentState: AgentState(
          requests: {
            'p1': RequestInfo(tool: 'Bash', arguments: {'cmd': 'ls'}),
          },
        ),
        metadata: Metadata(path: '/home/me/proj'),
      );
      final d = c.computeDecision(session);
      expect(d.isShow, isTrue);
      expect(d.sessionId, 's1');
      expect(d.toolName, 'Bash');
      expect(d.startedAt, isNotNull);
      expect(
        d.startedAt!.millisecondsSinceEpoch,
        1_700_000_001_000,
      );
      // Falls back to last segment of path when summary is absent.
      expect(d.sessionName, 'proj');
    });

    test(
      'thinking session with no in-flight tool reports a placeholder',
      () {
        final c = SessionActivityCoordinator();
        final d = c.computeDecision(
          _makeSession(id: 's1', thinking: true),
        );
        expect(d.isShow, isTrue);
        expect(d.toolName, 'Thinking…');
      },
    );

    test('visibleSessionId suppresses the activity decision', () {
      final c = SessionActivityCoordinator()..visibleSessionId = 's1';
      final d = c.computeDecision(
        _makeSession(id: 's1', thinking: true),
      );
      // Not actively tracked yet, and we shouldn't start one for it.
      expect(d.isNoop, isTrue);
    });

    test(
      'leaving the thinking state for a tracked session yields end',
      () async {
        final c = SessionActivityCoordinator();
        // First mark s1 as thinking via applyDecision so internal
        // bookkeeping records it as active.
        await c.applyDecision(
          ActivityDecision.show(
            sessionId: 's1',
            toolName: 'Bash',
            startedAt: DateTime.now(),
          ),
        );
        expect(c.debugTrackedSessions, contains('s1'));

        final d = c.computeDecision(
          _makeSession(id: 's1', thinking: false),
        );
        expect(d.isEnd, isTrue);
      },
    );

    test('setVisibleSession ends an active activity for that session',
        () async {
      final c = SessionActivityCoordinator();
      await c.applyDecision(
        ActivityDecision.show(
          sessionId: 's1',
          toolName: 'Bash',
          startedAt: DateTime.now(),
        ),
      );
      expect(c.debugTrackedSessions, contains('s1'));
      await c.setVisibleSession('s1');
      expect(c.debugTrackedSessions, isNot(contains('s1')));
      expect(c.visibleSessionId, 's1');
    });
  });

  // Regression coverage for the Phase 1 safety net: ensures detach() (called
  // from syncShutdown) actually releases the periodic timer and the
  // domain-change subscription, and clears all in-flight activity
  // notifications. If the call site in syncShutdown is ever removed (or
  // detach() regresses), this test catches it.
  group('SessionActivityCoordinator.detach', () {
    test('clears all active notifications', () async {
      final c = SessionActivityCoordinator();
      await c.applyDecision(
        ActivityDecision.show(
          sessionId: 's1',
          toolName: 'Bash',
          startedAt: DateTime.now(),
        ),
      );
      await c.applyDecision(
        ActivityDecision.show(
          sessionId: 's2',
          toolName: 'Edit',
          startedAt: DateTime.now(),
        ),
      );
      expect(c.debugTrackedSessions, containsAll(['s1', 's2']));

      await c.detach();

      expect(c.debugTrackedSessions, isEmpty);
    });

    test('is idempotent — second detach is a no-op', () async {
      final c = SessionActivityCoordinator();
      await c.applyDecision(
        ActivityDecision.show(
          sessionId: 's1',
          toolName: 'Bash',
          startedAt: DateTime.now(),
        ),
      );

      await c.detach();
      // Second call must not throw, must keep the active map empty.
      await c.detach();
      expect(c.debugTrackedSessions, isEmpty);
    });

    test('attach() called twice replaces the prior subscription', () {
      // Without proper teardown, a second attach() would leak the
      // previous Timer + StreamSubscription. The cancel-on-reattach
      // behaviour in SessionActivityCoordinator.attach prevents that.
      // We assert it by calling attach twice and then detach — the
      // test must not throw and the state must be clean.
      final sync = createTestSync();
      final c = SessionActivityCoordinator()
        ..attach(sync)
        ..attach(sync);
      expect(c.debugTrackedSessions, isEmpty);
      // If both subscriptions leaked, this future would never complete
      // or detach() would not finish cancelling both. We bound it.
      return c.detach().timeout(const Duration(seconds: 1));
    });
  });

  // Freeze audit 2026-08-25: during a streaming turn, update-session events
  // bump SyncDomain.sessions up to ~10x/s, and each wave used to walk the
  // whole catalog (with a defensive toList copy) and re-post one platform
  // notification per thinking session. These tests pin the coalescing and
  // presentation dedup that bound that work.
  group('SessionActivityCoordinator event coalescing', () {
    test(
      'periodic refresh sleeps while idle but domain events discover work',
      () async {
        final sync = createTestSync();
        sync.testSessions['s1'] = _makeSession(id: 's1');
        final c = SessionActivityCoordinator(
          refreshInterval: const Duration(milliseconds: 20),
          eventReconcileCooldown: const Duration(milliseconds: 20),
        )..attach(sync);

        await Future<void>.delayed(const Duration(milliseconds: 70));
        expect(c.debugReconcileCount, 0);
        await c.detach();

        final discovery = SessionActivityCoordinator(
          refreshInterval: const Duration(hours: 1),
          eventReconcileCooldown: const Duration(milliseconds: 20),
        )..attach(sync);
        sync.testSessions['s1'] = _makeSession(id: 's1', thinking: true);
        sync.testEmitDomainChanged(SyncDomain.sessions);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(discovery.debugReconcileCount, 1);
        expect(discovery.debugTrackedSessions, contains('s1'));
        await discovery.detach();
      },
    );

    test('a sessions-domain burst walks the catalog at most twice and '
        'posts the notification once', () async {
      final sync = createTestSync();
      sync.testSessions['s1'] = _makeSession(id: 's1', thinking: true);
      final c = SessionActivityCoordinator(
        refreshInterval: const Duration(hours: 1),
        eventReconcileCooldown: const Duration(milliseconds: 80),
      )..attach(sync);

      for (var i = 0; i < 10; i++) {
        sync.testEmitDomainChanged(SyncDomain.sessions);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(c.debugReconcileCount, 2); // leading edge + trailing catch-up
      expect(c.debugNotificationPosts, 1); // unchanged show is not re-posted
      expect(c.debugTrackedSessions, ['s1']);
      await c.detach();
    });

    test('a tool change within the same turn re-posts the notification',
        () async {
      AgentState agentWith(String tool) => AgentState(
            requests: {
              'p1': RequestInfo(tool: tool, arguments: const {}),
            },
          );
      final sync = createTestSync();
      sync.testSessions['s1'] = _makeSession(
        id: 's1',
        thinking: true,
        agentState: agentWith('Bash'),
      );
      final c = SessionActivityCoordinator(
        refreshInterval: const Duration(hours: 1),
        eventReconcileCooldown: const Duration(milliseconds: 40),
      )..attach(sync);
      sync.testEmitDomainChanged(SyncDomain.sessions);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(c.debugNotificationPosts, 1);

      sync.testSessions['s1'] = _makeSession(
        id: 's1',
        thinking: true,
        agentState: agentWith('Edit'),
      );
      sync.testEmitDomainChanged(SyncDomain.sessions);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(c.debugNotificationPosts, 2);
      await c.detach();
    });

    test('deleting a tracked session ends its activity on the next wave',
        () async {
      final sync = createTestSync();
      sync.testSessions['s1'] = _makeSession(id: 's1', thinking: true);
      final c = SessionActivityCoordinator(
        refreshInterval: const Duration(hours: 1),
        eventReconcileCooldown: const Duration(milliseconds: 40),
      )..attach(sync);
      sync.testEmitDomainChanged(SyncDomain.sessions);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(c.debugTrackedSessions, contains('s1'));

      sync.testSessions.remove('s1');
      sync.testEmitDomainChanged(SyncDomain.sessions);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(c.debugTrackedSessions, isNot(contains('s1')));
      await c.detach();
    });
  });
}
