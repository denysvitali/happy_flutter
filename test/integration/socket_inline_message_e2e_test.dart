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

/// E2E tests for the socket inline message processing fast path.
///
/// These tests verify that messages arriving via WebSocket for visible
/// sessions are decrypted inline without triggering an HTTP fetch, and
/// that non-visible sessions are correctly tracked for deferred fetch.

void main() {
  group('inline message processing for visible sessions', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();

      // Clear state from previous tests
      for (final id in sync.sessionMessages.keys.toList()) {
        sync.testSetSessionMessages(id, []);
      }
      for (final id in sync.testSessions.keys.toList()) {
        sync.testSetSessionLastSeq(id, 0);
      }
      sync.testSessions.clear();
      sync.testClearSessionsWithPendingSocketMessages();

      _stubAllSyncs(sync);

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;

      // Prevent the HTTP fallback from trying to call ApiClient
      // when inline processing triggers a messagesSync invalidation.
      sync.testFetchMessagesOverride = (_, __, ___) async => {
        'messages': <Map<String, dynamic>>[],
        'hasMore': false,
      };
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'socket message for visible session is decrypted inline '
      'and added to messages',
      () async {
        const sessionId = 'visible-sess-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 1,
        );
        sync.testSetSessionMessages(sessionId, []);

        // Mark the session as visible
        sync.testVisibleSessionId = sessionId;

        // Pre-populate messagesSync so the inline path works
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        // Inject a socket new-message event with an embedded message
        final encMsg = _makeEncryptedMessage(
          'msg-1',
          seq: 2,
          content: 'Hello from socket',
        );
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': encMsg,
        });

        // Allow inline decryption to complete
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

    test('inline message advances seq cursor', () async {
      const sessionId = 'visible-seq-1';

      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        lastSeq: 5,
      );
      sync.testSetSessionMessages(sessionId, []);
      sync.testSetSessionLastSeq(sessionId, 5);
      sync.testVisibleSessionId = sessionId;
      sync.messagesSync[sessionId] = InvalidateSync(
        () => sync.fetchMessages(sessionId),
      );

      final encMsg = _makeEncryptedMessage(
        'msg-6',
        seq: 6,
        content: 'New message',
      );
      sync.handleUpdate({
        't': 'new-message',
        'sid': sessionId,
        'message': encMsg,
      });

      await Future<void>.delayed(
        const Duration(milliseconds: 200),
      );

      // Cursor should have advanced to at least seq 6
      final cursors = sync.sessionMessageCursors;
      final cursor = cursors[sessionId] ?? 0;
      expect(
        cursor,
        greaterThanOrEqualTo(6),
        reason: 'Seq cursor should advance after inline processing',
      );
    });

    test(
      'multiple inline messages are processed in order',
      () async {
        const sessionId = 'visible-order-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10,
        );
        sync.testSetSessionMessages(sessionId, []);
        sync.testSetSessionLastSeq(sessionId, 10);
        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        // Send 3 messages with different seqs
        for (var i = 11; i <= 13; i++) {
          sync.handleUpdate({
            't': 'new-message',
            'sid': sessionId,
            'message': _makeEncryptedMessage(
              'msg-$i',
              seq: i,
              content: 'Message $i',
            ),
          });
        }

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(
          msgs,
          isNotNull,
          reason: 'Messages should be present',
        );
        // All 3 messages should be in the list
        expect(
          msgs!.length,
          greaterThanOrEqualTo(3),
          reason: 'All 3 inline messages should be stored',
        );

        // Verify messages are in ascending seq order
        final seqs = msgs.map((m) => m['seq'] as int? ?? 0).toList();
        for (var i = 1; i < seqs.length; i++) {
          expect(
            seqs[i],
            greaterThanOrEqualTo(seqs[i - 1]),
            reason: 'Messages should be in ascending seq order',
          );
        }
      },
    );

    test(
      'inline codex tool-call and result are merged into a rendered tool',
      () async {
        const sessionId = 'visible-codex-tool-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 20,
        );
        sync.testSetSessionMessages(sessionId, []);
        sync.testSetSessionLastSeq(sessionId, 20);
        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': _makeEncryptedStructuredMessage(
            'msg-tool-1',
            seq: 21,
            data: {
              'type': 'tool-call',
              'name': 'CodexBash',
              'callId': 'call-1',
              'input': {
                'command': ['/bin/bash -lc pwd'],
                'parsed_cmd': [
                  {'cmd': '/bin/bash -lc pwd'},
                ],
              },
            },
          ),
        });

        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': _makeEncryptedStructuredMessage(
            'msg-tool-2',
            seq: 22,
            data: {
              'type': 'tool-call-result',
              'callId': 'call-1',
              'output': {
                'stdout': '/tmp/work\n',
                'exitCode': 0,
                'status': 'completed',
              },
            },
          ),
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 300),
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        expect(msgs, hasLength(1));
        expect(msgs!.single['kind'], 'tool-call');
        expect(msgs.single['name'], 'CodexBash');
        expect(msgs.single['state'], 'completed');
        expect(
          (msgs.single['result'] as Map<String, dynamic>)['stdout'],
          '/tmp/work\n',
        );
      },
    );

    test(
      'inline message triggers onSessionMessagesChanged notification',
      () async {
        const sessionId = 'visible-notify-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 1,
        );
        sync.testSetSessionMessages(sessionId, []);
        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        final notifiedIds = <String>[];
        final sub = sync.onSessionMessagesChanged.listen(
          notifiedIds.add,
        );

        final encMsg = _makeEncryptedMessage(
          'msg-notify-1',
          seq: 2,
          content: 'Notification test',
        );
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': encMsg,
        });

        // Wait for: async inline decryption + 200ms debounce timer
        await Future<void>.delayed(
          const Duration(milliseconds: 500),
        );

        await sub.cancel();

        expect(
          notifiedIds.contains(sessionId),
          isTrue,
          reason: 'onSessionMessagesChanged should fire for visible session',
        );
      },
    );
  });

  group('non-visible session socket handling', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();

      for (final id in sync.sessionMessages.keys.toList()) {
        sync.testSetSessionMessages(id, []);
      }
      for (final id in sync.testSessions.keys.toList()) {
        sync.testSetSessionLastSeq(id, 0);
      }
      sync.testSessions.clear();
      sync.testClearSessionsWithPendingSocketMessages();

      _stubAllSyncs(sync);

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testFetchMessagesOverride = (_, __, ___) async => {
        'messages': <Map<String, dynamic>>[],
        'hasMore': false,
      };
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
      sync.testVisibleSessionId = null;
    });

    test(
      'socket message for non-visible session is processed inline',
      () async {
        const sessionId = 'non-visible-pending-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        sync.testSetSessionMessages(sessionId, []);

        // Ensure no session is visible
        sync.testVisibleSessionId = null;

        final encMsg = _makeEncryptedMessage(
          'msg-bg-1',
          seq: 6,
          content: 'Background message',
        );
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': encMsg,
        });

        // Allow inline processing
        await Future<void>.delayed(
          const Duration(milliseconds: 500),
        );

        // Embedded messages are now processed inline for
        // non-visible sessions.  The pending socket flag is only
        // set for events without an embedded message.
        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isFalse,
          reason:
              'Embedded messages are processed inline — no '
              'pending socket flag needed',
        );
        // But pending updates should still be set.
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
      'non-visible session decrypts and merges messages inline',
      () async {
        const sessionId = 'non-visible-no-decrypt-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        // Pre-populate with an existing message
        final existingMessages = [
          {
            'id': 'old-msg',
            'seq': 5,
            'role': 'user',
            'text': 'existing',
            'createdAt': 1700000005000,
          },
        ];
        sync.testSetSessionMessages(sessionId, existingMessages);

        // Different session is visible
        sync.testVisibleSessionId = 'some-other-session';

        final encMsg = _makeEncryptedMessage(
          'msg-bg-2',
          seq: 6,
          content: 'Should be decrypted inline',
        );
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': encMsg,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 500),
        );

        // Non-visible sessions now process embedded messages
        // inline so they are available immediately on navigation.
        final msgs = sync.testSessionMessages(sessionId);
        expect(
          msgs,
          isNotNull,
          reason: 'Messages should be present',
        );
        // Existing message should be preserved; new one merged.
        expect(
          msgs!.length,
          greaterThanOrEqualTo(1),
          reason:
              'Non-visible session should have at least the '
              'existing message after inline processing',
        );
        expect(
          msgs.any((m) => m['id'] == 'old-msg'),
          isTrue,
          reason: 'Original message should be preserved',
        );

        // lastSeq should track the server seq.
        final session = sync.testSessions[sessionId];
        expect(
          session!.lastSeq,
          equals(6),
          reason: 'lastSeq should track server seq',
        );
      },
    );
  });

  group('session visibility transitions', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();

      for (final id in sync.sessionMessages.keys.toList()) {
        sync.testSetSessionMessages(id, []);
      }
      for (final id in sync.testSessions.keys.toList()) {
        sync.testSetSessionLastSeq(id, 0);
      }
      sync.testSessions.clear();
      sync.testClearSessionsWithPendingSocketMessages();

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
      'switching visible session triggers fetch for pending messages',
      () async {
        const sessionId = 'pending-fetch-sess-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10,
        );
        sync.testSetSessionMessages(sessionId, []);
        sync.testSetSessionLastSeq(sessionId, 5);

        // Mark session as having received socket messages while
        // non-visible
        sync.testSetPendingSocketMessages({sessionId});

        expect(
          sync.testHasPendingSocketMessage(sessionId),
          isTrue,
          reason: 'Session should have pending socket messages',
        );

        final fetchedSessions = <String>[];
        sync.testFetchMessagesOverride = (sid, afterSeq, limit) async {
          fetchedSessions.add(sid);
          return {
            'messages': <Map<String, dynamic>>[],
            'hasMore': false,
          };
        };

        // Simulate user navigating to the session with pending messages
        sync.onSessionVisible(sessionId);

        // Allow fetch to complete
        await Future<void>.delayed(
          const Duration(milliseconds: 300),
        );

        expect(
          fetchedSessions.contains(sessionId),
          isTrue,
          reason:
              'fetchMessages should be called when navigating to '
              'a session with pending socket messages',
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
/// Uses FakeEncryptor format: [0x01] + utf8(json)
///
/// The inner content uses `type: 'codex'` with `data.type: 'message'`
/// so that [processDecryptedMessages] via [_processCodexContent] will
/// produce a displayable text message.
Map<String, dynamic> _makeEncryptedMessage(
  String id, {
  required int seq,
  required String content,
}) {
  return _makeEncryptedStructuredMessage(
    id,
    seq: seq,
    data: {
      'type': 'message',
      'message': content,
    },
  );
}

Map<String, dynamic> _makeEncryptedStructuredMessage(
  String id, {
  required int seq,
  required Map<String, dynamic> data,
}) {
  final innerContent = {
    'role': 'agent',
    'content': {
      'type': 'codex',
      'data': data,
    },
  };
  final jsonStr = jsonEncode(innerContent);
  final bytes = utf8.encode(jsonStr);
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

void _stubAllSyncs(Sync instance) {
  try {
    instance.sessionsSync.dispose();
  } on Error {
    // Not yet initialized — ignore
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
          final jsonStr = utf8.decode(item.sublist(1));
          results.add(jsonDecode(jsonStr));
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
