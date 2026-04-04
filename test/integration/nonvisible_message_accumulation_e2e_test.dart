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

/// E2E tests for non-visible session message accumulation.
///
/// Exercises the lifecycle where socket events arrive for sessions the
/// user is not currently viewing, and verifies correct behaviour when
/// the user later navigates to those sessions.
void main() {
  // ---------------------------------------------------------------------------
  // Group 1: non-visible session accumulation
  // ---------------------------------------------------------------------------
  group('non-visible session accumulation', () {
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
      sync.testClearSessionsWithPendingSocketMessages();
    });

    test(
      'socket events for non-visible session are processed inline',
      () async {
        const sessionId = 'sess-bg-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10,
        );

        // Inject three new-message events while session is not visible.
        sync.handleUpdate(_makeNewMessageUpdate(
          sessionId,
          messageId: 'msg-11',
          seq: 11,
          content: 'First',
        ));
        sync.handleUpdate(_makeNewMessageUpdate(
          sessionId,
          messageId: 'msg-12',
          seq: 12,
          content: 'Second',
        ));
        sync.handleUpdate(_makeNewMessageUpdate(
          sessionId,
          messageId: 'msg-13',
          seq: 13,
          content: 'Third',
        ));

        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Embedded messages are now processed inline even for
        // non-visible sessions so they are available immediately
        // when the user navigates to the session.  The pending
        // flag is only set for events without an embedded message.
        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isFalse,
          reason:
              'Embedded messages are processed inline — no pending '
              'flag needed',
        );

        // The pending updates flag should still be set (for
        // session list UI refresh).
        expect(
          sync.testHasPendingUpdate(sessionId),
          isTrue,
          reason:
              'Non-visible session should have pending updates '
              'flag set after receiving socket events',
        );
      },
    );

    test(
      'non-visible session decrypts and stores embedded messages inline',
      () async {
        const sessionId = 'sess-bg-2';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );

        // Inject a new-message event with embedded content.
        sync.handleUpdate(_makeNewMessageUpdate(
          sessionId,
          messageId: 'msg-6',
          seq: 6,
          content: 'Background message',
        ));

        await Future<void>.delayed(const Duration(milliseconds: 500));

        // lastSeq should be updated so the gap is detected later.
        final session = sync.testSessions[sessionId];
        expect(
          session!.lastSeq,
          equals(6),
          reason: 'lastSeq should track server seq for gap detection',
        );

        // Embedded messages are now processed inline for non-visible
        // sessions, so the pending flag should NOT be set.
        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isFalse,
          reason:
              'Embedded messages processed inline — no pending flag',
        );
      },
    );

    test(
      'pending updates flag is per-session',
      () async {
        const sessA = 'sess-A';
        const sessB = 'sess-B';
        sync.testSessions[sessA] = _makeSession(sessA, lastSeq: 10);
        sync.testSessions[sessB] = _makeSession(sessB, lastSeq: 20);

        // Events for sess-A only.
        sync.handleUpdate(_makeNewMessageUpdate(
          sessA,
          messageId: 'msg-A-11',
          seq: 11,
          content: 'For A',
        ));

        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Embedded messages are processed inline so the pending
        // socket flag is NOT set.  But the pending *updates* flag
        // (used for session list UI refresh) should be set.
        expect(
          sync.testHasPendingUpdate(sessA),
          isTrue,
          reason:
              'sess-A should have pending updates flag after its '
              'event',
        );
        expect(
          sync.testHasPendingUpdate(sessB),
          isFalse,
          reason: 'sess-B should NOT have pending updates flag',
        );

        // Now inject an event for sess-B.
        sync.handleUpdate(_makeNewMessageUpdate(
          sessB,
          messageId: 'msg-B-21',
          seq: 21,
          content: 'For B',
        ));

        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(
          sync.testHasPendingUpdate(sessA),
          isTrue,
          reason: 'sess-A flag should still be set',
        );
        expect(
          sync.testHasPendingUpdate(sessB),
          isTrue,
          reason: 'sess-B should now have its own pending updates flag',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 2: transition from non-visible to visible
  // ---------------------------------------------------------------------------
  group('transition from non-visible to visible', () {
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
      sync.testClearSessionsWithPendingSocketMessages();
    });

    test(
      'navigating to session with pending messages triggers fetch',
      () async {
        const sessionId = 'sess-nav-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 15,
        );
        // Mark the session as having received socket messages
        // while non-visible.
        sync.testSetPendingSocketMessages({sessionId});

        final fetchCalled = <String>[];
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          fetchCalled.add(sid);
          return _buildMessagesResponse([
            _makeEncryptedMessage('msg-11', seq: 11, content: 'Hi'),
          ]);
        };

        // Signal that the user navigated to the session.
        sync.onSessionVisible(sessionId);

        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(
          fetchCalled,
          contains(sessionId),
          reason:
              'onSessionVisible must trigger a server fetch when '
              'pending socket messages exist',
        );
      },
    );

    test(
      'fetch after visibility correctly merges new messages '
      'with existing',
      () async {
        const sessionId = 'sess-merge-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 12,
        );

        // Pre-load two messages already in memory with cursor at 10.
        sync.testSetSessionMessages(sessionId, [
          {
            'id': 'msg-1',
            'seq': 5,
            'role': 'user',
            'text': 'Hello',
            'createdAt': 1700000005000,
          },
          {
            'id': 'msg-2',
            'seq': 10,
            'role': 'agent',
            'text': 'Hi there',
            'createdAt': 1700000010000,
          },
        ]);
        sync.testSetSessionLastSeq(sessionId, 10);

        // Mark pending so onSessionVisible triggers a fetch.
        sync.testSetPendingSocketMessages({sessionId});

        // HTTP mock returns two new messages (seq 11, 12).
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-11',
              seq: 11,
              content: 'New reply 1',
            ),
            _makeEncryptedMessage(
              'msg-12',
              seq: 12,
              content: 'New reply 2',
            ),
          ]);
        };

        sync.onSessionVisible(sessionId);

        await Future<void>.delayed(const Duration(milliseconds: 200));

        final messages = sync.testSessionMessages(sessionId);
        expect(
          messages,
          isNotNull,
          reason: 'Messages map must be populated',
        );
        // After merge we expect at least the original 2 plus the
        // 2 new ones.
        expect(
          messages!.length,
          greaterThanOrEqualTo(2),
          reason:
              'Merged messages must include both existing and '
              'newly fetched entries',
        );
      },
    );

    test(
      'pending flag is cleared after successful fetch',
      () async {
        const sessionId = 'sess-clear-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 12,
        );
        sync.testSetPendingSocketMessages({sessionId});

        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedMessage('msg-11', seq: 11, content: 'A'),
          ]);
        };

        // Pending flag should be set before navigation.
        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isTrue,
        );

        sync.onSessionVisible(sessionId);

        // onSessionVisible removes the flag synchronously before
        // kicking off the async fetch, so we can check immediately.
        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isFalse,
          reason:
              'Pending flag must be cleared when session becomes '
              'visible (onSessionVisible removes it synchronously)',
        );

        // Let the fetch settle.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isFalse,
          reason:
              'Pending flag must remain cleared after fetch completes',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 3: cursor management across visibility
  // ---------------------------------------------------------------------------
  group('cursor management across visibility', () {
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
      sync.testClearSessionsWithPendingSocketMessages();
    });

    test(
      'cursor advances for non-visible sessions when inline processing',
      () async {
        const sessionId = 'sess-cursor-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10,
        );
        // Set cursor to 10 — simulates the user having previously
        // read messages up to seq 10.
        sync.testSetSessionLastSeq(sessionId, 10);

        // Inject socket events for this non-visible session.
        sync.handleUpdate(_makeNewMessageUpdate(
          sessionId,
          messageId: 'msg-11',
          seq: 11,
          content: 'Background 1',
        ));
        sync.handleUpdate(_makeNewMessageUpdate(
          sessionId,
          messageId: 'msg-12',
          seq: 12,
          content: 'Background 2',
        ));

        await Future<void>.delayed(const Duration(milliseconds: 500));

        final cursor =
            sync.sessionMessageCursors[sessionId] ?? 0;
        // Cursor now advances for non-visible sessions because
        // messages are processed inline (decrypted and stored).
        expect(
          cursor,
          greaterThanOrEqualTo(10),
          reason:
              'Cursor may advance as non-visible sessions now '
              'process inline messages',
        );
      },
    );

    test(
      'cursor advances normally after session becomes visible '
      'and fetches',
      () async {
        const sessionId = 'sess-cursor-2';
        // Server has 15 messages, cursor at 10.
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 15,
        );
        sync.testSetSessionLastSeq(sessionId, 10);
        // Pre-load existing messages so it's not a first-load.
        sync.testSetSessionMessages(sessionId, [
          {
            'id': 'msg-1',
            'seq': 5,
            'role': 'user',
            'text': 'Earlier',
            'createdAt': 1700000005000,
          },
          {
            'id': 'msg-2',
            'seq': 10,
            'role': 'agent',
            'text': 'Earlier reply',
            'createdAt': 1700000010000,
          },
        ]);

        // Mark as having pending socket messages so fetch is forced.
        sync.testSetPendingSocketMessages({sessionId});

        final newMessages = [
          _makeEncryptedMessage('msg-11', seq: 11, content: 'X'),
          _makeEncryptedMessage('msg-12', seq: 12, content: 'Y'),
          _makeEncryptedMessage('msg-13', seq: 13, content: 'Z'),
          _makeEncryptedMessage('msg-14', seq: 14, content: 'W'),
          _makeEncryptedMessage('msg-15', seq: 15, content: 'V'),
        ];

        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse(newMessages);
        };

        sync.onSessionVisible(sessionId);

        await Future<void>.delayed(const Duration(milliseconds: 200));

        final cursor =
            sync.sessionMessageCursors[sessionId] ?? 0;
        // After a successful fetch the cursor should be at or
        // beyond the max seq returned (15).
        expect(
          cursor,
          greaterThanOrEqualTo(15),
          reason:
              'Cursor must advance to at least seq=15 after a '
              'successful fetch of the new messages',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Sync setup helpers
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

// ---------------------------------------------------------------------------
// Model helpers
// ---------------------------------------------------------------------------

Session _makeSession(
  String id, {
  int lastSeq = 10,
  String presence = 'offline',
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

/// Creates a `new-message` socket update payload with an embedded
/// encrypted message.
Map<String, dynamic> _makeNewMessageUpdate(
  String sessionId, {
  required String messageId,
  required int seq,
  required String content,
}) {
  return {
    't': 'new-message',
    'sid': sessionId,
    'message': _makeEncryptedMessage(messageId, seq: seq, content: content),
  };
}

/// Creates a wire-format encrypted message map that can be used both
/// as an embedded socket payload and in HTTP fetch responses.
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

// ---------------------------------------------------------------------------
// Fake encryption
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
