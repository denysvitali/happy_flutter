import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/stuck_agent_sentinel.dart';

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
}
