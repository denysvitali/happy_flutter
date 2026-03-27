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

/// E2E tests for backward message pagination (fetchOlderMessages).
///
/// Exercises:
/// - hasOlderMessages guard logic
/// - fetchOlderMessages pagination
/// - _sessionFirstLoadedSeq tracking and persistence
/// - Multi-page backward pagination
void main() {
  group('hasOlderMessages', () {
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
    });

    test('returns false when firstLoaded is null', () {
      const sessionId = 'sess-new';
      // No firstLoadedSeq set
      expect(sync.hasOlderMessages(sessionId), isFalse);
    });

    test('returns false when firstLoaded <= 1', () {
      const sessionId = 'sess-empty';
      sync.testSetSessionFirstLoadedSeq(sessionId, 0);
      expect(sync.hasOlderMessages(sessionId), isFalse);

      sync.testSetSessionFirstLoadedSeq(sessionId, 1);
      expect(sync.hasOlderMessages(sessionId), isFalse);
    });

    test('returns true when firstLoaded > 1', () {
      const sessionId = 'sess-old';
      sync.testSetSessionFirstLoadedSeq(sessionId, 201);
      expect(sync.hasOlderMessages(sessionId), isTrue);

      sync.testSetSessionFirstLoadedSeq(sessionId, 50);
      expect(sync.hasOlderMessages(sessionId), isTrue);
    });
  });

  group('fetchOlderMessages basic', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      _stubAllSyncs(sync);
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchOlderMessagesOverride = null;
    });

    test('isLoadingOlderMessages returns true while fetch is in progress',
        () async {
      const sessionId = 'sess-loading';

      // Pre-populate so hasOlderMessages returns true
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 500);
      sync.testSetSessionFirstLoadedSeq(sessionId, 201);

      // Block the fetch until we check
      var fetchStarted = false;
      sync.testFetchOlderMessagesOverride =
          (sid, afterSeq, limit) async {
        fetchStarted = true;
        // Simulate some async work
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _buildMessagesResponse([]);
      };

      expect(sync.isLoadingOlderMessages(sessionId), isFalse);

      // Start fetch (won't await)
      final fetchFuture = sync.fetchOlderMessages(sessionId);
      expect(sync.isLoadingOlderMessages(sessionId), isTrue);

      await fetchFuture;
      expect(sync.isLoadingOlderMessages(sessionId), isFalse);
    });

    test(
        'returns early if isLoadingOlderMessages is already true', () async {
      const sessionId = 'sess-duplicate';

      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 500);
      sync.testSetSessionFirstLoadedSeq(sessionId, 201);

      var callCount = 0;
      sync.testFetchOlderMessagesOverride =
          (sid, afterSeq, limit) async {
        callCount++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _buildMessagesResponse([]);
      };

      // Start two fetches simultaneously
      await Future.wait([
        sync.fetchOlderMessages(sessionId),
        sync.fetchOlderMessages(sessionId),
      ]);

      // Should only call the override once
      expect(callCount, 1);
    });

    test('returns early if firstLoaded <= 1 (nothing older to fetch)', () async {
      const sessionId = 'sess-exhausted';

      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 500);
      sync.testSetSessionFirstLoadedSeq(sessionId, 1);

      var callCount = 0;
      sync.testFetchOlderMessagesOverride =
          (sid, afterSeq, limit) async {
        callCount++;
        return _buildMessagesResponse([]);
      };

      await sync.fetchOlderMessages(sessionId);

      expect(callCount, 0,
          reason: 'Should not fetch when firstLoaded <= 1');
    });

    test('returns early if firstLoaded is null', () async {
      const sessionId = 'sess-null';

      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 500);
      // Don't set firstLoadedSeq

      var callCount = 0;
      sync.testFetchOlderMessagesOverride =
          (sid, afterSeq, limit) async {
        callCount++;
        return _buildMessagesResponse([]);
      };

      await sync.fetchOlderMessages(sessionId);

      expect(callCount, 0,
          reason: 'Should not fetch when firstLoaded is null');
    });
  });

  group('fetchOlderMessages pagination', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      _stubAllSyncs(sync);
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchOlderMessagesOverride = null;
    });

    test('fetches page of older messages and updates firstLoadedSeq',
        () async {
      const sessionId = 'sess-page-1';

      // Initial state: firstLoadedSeq=201 means we've loaded up to seq 200
      // (messages 201-500 are loaded)
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 500);
      sync.testSetSessionFirstLoadedSeq(sessionId, 201);

      final capturedParams = <List<dynamic>>[];
      sync.testFetchOlderMessagesOverride =
          (sid, afterSeq, limit) async {
        capturedParams.add([sid, afterSeq, limit]);
        // Return messages 101-200
        return _buildMessagesResponse([
          for (var i = 101; i <= 200; i++)
            _makeEncryptedMessage('msg-$i', seq: i, content: 'Msg $i'),
        ]);
      };

      await sync.fetchOlderMessages(sessionId);

      expect(capturedParams.length, 1);
      // startSeq = (201 - 1 - 100) = 100, so we fetch after_seq=100
      // which should return messages 101-200
      expect(capturedParams[0][0], sessionId);
      expect(capturedParams[0][1], 100,
          reason: 'Should fetch after_seq=100 (firstLoaded-1-pageSize)');
      expect(capturedParams[0][2], 100);

      // firstLoadedSeq should now be updated to 101 (the lowest seq loaded)
      expect(sync.testSessionFirstLoadedSeq(sessionId), 101);
    });

    test(
        'second fetchOlderMessages loads the next page '
        '(101-200 was loaded, now loads 1-100)', () async {
      const sessionId = 'sess-page-2';

      // After first backward fetch, firstLoadedSeq=101
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 500);
      sync.testSetSessionFirstLoadedSeq(sessionId, 101);

      final capturedParams = <List<dynamic>>[];
      sync.testFetchOlderMessagesOverride =
          (sid, afterSeq, limit) async {
        capturedParams.add([sid, afterSeq, limit]);
        // Return messages 1-100
        return _buildMessagesResponse([
          for (var i = 1; i <= 100; i++)
            _makeEncryptedMessage('msg-$i', seq: i, content: 'Msg $i'),
        ]);
      };

      await sync.fetchOlderMessages(sessionId);

      expect(capturedParams.length, 1);
      // startSeq = (101 - 1 - 100) = 0, clamped to [0, 100] = 0
      // So we fetch after_seq=0 which returns messages 1+
      expect(capturedParams[0][1], 0,
          reason: 'Should fetch after_seq=0 to get the oldest messages');
    });

    test(
        'when firstLoaded reaches 0, hasOlderMessages returns false '
        '(all messages loaded)', () async {
      const sessionId = 'sess-exhausted';

      // firstLoadedSeq=1 means only seq 1 is the boundary, nothing before it
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 500);
      sync.testSetSessionFirstLoadedSeq(sessionId, 1);

      // Should not even attempt fetch
      var callCount = 0;
      sync.testFetchOlderMessagesOverride =
          (sid, afterSeq, limit) async {
        callCount++;
        return _buildMessagesResponse([]);
      };

      await sync.fetchOlderMessages(sessionId);

      expect(callCount, 0,
          reason: 'Should not fetch when firstLoadedSeq=1');
      expect(sync.hasOlderMessages(sessionId), isFalse);
    });

    test('fetches messages in correct order (oldest first)', () async {
      const sessionId = 'sess-order';

      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 500);
      sync.testSetSessionFirstLoadedSeq(sessionId, 201);

      final capturedMessages = <Map<String, dynamic>>[];
      sync.testFetchOlderMessagesOverride =
          (sid, afterSeq, limit) async {
        // Return messages in ascending seq order (as the server would)
        return _buildMessagesResponse([
          _makeEncryptedMessage('msg-150', seq: 150, content: 'First'),
          _makeEncryptedMessage('msg-175', seq: 175, content: 'Middle'),
          _makeEncryptedMessage('msg-200', seq: 200, content: 'Last'),
        ]);
      };

      await sync.fetchOlderMessages(sessionId);

      final messages = sync.testSessionMessages(sessionId);
      expect(messages, isNotNull);

      // Messages should be stored in seq order
      final seqs = messages!.map((m) => m['seq'] as int).toList();
      expect(seqs, [150, 175, 200],
          reason: 'Messages should be stored in seq order');
    });
  });

  group('fetchOlderMessages with encryption', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      _stubAllSyncs(sync);
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchOlderMessagesOverride = null;
    });

    test('decrypts encrypted messages correctly', () async {
      const sessionId = 'sess-encrypted';

      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 500);
      sync.testSetSessionFirstLoadedSeq(sessionId, 201);

      sync.testFetchOlderMessagesOverride =
          (sid, afterSeq, limit) async {
        // Return encrypted messages
        return _buildMessagesResponse([
          _makeEncryptedMessage('msg-150', seq: 150, content: 'Secret msg'),
        ]);
      };

      await sync.fetchOlderMessages(sessionId);

      final messages = sync.testSessionMessages(sessionId);
      expect(messages, isNotNull);
      expect(messages!.length, 1);
      expect(messages[0]['id'], 'msg-150');
    });
  });

  group('_sessionFirstLoadedSeq tracking', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
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
      sync.testFetchOlderMessagesOverride = null;
    });

    test(
        'first load with lastSeq > initialLoad sets firstLoadedSeq correctly',
        () async {
      const sessionId = 'sess-tail';

      // Session with 500 messages, first load
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 500);
      // No messages in memory (first load), no cursor set

      sync.testFetchMessagesOverride =
          (sid, afterSeq, limit) async {
        // Server returns messages 301-500
        return _buildMessagesResponse([
          for (var i = 301; i <= 500; i++)
            _makeEncryptedMessage('msg-$i', seq: i, content: 'Msg $i'),
        ], hasMore: false);
      };

      await sync.fetchMessages(sessionId);

      // afterSeq = 500 - 200 = 300, so firstLoadedSeq should be 301
      expect(
        sync.testSessionFirstLoadedSeq(sessionId),
        301,
        reason: 'firstLoadedSeq should be afterSeq+1 (300+1=301)',
      );
      expect(sync.hasOlderMessages(sessionId), isTrue,
          reason: 'firstLoadedSeq=301 > 1 means there are older messages');
    });

    test(
        'first load with lastSeq <= initialLoad sets firstLoadedSeq to 0 '
        '(session fully loaded)', () async {
      const sessionId = 'sess-short';

      // Session with only 150 messages (less than initialLoad of 200)
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 150);
      // No messages in memory

      sync.testFetchMessagesOverride =
          (sid, afterSeq, limit) async {
        // Server returns all messages 1-150
        return _buildMessagesResponse([
          for (var i = 1; i <= 150; i++)
            _makeEncryptedMessage('msg-$i', seq: i, content: 'Msg $i'),
        ], hasMore: false);
      };

      await sync.fetchMessages(sessionId);

      // afterSeq = 0 (because knownMax=150 <= initialLoad=200)
      // So firstLoadedSeq should be 0 (meaning fully loaded)
      expect(
        sync.testSessionFirstLoadedSeq(sessionId),
        0,
        reason: 'firstLoadedSeq=0 means all messages loaded (short session)',
      );
      expect(sync.hasOlderMessages(sessionId), isFalse,
          reason: 'firstLoadedSeq=0 means no older messages');
    });

    test(
        'delta fetch (cursor already established) does NOT change firstLoadedSeq',
        () async {
      const sessionId = 'sess-delta';

      // Session already has messages loaded, cursor at 300
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 400);
      sync.testSetSessionLastSeq(sessionId, 300);
      sync.testSetSessionFirstLoadedSeq(sessionId, 201);
      // Pre-populate some messages
      sync.testSetSessionMessages(sessionId, [
        for (var i = 201; i <= 300; i++)
          {'id': 'msg-$i', 'seq': i, 'role': 'agent'},
      ]);

      sync.testFetchMessagesOverride =
          (sid, afterSeq, limit) async {
        // Server returns messages 301-400
        return _buildMessagesResponse([
          for (var i = 301; i <= 400; i++)
            _makeEncryptedMessage('msg-$i', seq: i, content: 'Msg $i'),
        ], hasMore: false);
      };

      await sync.fetchMessages(sessionId);

      // firstLoadedSeq should NOT change (delta fetch adds newer messages,
      // doesn't affect the oldest loaded seq)
      expect(
        sync.testSessionFirstLoadedSeq(sessionId),
        201,
        reason: 'firstLoadedSeq should remain 201 (delta fetch does not change it)',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
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

/// Creates a fake-encrypted agent message.
///
/// Uses the legacy `type: 'assistant'` + string content format so that
/// [processDecryptedMessages] produces a real display-ready message entry
/// (kind: 'text') rather than dropping the message silently.
///
/// Uses FakeEncryptor format: [0x01] + utf8(json)
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
        'message': content, // bare string (legacy format)
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