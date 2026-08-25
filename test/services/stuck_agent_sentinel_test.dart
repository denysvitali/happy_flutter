import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/stuck_agent_sentinel.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import '../helpers/test_helpers.dart';

Session _session({
  required String id,
  bool thinking = true,
  bool permission = false,
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 10,
    active: true,
    activeAt: 10,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: 'online',
    agentState: permission
        ? AgentState(
            requests: {
              'permission': RequestInfo(tool: 'Bash', arguments: const {}),
            },
          )
        : null,
  );
}

void main() {
  test(
    'raises once after threshold and rearms after message progress',
    () async {
      var now = DateTime(2026, 1, 1, 12);
      final shown = <StuckAlert>[];
      final cancelled = <String>[];
      final sentinel = StuckAgentSentinel(
        stallThreshold: const Duration(minutes: 10),
        now: () => now,
        visibleSessionResolver: () => null,
        showAlert: (alert) async => shown.add(alert),
        cancelAlert: (sessionId) async => cancelled.add(sessionId),
      );

      sentinel.reconcile([_session(id: 's1')]);
      now = now.add(const Duration(minutes: 11));
      sentinel.reconcile([_session(id: 's1')]);
      await Future<void>.delayed(Duration.zero);
      expect(shown, hasLength(1));

      sentinel.reconcile([_session(id: 's1')]);
      await Future<void>.delayed(Duration.zero);
      expect(shown, hasLength(1));

      sentinel.recordProgress('s1');
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, ['s1']);

      now = now.add(const Duration(minutes: 11));
      sentinel.reconcile([_session(id: 's1')]);
      await Future<void>.delayed(Duration.zero);
      expect(shown, hasLength(2));
      await sentinel.detach();
    },
  );

  test('suppresses visible and permission-blocked sessions', () async {
    var now = DateTime(2026, 1, 1, 12);
    final shown = <StuckAlert>[];
    final sentinel = StuckAgentSentinel(
      stallThreshold: const Duration(minutes: 10),
      now: () => now,
      visibleSessionResolver: () => 'visible',
      showAlert: (alert) async => shown.add(alert),
      cancelAlert: (_) async {},
    );

    sentinel.reconcile([
      _session(id: 'visible'),
      _session(id: 'permission', permission: true),
    ]);
    now = now.add(const Duration(minutes: 11));
    sentinel.reconcile([
      _session(id: 'visible'),
      _session(id: 'permission', permission: true),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(shown, isEmpty);
    await sentinel.detach();
  });

  // Freeze audit 2026-08-25: update-session socket events bump
  // SyncDomain.sessions per token batch during streaming, and this listener
  // used to walk and fingerprint the whole catalog on every wave. Pin the
  // leading+trailing coalescing that caps the walk at one per cooldown.
  test('coalesces a sessions-domain burst into two catalog walks', () async {
    final sync = createTestSync();
    sync.testSessions['s1'] = _session(id: 's1');
    final shown = <StuckAlert>[];
    final cancelled = <String>[];
    final sentinel = StuckAgentSentinel(
      stallThreshold: Duration.zero,
      eventReconcileCooldown: const Duration(milliseconds: 80),
      checkInterval: const Duration(hours: 1),
      visibleSessionResolver: () => null,
      showAlert: (alert) async => shown.add(alert),
      cancelAlert: (sessionId) async => cancelled.add(sessionId),
    )..attach(sync);

    for (var i = 0; i < 10; i++) {
      sync.testEmitDomainChanged(SyncDomain.sessions);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(sentinel.debugReconcileCount, 2); // leading + trailing
    expect(shown, hasLength(1)); // one-shot alert, not one per wave
    expect(cancelled, isEmpty);
    await sentinel.detach();
  });
}
