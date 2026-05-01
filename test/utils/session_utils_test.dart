import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';

Session _session({
  required bool active,
  required String presence,
  bool archived = false,
  String? lifecycleState,
  int? lifecycleStateSince,
}) {
  return Session(
    id: 's1',
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: active,
    activeAt: 1,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    archived: archived,
    presence: presence,
    metadata: lifecycleState == null && lifecycleStateSince == null
        ? null
        : Metadata(
            lifecycleState: lifecycleState,
            lifecycleStateSince: lifecycleStateSince,
          ),
  );
}

void main() {
  group('isSessionActive', () {
    test('returns true for online presence', () {
      final session = _session(active: false, presence: 'online');
      expect(isSessionActive(session), isTrue);
    });

    test('returns true for persisted active sessions even if offline', () {
      final session = _session(active: true, presence: 'offline');
      expect(isSessionActive(session), isTrue);
    });

    test('returns false only when offline and inactive', () {
      final session = _session(active: false, presence: 'offline');
      expect(isSessionActive(session), isFalse);
    });

    test('returns true when archived but agent lifecycle is running and '
        'recent (e.g. respawn after a clean-exit archive)', () {
      final session = _session(
        active: false,
        presence: 'offline',
        archived: true,
        lifecycleState: 'running',
        lifecycleStateSince: DateTime.now().millisecondsSinceEpoch - 5000,
      );
      expect(isSessionActive(session), isTrue);
    });

    test('returns true when archived but agent is starting recently', () {
      final session = _session(
        active: false,
        presence: 'offline',
        archived: true,
        lifecycleState: 'starting',
        lifecycleStateSince: DateTime.now().millisecondsSinceEpoch - 1000,
      );
      expect(isSessionActive(session), isTrue);
    });

    test('returns false when archived and lifecycle running is stale', () {
      final session = _session(
        active: false,
        presence: 'offline',
        archived: true,
        lifecycleState: 'running',
        lifecycleStateSince:
            DateTime.now().millisecondsSinceEpoch - 5 * 60 * 1000,
      );
      expect(isSessionActive(session), isFalse);
    });

    test('returns false when archived with no lifecycle metadata', () {
      final session = _session(
        active: true,
        presence: 'online',
        archived: true,
      );
      expect(isSessionActive(session), isFalse);
    });
  });
}
