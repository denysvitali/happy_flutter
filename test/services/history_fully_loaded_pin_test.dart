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
    sync.testClearHistoryTrimmed(sessionId);
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

  test('a session whose window is at the trim cap is not pinned', () async {
    // A large session: every page fetched by "load older" is sorted and
    // trimmed back to the newest-N cap, so the rows never actually land in
    // memory. Pinning here permanently kills "load older" for the session
    // even though nothing older is loaded.
    final cap = Sync.maxVisibleSessionMessagesForTesting;
    sync.testSetSessionMessages(sessionId, [
      for (var i = 0; i < cap; i++) _msg('m-${4000 + i}', 4000 + i),
    ]);
    sync.testSetSessionFirstLoadedSeq(sessionId, 50);

    await sync.fetchOlderMessages(sessionId, pageSize: 100);

    expect(
      sync.testHistoryFullyLoaded(sessionId),
      isFalse,
      reason:
          'a full window means the fetched page was trimmed away — the '
          'session has NOT loaded all its history',
    );
  });

  test(
    'a BACKGROUND session at the background trim cap is not pinned',
    () async {
      // Background sessions trim to _maxBackgroundSessionMessages (200), not
      // the visible cap (1000). Comparing the window against the visible
      // constant declared a 200-message background session "below cap", so
      // reaching seq 0 pinned it as fully loaded even though the fetched page
      // was trimmed straight back off again — permanently killing "load
      // older" once the user opened the session.
      sync.testSetVisibleSessionId('some-other-session');
      final cap = Sync.maxBackgroundSessionMessagesForTesting;
      sync.testSetSessionMessages(sessionId, [
        for (var i = 0; i < cap; i++) _msg('m-${4000 + i}', 4000 + i),
      ]);
      sync.testSetSessionFirstLoadedSeq(sessionId, 50);

      await sync.fetchOlderMessages(sessionId, pageSize: 100);

      expect(
        sync.testHistoryFullyLoaded(sessionId),
        isFalse,
        reason:
            'a background session at ITS cap has its fetched pages trimmed '
            'away, so it has NOT loaded all its history',
      );
    },
  );

  test('a walk-back trimmed along the way is NOT pinned at seq 0 — boundary '
      'stays at the resident minimum and the orphan sweep gives up', () async {
    // Production shape, 2026-08-03 (session c01b840f…): a 13k-seq session
    // whose orphan walk-back paged through the whole history while the
    // newest-N trim discarded pages as fast as they arrived. Reaching
    // startSeq 0 with a below-cap window at that instant wrote
    // firstLoadedSeq = 0 and pinned "history fully loaded": the chat then
    // rendered "Beginning of conversation" over the newest ~200 rows and
    // scroll-back died (the firstLoaded <= 1 guard in fetchOlderMessages).
    final cap = Sync.maxVisibleSessionMessagesForTesting;
    sync.testSetSessionMessages(sessionId, [
      for (var i = 0; i < cap; i++) _msg('m-${4000 + i}', 4000 + i),
    ]);
    // Push one tail row through the real upsert so the trim actually
    // discards a row — the "history was trimmed" ledger entry.
    sync.testUpsertSessionMessages(sessionId, [_msg('m-5000', 5000)]);
    expect(sync.testHistoryTrimmed(sessionId), isTrue);

    // Simulate a later background trim cutting the window to the newest
    // 200 rows, so the final page arrives with the window BELOW the
    // visible cap — the case the at-cap guard alone cannot catch.
    sync.testSetSessionMessages(sessionId, [
      for (var i = 0; i < 200; i++) _msg('m-${4801 + i}', 4801 + i),
    ]);
    sync.testSetSessionFirstLoadedSeq(sessionId, 50);

    await sync.fetchOlderMessages(sessionId, pageSize: 100);

    expect(
      sync.testHistoryFullyLoaded(sessionId),
      isFalse,
      reason: 'a trimmed walk-back must never claim history-complete',
    );
    expect(
      sync.testSessionFirstLoadedSeq(sessionId),
      4801,
      reason:
          'the boundary must be the oldest resident seq — writing 0 '
          '(or startSeq + 1 = 1) over a trimmed window is the lie that '
          'hollowed out the transcript',
    );
    expect(
      sync.hasOlderMessages(sessionId),
      isTrue,
      reason:
          'older messages still exist on the server — scroll-back '
          'must stay alive',
    );
    expect(
      sync.testOrphanFetchOlderNoProgressCount(sessionId),
      sync.testOrphanFetchOlderMaxAttempts,
      reason:
          'an unwinnable walk-back (orphan parents can never become '
          'resident) must exhaust the sweep budget so orphans render '
          'inline instead of re-walking history on every regroup',
    );
  });

  test('an untrimmed walk-back to seq 0 still pins, even when earlier seqs '
      'never produced resident rows', () async {
    // Control for the ledger: parser-dropped rows (usage/ready events
    // occupy seqs but never land in the window) must not read as
    // "trimmed". Below cap, no real trim — reaching seq 0 pins.
    sync.testSetSessionMessages(sessionId, [
      _msg('m-100', 100),
      _msg('m-101', 101),
    ]);
    sync.testSetSessionFirstLoadedSeq(sessionId, 50);

    await sync.fetchOlderMessages(sessionId, pageSize: 100);

    expect(sync.testHistoryTrimmed(sessionId), isFalse);
    expect(sync.testHistoryFullyLoaded(sessionId), isTrue);
    expect(sync.hasOlderMessages(sessionId), isFalse);
  });

  test('a mid-walk empty page still advances the coverage boundary', () async {
    // The orphan walk-back's progress is measured by the boundary moving
    // down; an empty page means "this range was checked", not "nothing
    // older exists". Only the startSeq == 0 write switches to the
    // residency semantics — mid-walk pages must keep coverage semantics
    // or a stretch of parser-dropped rows becomes a refetch wall.
    final cap = Sync.maxVisibleSessionMessagesForTesting;
    sync.testSetSessionMessages(sessionId, [
      for (var i = 0; i < cap; i++) _msg('m-${4000 + i}', 4000 + i),
    ]);
    sync.testSetSessionFirstLoadedSeq(sessionId, 4000);

    await sync.fetchOlderMessages(sessionId, pageSize: 100);

    expect(
      sync.testSessionFirstLoadedSeq(sessionId),
      3900,
      reason:
          'startSeq = 4000 - 1 - 100 = 3899, so the coverage '
          'boundary advances to 3900 even though the page was empty',
    );
    expect(sync.testHistoryFullyLoaded(sessionId), isFalse);
  });

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
