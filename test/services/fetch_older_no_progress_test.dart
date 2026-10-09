import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Regression: a history page that cannot move the boundary must not be
/// downloaded twice in a row.
///
/// Production shape, 2026-10-08 power diagnostics: one 500-row
/// `after_seq=0` page for the same session completed twice 670ms apart. The
/// orphan walk-back and the top-scroll trigger both reached
/// `fetchOlderMessages` while the first page's rows had been trimmed away,
/// so the boundary stayed put and the identical request was issued again.
void main() {
  const sessionId = 'noprog-s1';
  late Sync sync;
  late List<int> requestedAfterSeq;

  setUp(() {
    sync = createTestSync();
    sync.encryption = _FakeEncryption();
    sync.testIsInitialized = true;
    sync.testSetVisibleSessionId(sessionId);
    sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 5000);
    requestedAfterSeq = <int>[];
    sync.testFetchOlderMessagesOverride = (id, afterSeq, limit) async {
      requestedAfterSeq.add(afterSeq);
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
    'a repeat of a page that left the boundary unchanged is skipped',
    () async {
      // Mark the history as trimmed through the real upsert, then leave a
      // small window whose oldest resident row is the current boundary.
      final cap = Sync.maxVisibleSessionMessagesForTesting;
      sync.testSetSessionMessages(sessionId, [
        for (var i = 0; i < cap; i++) _msg('m-${4000 + i}', 4000 + i),
      ]);
      sync.testUpsertSessionMessages(sessionId, [_msg('m-5000', 5000)]);
      sync.testSetSessionMessages(sessionId, [
        for (var i = 0; i < 200; i++) _msg('m-${301 + i}', 301 + i),
      ]);
      sync.testSetSessionFirstLoadedSeq(sessionId, 301);

      await sync.fetchOlderMessages(sessionId, pageSize: 500);
      await sync.fetchOlderMessages(sessionId, pageSize: 500);

      expect(requestedAfterSeq, [
        0,
      ], reason: 'the identical page was refetched');
      expect(sync.testSessionFirstLoadedSeq(sessionId), 301);
    },
  );

  test('pages that move the boundary are never suppressed', () async {
    sync.testSetSessionMessages(sessionId, [
      for (var i = 0; i < 200; i++) _msg('m-${4000 + i}', 4000 + i),
    ]);
    sync.testSetSessionFirstLoadedSeq(sessionId, 4000);

    await sync.fetchOlderMessages(sessionId, pageSize: 100);
    await sync.fetchOlderMessages(sessionId, pageSize: 100);

    expect(requestedAfterSeq, [3899, 3799]);
    expect(sync.testSessionFirstLoadedSeq(sessionId), 3800);
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

Session _makeSession(String id, {required int lastSeq}) {
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

class _FakeEncryption implements Encryption {
  final Map<String, SessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => SessionEncryption(
        sessionId: sessionId,
        encryptor: _FakeEncryptor(),
        decryptor: _FakeEncryptor(),
        cache: EncryptionCache(),
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async =>
      data.map((_) => Uint8List(0)).toList();

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async =>
      data.map((_) => null).toList();
}
