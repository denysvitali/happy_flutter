import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';

Session _session({required bool active, required String presence}) {
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
    presence: presence,
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
  });
}
