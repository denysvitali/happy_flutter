import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

/// E2E tests for message cache cold-start integration.
///
/// Exercises how the Sync singleton handles pre-populated messages from
/// the cache and reconciles them with server data, simulating
/// _restoreAllCachedMessages() via testSetSessionMessages.
void main() {
  // -------------------------------------------------------------------------
  // Group 1: cache restoration and display
  // -------------------------------------------------------------------------

  group('cache restoration and display', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      _stubAllSyncs(sync);
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'cached messages are available immediately after '
      'testSetSessionMessages',
      () {
        const sessionId = 'sess-cache-1';

        final cached = [
          _makePlainMessage('msg-1', seq: 1),
          _makePlainMessage('msg-2', seq: 2),
          _makePlainMessage('msg-3', seq: 3),
        ];
        sync.testSetSessionMessages(sessionId, cached);

        final result = sync.testSessionMessages(sessionId);
        expect(result, isNotNull);
        expect(
          result!.length,
          3,
          reason: 'All 3 cached messages should be accessible immediately',
        );
        final ids = result.map((m) => m['id'] as String).toSet();
        expect(ids, containsAll(['msg-1', 'msg-2', 'msg-3']));
      },
    );

    test(
      'cached messages with correct seq set cursor properly',
      () async {
        const sessionId = 'sess-cache-2';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 15,
        );

        // Simulate cache restoration: set messages and advance cursor.
        final cached = [
          _makePlainMessage('msg-1', seq: 1),
          _makePlainMessage('msg-15', seq: 15),
        ];
        sync.testSetSessionMessages(sessionId, cached);
        sync.testSetSessionLastSeq(sessionId, 15);

        // Server reports lastSeq=15 — cursor matches, no fetch needed.
        final fetchCalls = <int>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          fetchCalls.add(afterSeq);
          return _buildResponse([]);
        };

        await sync.fetchMessages(sessionId);

        expect(
          fetchCalls,
          isEmpty,
          reason: 'Cursor==server means no fetch should occur '
              '(already caught up)',
        );
      },
    );

    test(
      'empty cache results in first-load behavior',
      () async {
        const sessionId = 'sess-cache-3';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        // No cached messages — isFirstLoad will be true.

        final capturedAfterSeqs = <int>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          capturedAfterSeqs.add(afterSeq);
          return _buildResponse([
            _makeEncryptedMessage('msg-1', seq: 1, content: 'Hello'),
          ]);
        };

        await sync.fetchMessages(sessionId);

        expect(
          capturedAfterSeqs,
          isNotEmpty,
          reason: 'Empty cache should trigger a first-load fetch',
        );
        // With lastSeq=5 <= initialLoad(200), afterSeq should be 0.
        expect(
          capturedAfterSeqs.first,
          0,
          reason: 'First-load with short history uses afterSeq=0',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Group 2: server reconciliation with cache
  // -------------------------------------------------------------------------

  group('server reconciliation with cache', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      _stubAllSyncs(sync);
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'server delta merges with cached messages',
      () async {
        const sessionId = 'sess-delta-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 8,
        );

        // Pre-populate cache with 5 messages (seq 1-5).
        final cached = List.generate(
          5,
          (i) => _makePlainMessage('msg-${i + 1}', seq: i + 1),
        );
        sync.testSetSessionMessages(sessionId, cached);
        sync.testSetSessionLastSeq(sessionId, 5);

        // Server has messages 6-8 (delta).
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          expect(
            afterSeq,
            5,
            reason: 'Delta fetch should start at cursor seq=5',
          );
          return _buildResponse([
            _makeEncryptedMessage('msg-6', seq: 6, content: 'Six'),
            _makeEncryptedMessage('msg-7', seq: 7, content: 'Seven'),
            _makeEncryptedMessage('msg-8', seq: 8, content: 'Eight'),
          ]);
        };

        await sync.fetchMessages(sessionId);

        final result = sync.testSessionMessages(sessionId);
        expect(result, isNotNull);
        final ids = result!.map((m) => m['id'] as String).toSet();

        // All 8 messages should be present after the merge.
        for (var i = 1; i <= 8; i++) {
          expect(
            ids.contains('msg-$i'),
            isTrue,
            reason: 'msg-$i should be present after delta merge',
          );
        }
      },
    );

    test(
      'server returns newer version of cached message',
      () async {
        const sessionId = 'sess-update-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 1,
        );

        // Cache has msg-1 at seq=1.
        sync.testSetSessionMessages(sessionId, [
          _makePlainMessage('msg-1', seq: 1),
        ]);
        // Cursor behind server (so fetch runs).
        sync.testSetSessionLastSeq(sessionId, 0);

        // Server returns msg-1 at seq=1 with updated encrypted content.
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          return _buildResponse([
            _makeEncryptedMessage(
              'msg-1',
              seq: 1,
              content: 'UpdatedContent',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);

        final result = sync.testSessionMessages(sessionId);
        expect(result, isNotNull);
        // Exactly one message with id msg-1 should exist (upsert, not dup).
        final matching = result!
            .where((m) => m['id'] == 'msg-1')
            .toList();
        expect(
          matching.length,
          1,
          reason: 'Upsert should not duplicate msg-1',
        );
      },
    );

    test(
      'cache-only messages preserved when server has no new data',
      () async {
        const sessionId = 'sess-nochange-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );

        // Cache has 5 messages; cursor matches server — no new data.
        final cached = List.generate(
          5,
          (i) => _makePlainMessage('msg-${i + 1}', seq: i + 1),
        );
        sync.testSetSessionMessages(sessionId, cached);
        sync.testSetSessionLastSeq(sessionId, 5);

        // Override should NOT be called when cursor==server.
        var fetchCalled = false;
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          fetchCalled = true;
          return _buildResponse([]);
        };

        await sync.fetchMessages(sessionId);

        expect(fetchCalled, isFalse);

        // Original 5 cache messages should still be intact.
        final result = sync.testSessionMessages(sessionId);
        expect(result, isNotNull);
        expect(
          result!.length,
          5,
          reason: 'Cache messages should be preserved when server is current',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Group 3: stale cache handling
  // -------------------------------------------------------------------------

  group('stale cache handling', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      _stubAllSyncs(sync);
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'stale cache (cursor far behind server) triggers tail refresh',
      () async {
        const sessionId = 'sess-stale-1';
        // lastSeq=500, cursor=5 → gap=495 > initialLoad(200) → gapTooLarge.
        // Expected afterSeq = 500 - 200 = 300.
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 500,
        );
        // Cache has old messages (seq 1-5), cursor at 5.
        final staleCache = List.generate(
          5,
          (i) => _makePlainMessage('msg-${i + 1}', seq: i + 1),
        );
        sync.testSetSessionMessages(sessionId, staleCache);
        sync.testSetSessionLastSeq(sessionId, 5);

        final capturedAfterSeqs = <int>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          capturedAfterSeqs.add(afterSeq);
          return _buildResponse([
            _makeEncryptedMessage('msg-301', seq: 301, content: 'New'),
          ]);
        };

        await sync.fetchMessages(sessionId);

        expect(capturedAfterSeqs, isNotEmpty);
        expect(
          capturedAfterSeqs.first,
          300,
          reason: 'Tail refresh should start at '
              'lastSeq(500) - initialLoad(200) = 300',
        );
      },
    );

    test(
      'stale cache messages are replaced by tail refresh',
      () async {
        const sessionId = 'sess-stale-2';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 500,
        );
        // Old cache: seq 1-5, cursor at 5.
        final staleCache = List.generate(
          5,
          (i) => _makePlainMessage('old-msg-${i + 1}', seq: i + 1),
        );
        sync.testSetSessionMessages(sessionId, staleCache);
        sync.testSetSessionLastSeq(sessionId, 5);

        // Server returns only tail messages (seq 301+).
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          return _buildResponse([
            _makeEncryptedMessage('new-msg-301', seq: 301, content: 'A'),
            _makeEncryptedMessage('new-msg-302', seq: 302, content: 'B'),
          ]);
        };

        await sync.fetchMessages(sessionId);

        final result = sync.testSessionMessages(sessionId);
        expect(result, isNotNull);

        // New tail messages should be present.
        final ids = result!.map((m) => m['id'] as String).toSet();
        expect(
          ids.contains('new-msg-301'),
          isTrue,
          reason: 'Tail-refresh message new-msg-301 should be present',
        );
        expect(
          ids.contains('new-msg-302'),
          isTrue,
          reason: 'Tail-refresh message new-msg-302 should be present',
        );

        // Stale messages should have been cleared by the gap recovery.
        expect(
          ids.contains('old-msg-1'),
          isFalse,
          reason: 'Stale cache message old-msg-1 should be replaced',
        );
      },
    );

    test(
      'cache with no cursor (first load) fetches full window',
      () async {
        const sessionId = 'sess-nocursor-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 50,
        );
        // Cache has messages but cursor is NOT set (simulates restored
        // cache where seq was not persisted — treated as first load).
        final cached = List.generate(
          3,
          (i) => _makePlainMessage('cache-msg-${i + 1}', seq: i + 1),
        );
        sync.testSetSessionMessages(sessionId, cached);
        // Do NOT call testSetSessionLastSeq — cursor stays at 0.

        final capturedAfterSeqs = <int>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          capturedAfterSeqs.add(afterSeq);
          return _buildResponse([
            _makeEncryptedMessage('msg-1', seq: 1, content: 'Msg1'),
          ]);
        };

        await sync.fetchMessages(sessionId);

        // With cursor=0 and messages in memory (isFirstLoad=false),
        // the code falls into the `cursorSeq == 0` branch which uses
        // _tailAfterSeqForSession (server hint-based tail).
        // lastSeq=50 <= initialLoad(200) → afterSeq=0.
        expect(capturedAfterSeqs, isNotEmpty);
        expect(
          capturedAfterSeqs.first,
          0,
          reason: 'No cursor with short history should start at afterSeq=0',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Group 4: multiple sessions cache interaction
  // -------------------------------------------------------------------------

  group('multiple sessions cache interaction', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      _stubAllSyncs(sync);
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'cache for multiple sessions is independent',
      () {
        const sessA = 'sess-multi-a';
        const sessB = 'sess-multi-b';

        // Pre-populate different message sets for each session.
        sync.testSetSessionMessages(sessA, [
          _makePlainMessage('a-msg-1', seq: 1),
          _makePlainMessage('a-msg-2', seq: 2),
        ]);
        sync.testSetSessionMessages(sessB, [
          _makePlainMessage('b-msg-1', seq: 10),
          _makePlainMessage('b-msg-2', seq: 20),
          _makePlainMessage('b-msg-3', seq: 30),
        ]);

        final msgsA = sync.testSessionMessages(sessA);
        final msgsB = sync.testSessionMessages(sessB);

        expect(msgsA, isNotNull);
        expect(msgsA!.length, 2, reason: 'sess-A should have 2 messages');
        expect(msgsB, isNotNull);
        expect(msgsB!.length, 3, reason: 'sess-B should have 3 messages');

        // Verify no cross-contamination of IDs.
        final idsA = msgsA.map((m) => m['id'] as String).toSet();
        final idsB = msgsB.map((m) => m['id'] as String).toSet();
        expect(idsA.intersection(idsB), isEmpty,
          reason: 'Sessions A and B should have disjoint message sets');
      },
    );

    test(
      'fetching one session preserves other session cache',
      () async {
        const sessA = 'sess-preserve-a';
        const sessB = 'sess-preserve-b';

        sync.testSessions[sessA] = _makeSession(sessA, lastSeq: 8);
        sync.testSessions[sessB] = _makeSession(sessB, lastSeq: 3);

        // Pre-populate both sessions in cache.
        sync.testSetSessionMessages(sessA, [
          _makePlainMessage('a-msg-1', seq: 1),
          _makePlainMessage('a-msg-2', seq: 2),
        ]);
        sync.testSetSessionLastSeq(sessA, 2);

        sync.testSetSessionMessages(sessB, [
          _makePlainMessage('b-msg-1', seq: 1),
          _makePlainMessage('b-msg-2', seq: 2),
          _makePlainMessage('b-msg-3', seq: 3),
        ]);
        sync.testSetSessionLastSeq(sessB, 3);

        // Fetch for sess-A: server has messages 3-8.
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          expect(sid, sessA, reason: 'Only sess-A fetch should be called');
          return _buildResponse([
            _makeEncryptedMessage('a-msg-3', seq: 3, content: 'Three'),
            _makeEncryptedMessage('a-msg-8', seq: 8, content: 'Eight'),
          ]);
        };

        await sync.fetchMessages(sessA);

        // sess-A should have merged messages (original + new from server).
        final msgsA = sync.testSessionMessages(sessA);
        expect(msgsA, isNotNull);
        final idsA = msgsA!.map((m) => m['id'] as String).toSet();
        expect(idsA.contains('a-msg-3'), isTrue);

        // sess-B cache should be completely untouched.
        final msgsB = sync.testSessionMessages(sessB);
        expect(msgsB, isNotNull);
        expect(
          msgsB!.length,
          3,
          reason: 'sess-B cache must not be affected by sess-A fetch',
        );
        final idsB = msgsB.map((m) => m['id'] as String).toSet();
        expect(
          idsB,
          containsAll(['b-msg-1', 'b-msg-2', 'b-msg-3']),
          reason: 'All original sess-B messages must remain intact',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test infrastructure helpers
// ---------------------------------------------------------------------------

void _stubAllSyncs(Sync sync) {
  sync.sessionsSync = InvalidateSync(() async {});
  sync.settingsSync = InvalidateSync(() async {});
  sync.profileSync = InvalidateSync(() async {});
  sync.purchasesSync = InvalidateSync(() async {});
  sync.machinesSync = InvalidateSync(() async {});
  sync.pushTokenSync = InvalidateSync(() async {});
  sync.nativeUpdateSync = InvalidateSync(() async {});
  sync.artifactsSync = InvalidateSync(() async {});
  sync.friendsSync = InvalidateSync(() async {});
  sync.friendRequestsSync = InvalidateSync(() async {});
  sync.feedSync = InvalidateSync(() async {});
  sync.todosSync = InvalidateSync(() async {});
  sync.sessionGitStatusSync = InvalidateSync(() async {});
  sync.messagesSync.clear();
}

Session _makeSession(String id, {int lastSeq = 10}) {
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

/// Creates a plain (non-encrypted) message map suitable for inserting
/// directly via testSetSessionMessages to simulate a cache restore.
Map<String, dynamic> _makePlainMessage(String id, {required int seq}) {
  return {
    'id': id,
    'seq': seq,
    'role': 'agent',
    'kind': 'text',
    'content': 'Cached content for $id',
    'createdAt': 1700000000000 + seq * 1000,
  };
}

/// Creates a fake-encrypted agent message in the format expected
/// by Sync.
///
/// Uses [0x01] + utf8(JSON) format matching [_FakeEncryptor].
/// The inner envelope must use `type: 'assistant'` and supply
/// `message` as a bare string so that
/// [_processOutputContent] recognises the legacy format.
Map<String, dynamic> _makeEncryptedMessage(
  String id, {
  required int seq,
  required String content,
}) {
  final innerContent = {
    'role': 'agent',
    'content': {
      'type': 'output',
      'data': {
        'type': 'assistant',
        'message': content,
      },
    },
  };
  final json = jsonEncode(innerContent);
  final bytes = utf8.encode(json);
  final output = Uint8List(bytes.length + 1);
  output[0] = 0x01;
  output.setRange(1, output.length, bytes);
  return {
    'id': id,
    'seq': seq,
    'role': 'agent',
    'content': {'t': 'encrypted', 'c': base64Encode(output)},
    'createdAt': 1700000000000 + seq * 1000,
  };
}

Map<String, dynamic> _buildResponse(
  List<Map<String, dynamic>> messages, {
  bool hasMore = false,
}) {
  return {'messages': messages, 'hasMore': hasMore};
}

// ---------------------------------------------------------------------------
// Fake encryption classes (private)
// ---------------------------------------------------------------------------

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _FakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeSessionEncryption extends SessionEncryption {
  _FakeSessionEncryption({required String sessionId})
      : super(
          sessionId: sessionId,
          encryptor: _FakeEncryptor(),
          decryptor: _FakeEncryptor(),
          cache: EncryptionCache(),
        );
}

class _FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data.map((item) {
      final json = jsonEncode(item);
      final bytes = utf8.encode(json);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      return output;
    }).toList();
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    return data.map((item) {
      if (item.isEmpty) return null;
      try {
        return item[0] == 0x01
            ? jsonDecode(utf8.decode(item.sublist(1)))
            : utf8.decode(item);
      } catch (_) {
        return null;
      }
    }).toList();
  }
}
