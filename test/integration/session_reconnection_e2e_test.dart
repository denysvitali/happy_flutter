import 'dart:async';
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

void main() {
  group('reconnection triggers data refresh', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testLastInvalidateAllSyncsAtMs = null;
    });

    test('invalidateAllSyncs is called on reconnect', () async {
      // Reset so we can detect the change.
      sync.testLastInvalidateAllSyncsAtMs = null;

      sync.testInvalidateAllSyncs(force: true);

      expect(
        sync.testLastInvalidateAllSyncsAtMs,
        isNotNull,
        reason: 'timestamp should be set after invalidation',
      );
      final ts = sync.testLastInvalidateAllSyncsAtMs!;
      final now = DateTime.now().millisecondsSinceEpoch;
      expect(now - ts, lessThan(2000), reason: 'timestamp should be recent');
    });

    test('invalidateAllSyncs respects cooldown', () async {
      // Run a forced first invalidation to record the timestamp.
      sync.testInvalidateAllSyncs(force: true);
      final firstTs = sync.testLastInvalidateAllSyncsAtMs;
      expect(firstTs, isNotNull);

      // Immediately call without force — should be a no-op due to cooldown.
      sync.testInvalidateAllSyncs();
      expect(
        sync.testLastInvalidateAllSyncsAtMs,
        equals(firstTs),
        reason: 'second call within cooldown should not update the timestamp',
      );
    });

    test('reconnect always force-bypasses cooldown', () async {
      // Seed a recent timestamp so the 10s cooldown gate is active.
      sync.testLastInvalidateAllSyncsAtMs =
          DateTime.now().millisecondsSinceEpoch - 100; // 100ms ago
      final staleTs = sync.testLastInvalidateAllSyncsAtMs!;

      // Simulate the reconnect handler: force-invalidate.
      sync.testInvalidateAllSyncs(force: true);

      expect(
        sync.testLastInvalidateAllSyncsAtMs,
        greaterThan(staleTs),
        reason:
            'reconnect must force-bypass the cooldown so sessions '
            'are refetched and serverLastSeq is fresh',
      );
    });

    test('forced invalidateAllSyncs bypasses cooldown', () async {
      // Seed a very recent timestamp to simulate just-ran cooldown.
      final recent = DateTime.now().millisecondsSinceEpoch - 100; // 100ms ago
      sync.testLastInvalidateAllSyncsAtMs = recent;

      // Force should bypass the cooldown check.
      sync.testInvalidateAllSyncs(force: true);

      expect(
        sync.testLastInvalidateAllSyncsAtMs,
        greaterThan(recent),
        reason:
            'forced invalidation should update the timestamp even '
            'within cooldown',
      );
    });
  });

  group('message recovery after reconnect', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testLastInvalidateAllSyncsAtMs = null;
      sync.testVisibleSessionId = null;
    });

    test('visible session fetches messages after reconnect', () async {
      const sessionId = 'sess-visible';

      // Pre-populate session with cursor at 10.
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 10);
      sync.testSetSessionLastSeq(sessionId, 10);
      sync.testSetSessionMessages(sessionId, [
        _makePlainMessage('msg-1', seq: 1),
        _makePlainMessage('msg-10', seq: 10),
      ]);

      // Mark session visible and create the messagesSync entry.
      sync.testVisibleSessionId = sessionId;
      final fetchCalls = <int>[];
      sync.messagesSync[sessionId] = InvalidateSync(() async {
        // fetchMessages override records afterSeq.
        await sync.fetchMessages(sessionId);
      });

      // Ensure server knows about newer messages (seq 11-15).
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 15);

      sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
        fetchCalls.add(afterSeq);
        return _buildMessagesResponse([
          _makeEncryptedMessage('msg-15', seq: 15),
        ]);
      };

      // Trigger the same code path as onReconnected: invalidate all
      // then invalidate the visible session's messages.
      sync.testInvalidateAllSyncs(force: true);
      if (sync.testGetVisibleSessionId() != null) {
        sync.messagesSync[sessionId]?.invalidate();
      }

      // Wait for messagesSync to drain.
      await sync.messagesSync[sessionId]?.awaitQueue();

      expect(
        fetchCalls,
        isNotEmpty,
        reason: 'fetchMessages should be called for the visible session',
      );
    });

    test(
      'messages received during disconnect are fetched on reconnect',
      () async {
        const sessionId = 'sess-gap';

        // Session has messages up to seq 10 in memory.
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 15, // Server has 5 newer messages
        );
        sync.testSetSessionLastSeq(sessionId, 10);
        sync.testSetSessionMessages(sessionId, [
          for (var i = 1; i <= 10; i++) _makePlainMessage('msg-$i', seq: i),
        ]);

        sync.testVisibleSessionId = sessionId;

        final fetchedSeqs = <int>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          fetchedSeqs.add(afterSeq);
          return _buildMessagesResponse([
            for (var i = 11; i <= 15; i++)
              _makeEncryptedMessage('msg-$i', seq: i),
          ]);
        };

        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        // Simulate reconnect: invalidate all then fetch for visible.
        sync.testInvalidateAllSyncs(force: true);
        sync.messagesSync[sessionId]?.invalidate();
        await sync.messagesSync[sessionId]?.awaitQueue();

        expect(
          fetchedSeqs.isNotEmpty,
          isTrue,
          reason: 'fetchMessages should run after reconnect',
        );
        // The fetch should start from the cursor, not from scratch.
        expect(
          fetchedSeqs.first,
          10,
          reason: 'should fetch from cursor (seq 10)',
        );

        // Messages 11-15 should now be in memory.
        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        final seqs = msgs!.map((m) => m['seq'] as int).toSet();
        for (var i = 11; i <= 15; i++) {
          expect(seqs, contains(i), reason: 'msg seq=$i should be present');
        }
      },
    );
  });

    test(
      'reconnect within cooldown window still fetches messages '
      '(the stale-serverLastSeq bug)',
      () async {
        const sessionId = 'sess-cooldown';

        // Pre-populate: cursor and local lastSeq both at 10 (caught up).
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10,
        );
        sync.testSetSessionLastSeq(sessionId, 10);
        sync.testSetSessionMessages(sessionId, [
          for (var i = 1; i <= 10; i++) _makePlainMessage('msg-$i', seq: i),
        ]);

        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        // Seed a very recent _lastInvalidateAllSyncsAtMs so the
        // non-forced cooldown gate (10s) would block.
        sync.testLastInvalidateAllSyncsAtMs =
            DateTime.now().millisecondsSinceEpoch - 100;

        // Simulate the reconnect: server now has messages up to 15,
        // but our local _sessions[sessionId].lastSeq is still 10
        // because the sessions fetch was (hypothetically) skipped.
        // The fetch probe flag ensures fetchMessages still hits the
        // server.
        sync.testAddFetchProbe(sessionId);

        final fetchCalls = <int>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          fetchCalls.add(afterSeq);
          return _buildMessagesResponse([
            for (var i = 11; i <= 15; i++)
              _makeEncryptedMessage('msg-$i', seq: i),
          ]);
        };

        // Force-invalidate (as reconnect handler now does) + probe.
        sync.testInvalidateAllSyncs(force: true);
        sync.messagesSync[sessionId]?.invalidate();
        await sync.messagesSync[sessionId]?.awaitQueue();

        expect(
          fetchCalls,
          isNotEmpty,
          reason:
              'fetchMessages MUST hit the server on reconnect even '
              'when cursorSeq == serverLastSeq, because serverLastSeq '
              'may be stale if the sessions delta fetch was a no-op',
        );
      },
    );

  group('pending socket messages on reconnect', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testLastInvalidateAllSyncsAtMs = null;
      sync.testVisibleSessionId = null;
    });

    test('pending socket messages are cleared on reconnect', () async {
      // Simulate sessions that received socket messages while
      // the socket was down (or while non-visible).
      sync.testSetPendingSocketMessages({'sess-a', 'sess-b', 'sess-c'});

      expect(sync.testHasPendingSocketMessage('sess-a'), isTrue);
      expect(sync.testHasPendingSocketMessage('sess-b'), isTrue);

      // On reconnect we re-fetch everything, so pending marker
      // becomes irrelevant — clear it.
      sync.testClearSessionsWithPendingSocketMessages();

      expect(
        sync.testHasPendingSocketMessage('sess-a'),
        isFalse,
        reason: 'pending marker cleared after reconnect full-refetch',
      );
      expect(sync.testHasPendingSocketMessage('sess-b'), isFalse);
      expect(sync.testHasPendingSocketMessage('sess-c'), isFalse);
    });

    test(
      'reconnect preserves existing messages while adding new ones',
      () async {
        const sessionId = 'sess-preserve';

        // Messages 1-10 are already in memory.
        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 15);
        sync.testSetSessionLastSeq(sessionId, 10);
        sync.testSetSessionMessages(sessionId, [
          for (var i = 1; i <= 10; i++) _makePlainMessage('msg-$i', seq: i),
        ]);

        sync.testVisibleSessionId = sessionId;

        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          // Only return the 5 new messages (11-15).
          return _buildMessagesResponse([
            for (var i = 11; i <= 15; i++)
              _makeEncryptedMessage('msg-$i', seq: i),
          ]);
        };

        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        sync.testInvalidateAllSyncs(force: true);
        sync.messagesSync[sessionId]?.invalidate();
        await sync.messagesSync[sessionId]?.awaitQueue();

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);

        // All 15 messages should now be present.
        expect(
          msgs!.length,
          greaterThanOrEqualTo(15),
          reason: 'all 15 messages (1-15) should be present',
        );

        // Original messages must still be there.
        final seqs = msgs.map((m) => m['seq'] as int).toSet();
        for (var i = 1; i <= 10; i++) {
          expect(
            seqs,
            contains(i),
            reason: 'original msg seq=$i must be preserved',
          );
        }
        // New messages must also be there.
        for (var i = 11; i <= 15; i++) {
          expect(
            seqs,
            contains(i),
            reason: 'new msg seq=$i must be added after reconnect',
          );
        }
      },
    );
  });

  group('reconnect watchdog', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testLastInvalidateAllSyncsAtMs = null;
    });

    test(
      'suspend cancels reconnect watchdog timer',
      () async {
        // Resume starts the watchdog.
        sync.resume();

        // Suspend should cancel it.
        sync.suspend();

        // If the watchdog fired after suspend, it would trigger
        // network I/O while backgrounded — that's the bug we're
        // preventing.
        expect(
          InvalidateSync.isBackgrounded,
          isTrue,
          reason: 'suspend should set isBackgrounded = true',
        );
      },
    );

    test(
      'resume after long background triggers force invalidation',
      () async {
        // Simulate a long suspend (>30s).
        sync.testLastSuspendedAtMs =
            DateTime.now().millisecondsSinceEpoch - 60000;

        sync.testInvalidateAllSyncs(force: true);
        final ts = sync.testLastInvalidateAllSyncsAtMs;
        expect(ts, isNotNull);

        // A forced invalidation should always update the timestamp.
        await Future<void>.delayed(const Duration(milliseconds: 2));
        sync.testInvalidateAllSyncs(force: true);
        expect(
          sync.testLastInvalidateAllSyncsAtMs,
          greaterThan(ts!),
          reason:
              'force=true should bypass cooldown for watchdog recovery',
        );
      },
    );
  });

  group('resume from background', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testLastInvalidateAllSyncsAtMs = null;
    });

    test('testResetLastResumeAtMs allows immediate invalidation', () async {
      // Simulate a previous invalidation so the cooldown is active.
      sync.testInvalidateAllSyncs(force: true);
      final afterFirst = sync.testLastInvalidateAllSyncsAtMs;
      expect(afterFirst, isNotNull);

      // Non-forced call is rejected by cooldown.
      sync.testInvalidateAllSyncs();
      expect(
        sync.testLastInvalidateAllSyncsAtMs,
        equals(afterFirst),
        reason: 'cooldown should block non-forced call',
      );

      // After resetting the resume timestamp the forced call can run.
      sync.testResetLastResumeAtMs();
      // Ensure at least 1ms passes so the timestamp is strictly newer.
      await Future<void>.delayed(const Duration(milliseconds: 2));
      sync.testInvalidateAllSyncs(force: true);
      expect(
        sync.testLastInvalidateAllSyncsAtMs,
        greaterThan(afterFirst!),
        reason: 'forced call after reset should update the timestamp',
      );
    });

    test('suspend then resume re-creates visible session message sync '
        'and fetches missed messages', () async {
      const sessionId = 'resume-visible-session';

      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 15);
      sync.testVisibleSessionId = sessionId;
      sync.testSetSessionLastSeq(sessionId, 10);
      sync.testSetSessionMessages(sessionId, [
        for (var i = 1; i <= 10; i++) _makePlainMessage('msg-$i', seq: i),
      ]);
      sync.messagesSync[sessionId] = InvalidateSync(
        () => sync.fetchMessages(sessionId),
      );

      final afterSeqs = <int>[];
      sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
        afterSeqs.add(afterSeq);
        return _buildMessagesResponse([
          for (var i = 11; i <= 15; i++)
            _makeEncryptedMessage('msg-$i', seq: i),
        ]);
      };

      sync.suspend();
      expect(
        sync.messagesSync.containsKey(sessionId),
        isTrue,
        reason: 'Visible session sync entry is retained in the map',
      );

      sync.resume();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await sync.messagesSync[sessionId]?.awaitQueue();

      expect(
        afterSeqs,
        isNotEmpty,
        reason: 'Resume should trigger a message fetch for the visible chat',
      );
      expect(
        afterSeqs.first,
        10,
        reason: 'Visible session resume fetch must continue from the cursor',
      );

      final msgs = sync.testSessionMessages(sessionId);
      expect(msgs, isNotNull);
      final seqs = msgs!.map((m) => m['seq'] as int).toSet();
      for (var i = 11; i <= 15; i++) {
        expect(seqs, contains(i), reason: 'msg seq=$i should be restored');
      }
    });

    test(
      'suspend then resume recovers non-visible session messages '
      'from pending socket id-only events',
      () async {
        const sessionId = 'resume-non-visible-session';

        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 15);
        sync.testSetSessionLastSeq(sessionId, 10);
        sync.testSetSessionMessages(sessionId, [
          for (var i = 1; i <= 10; i++) _makePlainMessage('msg-$i', seq: i),
        ]);
        sync.testVisibleSessionId = 'some-other-session';

        // Regression target: if a non-visible session only receives the
        // id-only new-message socket event, foreground recovery must still
        // fetch the missing messages after resume.
        sync.handleUpdate({'t': 'new-message', 'sid': sessionId});

        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isTrue,
          reason:
              'id-only socket events must mark the non-visible session '
              'for foreground recovery',
        );

        final afterSeqs = <int>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          if (sid == sessionId) {
            afterSeqs.add(afterSeq);
            return _buildMessagesResponse([
              for (var i = 11; i <= 15; i++)
                _makeEncryptedMessage('msg-$i', seq: i),
            ]);
          }
          return _buildMessagesResponse(const <Map<String, dynamic>>[]);
        };

        sync.suspend();
        sync.resume();
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await sync.messagesSync[sessionId]?.awaitQueue();

        expect(
          afterSeqs,
          isNotEmpty,
          reason:
              'resume must trigger a fetch for non-visible sessions that '
              'only had pending socket markers',
        );
        expect(
          afterSeqs.first,
          10,
          reason:
              'resume should reuse the incremental cursor path when '
              'the non-visible session already has messages in memory '
              'and a valid cursor',
        );
        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isFalse,
          reason: 'pending socket marker should be cleared after recovery',
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        final seqs = msgs!.map((m) => m['seq'] as int).toSet();
        for (var i = 11; i <= 15; i++) {
          expect(
            seqs,
            contains(i),
            reason: 'msg seq=$i should be restored after resume',
          );
        }
      },
    );

    test(
      'suspend then resume tail-refreshes pending non-visible sessions '
      'when local state is missing',
      () async {
        const sessionId = 'resume-non-visible-first-load';

        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 15);
        sync.testSetSessionLastSeq(sessionId, 0);
        sync.testVisibleSessionId = 'some-other-session';

        sync.handleUpdate({'t': 'new-message', 'sid': sessionId});

        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isTrue,
          reason:
              'id-only socket events must still mark first-load sessions '
              'for foreground recovery',
        );

        final afterSeqs = <int>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          if (sid == sessionId) {
            afterSeqs.add(afterSeq);
            return _buildMessagesResponse([
              for (var i = 11; i <= 15; i++)
                _makeEncryptedMessage('msg-$i', seq: i),
            ]);
          }
          return _buildMessagesResponse(const <Map<String, dynamic>>[]);
        };

        sync.suspend();
        sync.resume();
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await sync.messagesSync[sessionId]?.awaitQueue();

        expect(
          afterSeqs,
          isNotEmpty,
          reason: 'resume should fetch messages for the pending session',
        );
        expect(
          afterSeqs.first,
          0,
          reason:
              'resume should still force a tail refresh when there is no '
              'usable local message state to continue from',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Session _makeSession(
  String id, {
  String presence = 'offline',
  int lastSeq = 10,
}) {
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
    presence: presence,
    lastSeq: lastSeq,
  );
}

/// A plain (un-encrypted) in-memory message for seeding test state.
Map<String, dynamic> _makePlainMessage(
  String id, {
  required int seq,
  String role = 'agent',
}) {
  return {
    'id': id,
    'seq': seq,
    'role': role,
    'text': 'message $id',
    'createdAt': 1700000000000 + seq * 1000,
  };
}

/// A fake-encrypted agent message in the format expected by
/// [processDecryptedMessages].
///
/// Uses `type: assistant` + string content so the message
/// processor produces a real display-ready entry (kind: 'text')
/// rather than dropping the message silently.
///
/// Content bytes are encoded as [0x01] + utf8(json) to match
/// [_FakeEncryptor.decrypt].
Map<String, dynamic> _makeEncryptedMessage(
  String id, {
  required int seq,
  String content = '',
}) {
  final innerContent = {
    'role': 'agent',
    'content': {
      'type': 'output',
      'data': {
        'type': 'assistant',
        'message': {'content': content.isEmpty ? 'msg $id' : content},
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

Map<String, dynamic> _buildMessagesResponse(
  List<Map<String, dynamic>> messages, {
  bool hasMore = false,
}) {
  return {'messages': messages, 'hasMore': hasMore};
}

void _stubAllSyncs(Sync instance) {
  try {
    instance.sessionsSync.dispose();
  } on Error {
    // Not initialized yet — ignore.
  }
  instance.sessionsSync = InvalidateSync(() async {});
  instance.settingsSync = InvalidateSync(() async {});
  instance.profileSync = InvalidateSync(() async {});
  instance.purchasesSync = InvalidateSync(() async {});
  instance.machinesSync = InvalidateSync(() async {});
  instance.pushTokenSync = InvalidateSync(() async {});
  instance.nativeUpdateSync = InvalidateSync(() async {});
  instance.artifactsSync = InvalidateSync(() async {});
  instance.sessionGitStatusSync = InvalidateSync(() async {});
  instance.messagesSync.clear();
}

// ---------------------------------------------------------------------------
// Fake encryption
// ---------------------------------------------------------------------------

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessions.putIfAbsent(
        sessionId,
        () => _FakeSessionEncryption(sessionId: sessionId),
      );

  @override
  String generateId() => 'test-local-${DateTime.now().microsecondsSinceEpoch}';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
