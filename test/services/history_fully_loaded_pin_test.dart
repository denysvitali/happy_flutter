import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Regression: the history boundary must not re-arm itself from tail traffic.
///
/// `_sessionFirstLoadedSeq` had two writers with different meanings:
/// `fetchOlderMessages` writes 0 when it reaches the beginning of history,
/// `_ensureFirstLoadedSeq` re-arms it from the in-memory minimum whenever it
/// is 0 or null. Once the newest-N trim dropped the oldest rows, the minimum
/// rose, the boundary was rewritten to a non-zero seq, `hasOlderMessages`
/// flipped back to true and the client re-downloaded history it already had —
/// driven purely by new messages arriving at the tail.
void main() {
  const sessionId = 'pin-s1';
  late Sync sync;

  setUp(() {
    sync = createTestSync();
    sync.encryption = _PinFakeEncryption();
    sync.testIsInitialized = true;
    sync.testSetVisibleSessionId(sessionId);
    sync.testSessions[sessionId] = _makePinSession(sessionId, lastSeq: 5000);
    sync.testFetchOlderMessagesOverride = (id, afterSeq, limit) async {
      return {'messages': <Map<String, dynamic>>[], 'hasMore': false};
    };
  });

  tearDown(() {
    sync.testFetchOlderMessagesOverride = null;
    sync.testClearHistoryFullyLoaded(sessionId);
    sync.testClearSessionMessageState(sessionId);
    sync.testSetVisibleSessionId(null);
  });

  test(
    'walking back to seq 0 pins the boundary against tail-driven re-arming',
    () async {
      // Seed a window whose oldest row is seq 100 and put the boundary just
      // above it so the next page reaches seq 0.
      sync.testSetSessionMessages(sessionId, [
        _msg('m-100', 100),
        _msg('m-101', 101),
      ]);
      sync.testSetSessionFirstLoadedSeq(sessionId, 50);
      expect(sync.hasOlderMessages(sessionId), isTrue);

      await sync.fetchOlderMessages(sessionId, pageSize: 100);

      expect(
        sync.testHistoryFullyLoaded(sessionId),
        isTrue,
        reason: 'reaching startSeq 0 must pin the session',
      );
      expect(sync.hasOlderMessages(sessionId), isFalse);

      // A new tail message arrives and the trim drops the oldest rows, so the
      // in-memory minimum rises from 100 to 900. Previously this re-armed the
      // boundary to 900 and hasOlderMessages went back to true.
      sync.testUpsertSessionMessages(sessionId, [
        _msg('m-900', 900),
        _msg('m-901', 901),
      ]);
      sync.testSetSessionMessages(sessionId, [_msg('m-900', 900)]);
      sync.testUpsertSessionMessages(sessionId, [_msg('m-902', 902)]);

      expect(
        sync.hasOlderMessages(sessionId),
        isFalse,
        reason:
            'tail traffic must not resurrect the older-history boundary for '
            'a session already paginated to seq 0',
      );
    },
  );

  test('an unpinned session still re-arms its boundary after a trim', () async {
    // Control case: a session that never reached seq 0 keeps the existing
    // self-healing behaviour so the user can scroll back.
    sync.testSetSessionFirstLoadedSeq(sessionId, 0);
    sync.testSetSessionMessages(sessionId, []);
    sync.testUpsertSessionMessages(sessionId, [_msg('m-900', 900)]);

    expect(sync.testHistoryFullyLoaded(sessionId), isFalse);
    expect(sync.hasOlderMessages(sessionId), isTrue);
  });
}

Map<String, dynamic> _msg(String id, int seq) => <String, dynamic>{
  'id': id,
  'seq': seq,
  'createdAt': 1700000000000 + seq,
  'role': 'agent',
  'kind': 'text',
  'content': 'body-$id',
};

Session _makePinSession(String id, {required int lastSeq}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    active: true,
    activeAt: 1700000000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'offline',
    lastSeq: lastSeq,
  );
}

class _PinFakeEncryption implements Encryption {
  final Map<String, _PinFakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _PinFakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PinFakeSessionEncryption extends SessionEncryption {
  _PinFakeSessionEncryption({required String sessionId})
    : super(
        sessionId: sessionId,
        encryptor: _PinFakeEncryptor(),
        decryptor: _PinFakeEncryptor(),
        cache: EncryptionCache(),
      );
}

class _PinFakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async =>
      data.map((_) => Uint8List(0)).toList();

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async =>
      data.map((_) => null).toList();
}
