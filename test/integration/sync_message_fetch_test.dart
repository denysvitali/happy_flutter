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
      sync.friendsSync = InvalidateSync(() async {});
      sync.friendRequestsSync = InvalidateSync(() async {});
      sync.feedSync = InvalidateSync(() async {});
      sync.todosSync = InvalidateSync(() async {});
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

    test('does NOT skip fetch when cursorSeq > serverLastSeq (socket outpaced)', () async {
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
    });

    test('skips fetch when cursorSeq == serverLastSeq (caught up)', () async {
      final sessionId = 'sess-1';

      // Session with cursor and server in sync at seq 10
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 10);
      sync.testSetSessionLastSeq(sessionId, 10);

      final capturedAfterSeq = <int>[];
      sync.testFetchMessagesOverride = (sessionId, afterSeq, limit) async {
        capturedAfterSeq.add(afterSeq);
        return _buildMessagesResponse([]);
      };

      // Act
      await sync.fetchMessages(sessionId);

      // Assert: no HTTP fetch for messages (already caught up)
      expect(capturedAfterSeq, isEmpty, reason: 'Should skip when cursor == server');
    });

    test('fetches from cursor when cursorSeq < serverLastSeq (normal delta)', () async {
      final sessionId = 'sess-1';

      // Session with cursor at 5, server at 10
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 10);
      sync.testSetSessionLastSeq(sessionId, 5);

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
    });

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
      sync.friendsSync = InvalidateSync(() async {});
      sync.friendRequestsSync = InvalidateSync(() async {});
      sync.feedSync = InvalidateSync(() async {});
      sync.todosSync = InvalidateSync(() async {});
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

    test('socket event advances cursor before fetchMessages runs', () async {
      final sessionId = 'sess-1';

      // Initial session state
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 10);
      sync.testSetSessionLastSeq(sessionId, 10);

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
      'data': {
        'type': 'message',
        'message': content,
      },
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
        .map((s) => {
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
            })
        .toList(),
    'hasNext': false,
  };
}

Map<String, dynamic> _buildMessagesResponse(
  List<Map<String, dynamic>> messages, {
  bool hasMore = false,
}) {
  return {
    'messages': messages,
    'hasMore': hasMore,
  };
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

