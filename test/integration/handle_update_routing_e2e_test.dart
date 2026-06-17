import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

/// E2E tests for handleUpdate and handleEphemeralUpdate event routing.
///
/// Verifies that each event type is dispatched to the correct handler and
/// that observable state (sessions map, messagesSync, pending flags, streams)
/// changes as expected.

void main() {
  // ---------------------------------------------------------------------------
  // Group 1: new-message event routing
  // ---------------------------------------------------------------------------

  group('new-message event routing', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();

      _clearSyncState(sync);
      _stubAllSyncs(sync);

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'new-message for non-visible session processes inline',
      () async {
        const sessionId = 'sess-A';

        sync.testSessions[sessionId] = _makeSession(sessionId);
        sync.testSetSessionMessages(sessionId, []);
        sync.testVisibleSessionId = null;

        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': _makeEncryptedMessage(
            'msg-1',
            seq: 2,
            content: 'hello',
          ),
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 500),
        );

        // Embedded messages are now processed inline for
        // non-visible sessions so they are immediately available.
        // The pending updates flag (for session list UI) is set.
        expect(
          sync.testHasPendingUpdate(sessionId),
          isTrue,
          reason:
              'Non-visible session should have pending updates '
              'flag for session list refresh',
        );
      },
    );

    test(
      'new-message for visible session triggers inline processing',
      () async {
        const sessionId = 'sess-visible';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 1,
        );
        sync.testSetSessionMessages(sessionId, []);
        sync.testVisibleSessionId = sessionId;
        // Use the fetch override so the fallback path never calls ApiClient.
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          return <String, dynamic>{
            'messages': <Map<String, dynamic>>[],
            'hasMore': false,
          };
        };
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': _makeEncryptedMessage(
            'msg-vis-1',
            seq: 2,
            content: 'visible session message',
          ),
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(
          msgs,
          isNotNull,
          reason: 'Messages list should exist after inline processing',
        );
        expect(
          msgs!.isNotEmpty,
          isTrue,
          reason: 'Inline message should appear in session messages',
        );
      },
    );

    test(
      'new-message without embedded message still marks pending',
      () async {
        const sessionId = 'sess-no-msg';

        sync.testSessions[sessionId] = _makeSession(sessionId);
        sync.testSetSessionMessages(sessionId, []);
        sync.testVisibleSessionId = null;

        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          // No 'message' field
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isTrue,
          reason:
              'New-message without embedded payload should still '
              'mark session as pending',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 2: update-session event
  // ---------------------------------------------------------------------------

  group('session-update event', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();

      _clearSyncState(sync);
      _stubAllSyncs(sync);

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'session-update enqueues sessionId in pending update set',
      () async {
        const sessionId = 'sess-upd-1';

        sync.testSessions[sessionId] = _makeSession(sessionId);

        // The pending IDs set is cleared after the debounce timer fires
        // (2s), so we check before it drains.
        sync.handleUpdate({
          't': 'update-session',
          'id': sessionId,
        });

        // The session id is added synchronously before the timer fires.
        expect(
          sync.testPendingUpdateSessionIdsEmpty(),
          isFalse,
          reason:
              'update-session should add the session id to the '
              'pending update set before the debounce timer drains',
        );
      },
    );

    test(
      'session-update drains pending session IDs after debounce',
      () async {
        const sessionId = 'sess-upd-2';

        sync.testSessions[sessionId] = _makeSession(sessionId);

        sync.handleUpdate({
          't': 'update-session',
          'id': sessionId,
        });

        // Pending set is populated synchronously…
        expect(
          sync.testPendingUpdateSessionIdsEmpty(),
          isFalse,
          reason:
              'Session id should be in the pending set immediately '
              'after the update-session event is dispatched',
        );

        // …then drained once the debounce timer fires (2s).
        await Future<void>.delayed(
          const Duration(milliseconds: 2500),
        );

        expect(
          sync.testPendingUpdateSessionIdsEmpty(),
          isTrue,
          reason:
              'Pending session IDs should be cleared after the '
              'debounced sessions-refresh flush runs',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 3: delete-session event
  // ---------------------------------------------------------------------------

  group('delete-session event', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();

      _clearSyncState(sync);
      _stubAllSyncs(sync);

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'delete-session removes session from _sessions',
      () async {
        const sessionId = 'sess-del-1';

        sync.testSessions[sessionId] = _makeSession(sessionId);
        expect(
          sync.testSessions.containsKey(sessionId),
          isTrue,
          reason: 'Session should be present before delete',
        );

        sync.handleUpdate({
          't': 'delete-session',
          'sid': sessionId,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        expect(
          sync.testSessions.containsKey(sessionId),
          isFalse,
          reason:
              'Session should be removed from _sessions after '
              'delete-session event',
        );
      },
    );

    test(
      'delete-session cleans up _sessionSpawnedAt entry',
      () async {
        const sessionId = 'sess-del-spawn';

        sync.testSessions[sessionId] = _makeSession(sessionId);
        sync.testSetSessionSpawnedAt(
          sessionId,
          DateTime.now().millisecondsSinceEpoch,
        );

        expect(
          sync.testSessionSpawnedAt.containsKey(sessionId),
          isTrue,
          reason: 'Spawn timestamp should exist before delete',
        );

        sync.handleUpdate({
          't': 'delete-session',
          'sid': sessionId,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        expect(
          sync.testSessionSpawnedAt.containsKey(sessionId),
          isFalse,
          reason:
              'delete-session should remove the session spawn '
              'timestamp from _sessionSpawnedAt',
        );
      },
    );

    test(
      'delete-session removes messagesSync entry',
      () async {
        const sessionId = 'sess-del-msgsync';

        sync.testSessions[sessionId] = _makeSession(sessionId);
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        expect(
          sync.messagesSync.containsKey(sessionId),
          isTrue,
          reason: 'messagesSync entry should exist before delete',
        );

        sync.handleUpdate({
          't': 'delete-session',
          'sid': sessionId,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        expect(
          sync.messagesSync.containsKey(sessionId),
          isFalse,
          reason:
              'delete-session should dispose and remove the '
              'messagesSync entry for the deleted session',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 4: session-thinking event (via ephemeral activity update)
  // ---------------------------------------------------------------------------

  group('session-thinking event', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();

      _clearSyncState(sync);
      _stubAllSyncs(sync);

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'activity event with thinking=true updates session thinking state',
      () async {
        const sessionId = 'sess-think-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          thinking: false,
          presence: 'offline',
        );

        sync.handleEphemeralUpdate({
          't': 'activity',
          'id': sessionId,
          'thinking': true,
          'active': true,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final session = sync.testSessions[sessionId];
        expect(
          session,
          isNotNull,
          reason: 'Session should still exist after activity update',
        );
        expect(
          session!.thinking,
          isTrue,
          reason:
              'Session thinking flag should be true after '
              'activity event with thinking=true',
        );
      },
    );

    test(
      'activity event fires onDomainChanged(sessions)',
      () async {
        const sessionId = 'sess-think-notify';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          thinking: false,
          presence: 'offline',
        );

        var notified = false;
        final sub = sync.onDomainChanged
            .where((d) => d == SyncDomain.sessions)
            .listen((_) => notified = true);

        sync.handleEphemeralUpdate({
          't': 'activity',
          'id': sessionId,
          'thinking': true,
          'active': true,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 400),
        );

        await sub.cancel();

        expect(
          notified,
          isTrue,
          reason:
              'onDomainChanged(sessions) should fire after an activity '
              'ephemeral event updates session state',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 5: session-presence event (via ephemeral activity update)
  // ---------------------------------------------------------------------------

  group('session-presence event', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();

      _clearSyncState(sync);
      _stubAllSyncs(sync);

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'activity with active=true transitions presence to online',
      () async {
        const sessionId = 'sess-pres-online';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          presence: 'offline',
        );

        sync.handleEphemeralUpdate({
          't': 'activity',
          'id': sessionId,
          'thinking': false,
          'active': true,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final session = sync.testSessions[sessionId];
        expect(
          session,
          isNotNull,
          reason: 'Session should still exist after presence update',
        );
        expect(
          session!.presence,
          equals('online'),
          reason:
              'Presence should be online after activity event '
              'with active=true',
        );
      },
    );

    test(
      'activity with active=false transitions presence to offline',
      () async {
        const sessionId = 'sess-pres-offline';

        // Start online so we can observe the transition.
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          presence: 'online',
        );

        sync.handleEphemeralUpdate({
          't': 'activity',
          'id': sessionId,
          'active': false,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final session = sync.testSessions[sessionId];
        expect(
          session,
          isNotNull,
          reason: 'Session should still exist after offline transition',
        );
        expect(
          session!.presence,
          equals('offline'),
          reason:
              'Presence should be offline after activity event '
              'with active=false',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 6: ephemeral events (do not modify persistent state)
  // ---------------------------------------------------------------------------

  group('ephemeral events', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();

      _clearSyncState(sync);
      _stubAllSyncs(sync);

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'ephemeral update does not modify persistent session state',
      () async {
        const sessionId = 'sess-eph-1';
        const otherSessionId = 'sess-eph-2';

        sync.testSessions[sessionId] = _makeSession(sessionId);
        sync.testSessions[otherSessionId] = _makeSession(otherSessionId);

        final sessionsBefore =
            Map<String, Session>.from(sync.testSessions);

        // Inject an ephemeral event for a session that has no entry in
        // _sessions (unknown session) — should not create a new entry.
        sync.handleEphemeralUpdate({
          't': 'unknown-ephemeral-type',
          'id': 'non-existent-session',
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        // Sessions map should be unchanged.
        expect(
          sync.testSessions.keys.toSet(),
          equals(sessionsBefore.keys.toSet()),
          reason:
              'Ephemeral events for unknown sessions should not '
              'add entries to the persistent sessions map',
        );

        // Existing sessions should not be modified.
        for (final id in sessionsBefore.keys) {
          final before = sessionsBefore[id]!;
          final after = sync.testSessions[id];
          expect(
            after,
            isNotNull,
            reason: 'Existing session $id should still be present',
          );
          expect(
            after!.id,
            equals(before.id),
            reason: 'Session $id id should be unchanged',
          );
          expect(
            after.seq,
            equals(before.seq),
            reason: 'Session $id seq should be unchanged',
          );
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 7: loops events
  // ---------------------------------------------------------------------------

  group('loops events', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      _clearSyncState(sync);
      _stubAllSyncs(sync);
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testClearAllLoops();
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testVisibleSessionId = null;
      sync.testClearAllLoops();
    });

    test('loops-updated replaces the session list', () async {
      const sessionId = 'sess-loops-1';
      sync.testLoopsBySession[sessionId] = const <Loop>[];

      await sync.handleUpdate(<String, dynamic>{
        't': 'loops-updated',
        'sid': sessionId,
        'loops': [
          <String, dynamic>{
            'id': 'aaaa1111',
            'sessionId': sessionId,
            'expression': '*/5 * * * *',
            'prompt': 'check',
            'recurring': true,
            'createdAt': 1700000000000,
            'expiresAt': 1700604800000,
            'fireCount': 0,
            'paused': false,
          },
        ],
      });

      final loops = sync.loopsForSession(sessionId);
      expect(loops, hasLength(1));
      expect(loops.single.id, 'aaaa1111');
    });

    test('loop-fired bumps lastFiredAt + fireCount', () async {
      const sessionId = 'sess-loops-2';
      sync.testLoopsBySession[sessionId] = [
        Loop(
          id: 'bbbb2222',
          sessionId: sessionId,
          expression: '*/5 * * * *',
          prompt: 'check',
          recurring: true,
          createdAt: 1700000000000,
          expiresAt: 1700604800000,
          fireCount: 1,
        ),
      ];

      await sync.handleUpdate(<String, dynamic>{
        't': 'loop-fired',
        'sid': sessionId,
        'loopId': 'bbbb2222',
        'firedAt': 1700000060000,
        'fireCount': 2,
      });

      final updated = sync.loopsForSession(sessionId).single;
      expect(updated.lastFiredAt, 1700000060000);
      expect(updated.fireCount, 2);
    });

    test('loop-expired removes the loop from the session list', () async {
      const sessionId = 'sess-loops-3';
      sync.testLoopsBySession[sessionId] = [
        Loop(
          id: 'cccc3333',
          sessionId: sessionId,
          expression: '*/5 * * * *',
          prompt: 'a',
          recurring: true,
          createdAt: 1,
          expiresAt: 2,
        ),
        Loop(
          id: 'dddd4444',
          sessionId: sessionId,
          expression: '0 9 * * *',
          prompt: 'b',
          recurring: false,
          createdAt: 1,
          expiresAt: 2,
        ),
      ];

      await sync.handleUpdate(<String, dynamic>{
        't': 'loop-expired',
        'sid': sessionId,
        'loopId': 'dddd4444',
      });

      final remaining = sync.loopsForSession(sessionId);
      expect(remaining, hasLength(1));
      expect(remaining.single.id, 'cccc3333');
    });

    test('delete-session clears loops for the deleted session', () async {
      const sessionId = 'sess-loops-del';
      sync.testLoopsBySession[sessionId] = [
        Loop(
          id: 'eeee5555',
          sessionId: sessionId,
          expression: '*/5 * * * *',
          prompt: 'a',
          recurring: true,
          createdAt: 1,
          expiresAt: 2,
        ),
      ];
      sync.testSessions[sessionId] = _makeSession(sessionId);

      await sync.handleUpdate(<String, dynamic>{
        't': 'delete-session',
        'sid': sessionId,
      });

      expect(sync.loopsForSession(sessionId), isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Session _makeSession(
  String id, {
  int seq = 1,
  int lastSeq = 10,
  bool thinking = false,
  String presence = 'offline',
}) {
  return Session(
    id: id,
    seq: seq,
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    active: true,
    activeAt: 1700000000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: presence,
    lastSeq: lastSeq,
  );
}

/// Creates a fake-encrypted socket message payload.
/// Uses the FakeEncryptor wire format: byte 0x01 + utf8(json).
Map<String, dynamic> _makeEncryptedMessage(
  String id, {
  required int seq,
  required String content,
}) {
  final innerContent = <String, dynamic>{
    'role': 'agent',
    'content': {
      'type': 'output',
      'data': {
        'type': 'assistant',
        'message': content,
      },
    },
  };
  final jsonStr = jsonEncode(innerContent);
  final bytes = utf8.encode(jsonStr);
  final output = Uint8List(bytes.length + 1);
  output[0] = 0x01;
  output.setRange(1, output.length, bytes);
  final b64 = base64Encode(output);

  return <String, dynamic>{
    'id': id,
    'seq': seq,
    'role': 'agent',
    'content': {'t': 'encrypted', 'c': b64},
    'createdAt': 1700000000000 + seq * 1000,
  };
}

/// Resets transient in-memory state between tests.
void _clearSyncState(Sync sync) {
  for (final id in sync.sessionMessages.keys.toList()) {
    sync.testSetSessionMessages(id, []);
  }
  sync.testSessions.clear();
  sync.testClearSessionsWithPendingSocketMessages();
  sync.testClearSessionSpawnedAt();
}

/// Stubs all 13 InvalidateSync fields to no-op callbacks so tests never
/// make real network calls.
void _stubAllSyncs(Sync instance) {
  try {
    instance.sessionsSync.dispose();
  } on Error {
    // Not yet initialized — ignore.
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
// Fake encryption classes
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
  String generateId() =>
      'test-local-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void removeSessionEncryption(String sessionId) {
    _sessions.remove(sessionId);
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
    final results = <Uint8List>[];
    for (final item in data) {
      final jsonStr = jsonEncode(item);
      final bytes = utf8.encode(jsonStr);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      results.add(output);
    }
    return results;
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    final results = <dynamic>[];
    for (final item in data) {
      if (item.isEmpty) {
        results.add(null);
        continue;
      }
      try {
        if (item[0] == 0x01) {
          results.add(jsonDecode(utf8.decode(item.sublist(1))));
        } else {
          results.add(utf8.decode(item));
        }
      } catch (_) {
        results.add(null);
      }
    }
    return results;
  }
}
