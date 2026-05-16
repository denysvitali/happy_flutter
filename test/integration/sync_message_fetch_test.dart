import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

/// E2E tests for the message fetch logic in Sync.
///
/// These tests use a mock HTTP layer and a fake session encryption
/// to exercise the full message fetch pipeline including:
/// - Skip logic (cursor >= serverLastSeq)
/// - Gap detection (gapTooLarge)
/// - Tail refresh (first load, force refresh)
/// - Incremental delta fetch
/// - Socket event cursor advancement

void main() {
  group('fetchMessages skip logic', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();

      // Clear all session messages to ensure test isolation
      for (final id in sync.sessionMessages.keys.toList()) {
        sync.testSetSessionMessages(id, []);
      }
      // Clear seq cursors
      for (final id in sync.testSessions.keys.toList()) {
        sync.testSetSessionLastSeq(id, 0);
      }

      // Stub all sync fields
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};

      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() async {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test(
      'does NOT skip fetch when cursorSeq > serverLastSeq (socket outpaced)',
      () async {
        // This is the bug we fixed: when socket events advance _sessionLastSeq
        // past the server's lastSeq, the skip guard should NOT trigger.
        final sessionId = 'sess-1';

        // Pre-populate session with serverLastSeq=10 but cursor at 15
        // (socket has advanced cursor beyond server's knowledge)
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10, // server thinks last seq is 10
        );
        sync.testSetSessionLastSeq(sessionId, 15); // socket advanced to 15
        // Put messages in memory so isFirstLoad=false (tests delta path)
        sync.testSetSessionMessages(sessionId, [
          {'id': 'msg-1', 'seq': 1, 'role': 'user'},
        ]);

        // HTTP mock: capture afterSeq and return messages
        final capturedAfterSeq = <int>[];
        sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
          capturedAfterSeq.add(afterSeq);
          return _buildMessagesResponse([
            _makeAgentMessage('msg-16', seq: 16, content: 'Hello'),
          ]);
        };

        // Act: trigger fetchMessages
        await sync.fetchMessages(sessionId);

        // Assert: HTTP fetch should have been called (not skipped)
        // because cursorSeq(15) > serverLastSeq(10)
        expect(
          capturedAfterSeq.contains(15),
          isTrue,
          reason: 'Should fetch from cursor 15 (socket advanced), not skip',
        );
      },
    );

    test('skips fetch when cursorSeq == serverLastSeq (caught up)', () async {
      final sessionId = 'sess-1';

      // Session with cursor and server in sync at seq 10
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 10);
      sync.testSetSessionLastSeq(sessionId, 10);
      // Put messages in memory so isFirstLoad=false (tests skip path)
      sync.testSetSessionMessages(sessionId, [
        {'id': 'msg-1', 'seq': 1, 'role': 'user'},
      ]);

      final capturedAfterSeq = <int>[];
      sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
        capturedAfterSeq.add(afterSeq);
        return _buildMessagesResponse([]);
      };

      // Act
      await sync.fetchMessages(sessionId);

      // Assert: no HTTP fetch for messages (already caught up)
      expect(
        capturedAfterSeq,
        isEmpty,
        reason: 'Should skip when cursor == server',
      );
    });

    test(
      'fetch probe bypasses caught-up skip when server seq may be stale',
      () async {
        final sessionId = 'sess-1';

        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 10);
        sync.testSetSessionLastSeq(sessionId, 10);
        sync.testSetSessionMessages(sessionId, [
          {'id': 'msg-1', 'seq': 1, 'role': 'user'},
        ]);
        sync.testAddFetchProbe(sessionId);

        final capturedAfterSeq = <int>[];
        sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
          capturedAfterSeq.add(afterSeq);
          return _buildMessagesResponse([
            _makeAgentMessage('msg-11', seq: 11, content: 'Late reply'),
          ]);
        };

        await sync.fetchMessages(sessionId);

        expect(
          capturedAfterSeq,
          equals([10]),
          reason: 'Explicit probe should bypass the caught-up early exit',
        );
        expect(sync.testHasFetchProbe(sessionId), isFalse);
      },
    );

    test('skips fetch when forceTailRefresh but cursor == server', () async {
      // Regression: when onSessionVisible requests a tail refresh but
      // cursor is already caught up (e.g. duplicate socket events),
      // fetchMessages should skip instead of wiping and re-downloading
      // the last 200 messages.
      final sessionId = 'sess-1';

      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 10);
      sync.testSetSessionLastSeq(sessionId, 10);
      sync.testSetSessionMessages(sessionId, [
        {'id': 'msg-1', 'seq': 1, 'role': 'user'},
      ]);
      // Simulate onSessionVisible requesting a tail refresh
      sync.testAddSessionsNeedingTailRefresh(sessionId);

      final capturedAfterSeq = <int>[];
      sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
        capturedAfterSeq.add(afterSeq);
        return _buildMessagesResponse([]);
      };

      await sync.fetchMessages(sessionId);

      // Assert: no HTTP fetch — cursor is caught up, tail refresh is a no-op
      expect(
        capturedAfterSeq,
        isEmpty,
        reason: 'Should skip when forceTailRefresh but cursor == server',
      );
    });

    test(
      'fetches from cursor when cursorSeq < serverLastSeq (normal delta)',
      () async {
        final sessionId = 'sess-1';

        // Session with cursor at 5, server at 10
        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 10);
        sync.testSetSessionLastSeq(sessionId, 5);
        // Put messages in memory so isFirstLoad=false (tests delta path)
        sync.testSetSessionMessages(sessionId, [
          {'id': 'msg-1', 'seq': 1, 'role': 'user'},
        ]);

        final capturedAfterSeq = <int>[];
        sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
          capturedAfterSeq.add(afterSeq);
          return _buildMessagesResponse([
            _makeAgentMessage('msg-6', seq: 6, content: 'Reply'),
            _makeAgentMessage('msg-7', seq: 7, content: 'Reply 2'),
          ]);
        };

        await sync.fetchMessages(sessionId);

        // Assert: fetched from cursor 5
        expect(capturedAfterSeq.first, 5);
      },
    );

    test('uses tail refresh on first load (isFirstLoad=true)', () async {
      final sessionId = 'sess-new';

      // Session with no messages in memory (first load)
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 250);
      // No _sessionLastSeq set (simulates first open)

      final capturedAfterSeq = <int>[];
      sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
        capturedAfterSeq.add(afterSeq);
        // Return messages from seq 51-200
        return _buildMessagesResponse([
          for (var i = 51; i <= 100; i++)
            _makeAgentMessage('msg-$i', seq: i, content: 'Msg $i'),
        ], hasMore: true);
      };

      await sync.fetchMessages(sessionId);

      // Assert: tail load starts at lastSeq - initialLoad = 250 - 200 = 50
      expect(capturedAfterSeq.first, 50);
    });

    test('first load with cursor advanced by socket '
        'events fetches full window', () async {
      // This is the critical scenario: a non-visible
      // session receives socket messages that advance
      // the cursor, but no messages are in memory. When
      // the user opens the session (first load), we must
      // fetch a full window instead of fetching from the
      // already-advanced cursor (which returns nothing).
      final sessionId = 'sess-1';

      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 50);
      // Socket advanced cursor to 50 while non-visible
      sync.testSetSessionLastSeq(sessionId, 50);
      // No messages in memory (first load)

      final capturedAfterSeq = <int>[];
      sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
        capturedAfterSeq.add(afterSeq);
        return _buildMessagesResponse([
          _makeAgentMessage('msg-1', seq: 1, content: 'Hello'),
        ]);
      };

      await sync.fetchMessages(sessionId);

      // Should fetch from 0 (full window since
      // max(50,50)=50 <= initialLoad=200), NOT from
      // cursor 50 which would return nothing.
      expect(
        capturedAfterSeq.first,
        0,
        reason:
            'First load should ignore cursor and fetch '
            'full window',
      );
    });

    test('gapTooLarge falls back to tail refresh', () async {
      final sessionId = 'sess-1';

      // Cursor at 10, server at 300 — gap of 290 (> initialLoad of 200)
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 300);
      sync.testSetSessionLastSeq(sessionId, 10); // far behind

      final capturedAfterSeq = <int>[];
      sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
        capturedAfterSeq.add(afterSeq);
        return _buildMessagesResponse([
          _makeAgentMessage('msg-101', seq: 101, content: 'Recent'),
        ]);
      };

      await sync.fetchMessages(sessionId);

      // Assert: tail refresh starts at lastSeq - initialLoad = 300 - 200 = 100
      expect(capturedAfterSeq.first, 100);
    });

    test(
      'non-visible session fetch stops after first page and requeues',
      () async {
        final sessionId = 'sess-bg';

        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 250);
        sync.testSetSessionLastSeq(sessionId, 0);
        sync.testVisibleSessionId = null;
        sync.messagesSync[sessionId] = InvalidateSync(
          () async {},
          name: 'fetchMessages',
        );

        final capturedAfterSeq = <int>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          capturedAfterSeq.add(afterSeq);
          if (capturedAfterSeq.length == 1) {
            return _buildMessagesResponse([
              _makeAgentMessage('msg-201', seq: 201, content: 'Recent'),
            ], hasMore: true);
          }
          return _buildMessagesResponse([
            _makeAgentMessage('msg-202', seq: 202, content: 'Next page'),
          ]);
        };

        await sync.fetchMessages(sessionId);

        expect(
          capturedAfterSeq,
          equals([50]),
          reason: 'Background fetch should stop after a single page',
        );
      },
    );
  });

  group('fetchMessages with socket inline processing', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();

      // Clear all session messages to ensure test isolation
      for (final id in sync.sessionMessages.keys.toList()) {
        sync.testSetSessionMessages(id, []);
      }
      // Clear seq cursors
      for (final id in sync.testSessions.keys.toList()) {
        sync.testSetSessionLastSeq(id, 0);
      }

      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test('non-visible session delta fetch preserves existing '
        'messages (no destructive tail refresh)', () async {
      // Regression test: when socket messages arrive for a
      // non-visible session, the cursor should NOT be advanced
      // (messages aren't stored in memory). When the user
      // navigates back, fetchMessages should use the
      // incremental delta path (afterSeq = cursor) to fetch
      // only the missing messages, NOT wipe and re-download
      // the last 200 messages via tail refresh.
      final sessionId = 'sess-delta';

      // User was viewing this session — has messages + cursor.
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        lastSeq: 15, // server updated by socket events
      );
      sync.testSetSessionLastSeq(sessionId, 10); // cursor
      sync.testSetSessionMessages(sessionId, [
        {'id': 'msg-1', 'seq': 5, 'role': 'agent'},
        {'id': 'msg-2', 'seq': 10, 'role': 'agent'},
      ]);

      final capturedAfterSeq = <int>[];
      sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
        capturedAfterSeq.add(afterSeq);
        return _buildMessagesResponse([
          _makeAgentMessage('msg-3', seq: 15, content: 'New'),
        ]);
      };

      // fetchMessages should see cursor=10 < server=15 and
      // fetch delta from cursor (not tail-load from 0).
      await sync.fetchMessages(sessionId);

      expect(
        capturedAfterSeq.first,
        10,
        reason: 'Should fetch from cursor=10, not tail-load',
      );
      // Existing messages should be preserved (not wiped).
      final msgs = sync.testSessionMessages(sessionId);
      expect(msgs, isNotNull, reason: 'Messages should still exist');
      expect(
        msgs!.length,
        greaterThanOrEqualTo(2),
        reason: 'Existing messages should be preserved',
      );
    });

    test('socket event advances cursor before fetchMessages runs', () async {
      final sessionId = 'sess-1';

      // Initial session state
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 10);
      sync.testSetSessionLastSeq(sessionId, 10);
      // Put messages in memory so isFirstLoad=false (tests delta path)
      sync.testSetSessionMessages(sessionId, [
        {'id': 'msg-1', 'seq': 1, 'role': 'user'},
      ]);

      // Simulate socket delivers a new message (inline processing)
      // This advances _sessionLastSeq to 15 before fetchMessages checks
      sync.testSetSessionLastSeq(sessionId, 15);

      final capturedAfterSeq = <int>[];
      sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
        capturedAfterSeq.add(afterSeq);
        return _buildMessagesResponse([]);
      };

      // fetchMessages sees cursorSeq=15, serverLastSeq=10
      // With the fix: 15 > 10, so should NOT skip
      await sync.fetchMessages(sessionId);

      // With the fix: cursor > server, should fetch from 15
      expect(capturedAfterSeq.first, 15);
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

/// Creates a fake-encrypted agent message.
/// Uses FakeEncryptor format: [0x01] + utf8(json)
Map<String, dynamic> _makeAgentMessage(
  String id, {
  required int seq,
  required String content,
}) {
  final innerContent = {
    'role': 'agent',
    'content': {
      'type': 'output',
      'data': {'type': 'message', 'message': content},
    },
  };
  final json = jsonEncode(innerContent);
  final bytes = utf8.encode(json);
  final output = Uint8List(bytes.length + 1);
  output[0] = 0x01;
  output.setRange(1, output.length, bytes);
  final b64 = base64Encode(output);

  return {
    'id': id,
    'seq': seq,
    'role': 'agent',
    'content': {'t': 'encrypted', 'c': b64},
    'createdAt': 1700000000000 + seq * 1000,
  };
}

Map<String, dynamic> _buildSessionsResponse(List<Session> sessions) {
  return {
    'sessions': sessions
        .map(
          (s) => {
            'id': s.id,
            'seq': s.seq,
            'createdAt': s.createdAt,
            'updatedAt': s.updatedAt,
            'active': s.active,
            'activeAt': s.activeAt,
            'metadataVersion': s.metadataVersion,
            'agentStateVersion': s.agentStateVersion,
            'thinking': s.thinking,
            'presence': s.presence,
            'lastSeq': s.lastSeq,
          },
        )
        .toList(),
    'hasNext': false,
  };
}

Map<String, dynamic> _buildMessagesResponse(
  List<Map<String, dynamic>> messages, {
  bool hasMore = false,
}) {
  return {'messages': messages, 'hasMore': hasMore};
}

// ---------------------------------------------------------------------------
// Fake encryption for tests
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
    final results = <Uint8List>[];
    for (final item in data) {
      final json = jsonEncode(item);
      final bytes = utf8.encode(json);
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
          final json = utf8.decode(item.sublist(1));
          results.add(jsonDecode(json));
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
