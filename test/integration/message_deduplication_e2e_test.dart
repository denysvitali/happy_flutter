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

/// E2E tests for message deduplication in Sync.
///
/// Verifies that duplicate socket events or overlapping HTTP fetch
/// responses do not create duplicate entries in the message list.
/// Deduplication is handled by [_upsertSessionMessages] which merges
/// incoming messages by their `id` field, replacing any existing entry
/// with the same ID.

void main() {
  group('HTTP fetch deduplication', () {
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
      'duplicate messages from server are merged by ID',
      () async {
        const sessionId = 'http-dedup-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        // Pre-populate with msg-1 at seq=5
        sync.testSetSessionMessages(sessionId, [
          {
            'id': 'msg-1',
            'seq': 5,
            'role': 'agent',
            'createdAt': 1700000005000,
            'text': 'original',
          },
        ]);
        sync.testSetSessionLastSeq(sessionId, 4);

        // Server returns the same msg-1 with updated content
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-1',
              seq: 5,
              content: 'updated content',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);

        final withId = msgs!
            .where((m) => m['id'] == 'msg-1')
            .toList();
        expect(
          withId.length,
          1,
          reason: 'msg-1 must appear exactly once after re-fetch',
        );
      },
    );

    test(
      'messages with same seq but different IDs are kept separate',
      () async {
        const sessionId = 'http-dedup-2';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        sync.testSetSessionMessages(sessionId, []);

        // Server returns two messages that share the same seq
        // but have distinct IDs — both must be stored.
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-a',
              seq: 5,
              content: 'first',
            ),
            _makeEncryptedMessage(
              'msg-b',
              seq: 5,
              content: 'second',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        expect(
          msgs!.any((m) => m['id'] == 'msg-a'),
          isTrue,
          reason: 'msg-a must be present',
        );
        expect(
          msgs.any((m) => m['id'] == 'msg-b'),
          isTrue,
          reason: 'msg-b must be present',
        );
      },
    );
  });

  group('socket inline deduplication', () {
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
      'duplicate socket events for same message ID are merged',
      () async {
        const sessionId = 'socket-dedup-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        sync.testSetSessionMessages(sessionId, []);

        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        // Suppress HTTP fallback — return empty for any fetch
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([]);
        };

        final encMsg = _makeEncryptedMessage(
          'msg-socket-1',
          seq: 6,
          content: 'hello',
        );

        // Inject the same socket event twice
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': encMsg,
        });
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': encMsg,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);

        final withId = msgs!
            .where((m) => m['id'] == 'msg-socket-1')
            .toList();
        expect(
          withId.length,
          1,
          reason: 'Duplicate socket events must not create duplicates',
        );
      },
    );

    test(
      'socket message with higher seq updates existing message',
      () async {
        const sessionId = 'socket-dedup-2';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10,
        );

        // Pre-populate msg-1 at seq=5
        sync.testSetSessionMessages(sessionId, [
          {
            'id': 'msg-1',
            'seq': 5,
            'role': 'agent',
            'createdAt': 1700000005000,
            'text': 'old content',
          },
        ]);

        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        // Suppress HTTP fallback
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([]);
        };

        // Inject socket event for msg-1 with higher seq=10
        final updatedMsg = _makeEncryptedMessage(
          'msg-1',
          seq: 10,
          content: 'updated content',
        );
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': updatedMsg,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);

        final withId = msgs!
            .where((m) => m['id'] == 'msg-1')
            .toList();
        expect(
          withId.length,
          1,
          reason: 'msg-1 should appear exactly once after upsert',
        );
        // The upserted entry should reflect the incoming seq
        expect(
          withId.first['seq'],
          10,
          reason: 'seq should be updated to 10 after upsert',
        );
      },
    );
  });

  group('optimistic message merge with server response', () {
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
      'server response merges with optimistic local message via localId',
      () async {
        const sessionId = 'optimistic-merge-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );

        // Simulate an optimistic message inserted before server ack
        sync.testSetSessionMessages(sessionId, [
          {
            'id': 'local-1',
            'localId': 'local-1',
            'seq': 0,
            'role': 'user',
            'createdAt': 1700000000000,
            'sendStatus': 'sending',
            'content': 'hello',
          },
        ]);
        sync.testSetSessionLastSeq(sessionId, 0);

        // Server returns the authoritative record for the
        // same message, referencing the local placeholder via
        // localId.
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'server-msg-1',
              seq: 5,
              content: 'hello',
              role: 'user',
              localId: 'local-1',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);

        // The optimistic placeholder must be gone
        final localCopies = msgs!
            .where((m) => m['id'] == 'local-1')
            .toList();
        expect(
          localCopies,
          isEmpty,
          reason:
              'Optimistic placeholder must be replaced by server record',
        );

        // The server record must exist
        final serverCopies = msgs
            .where((m) => m['id'] == 'server-msg-1')
            .toList();
        expect(
          serverCopies.length,
          1,
          reason: 'Server record must appear exactly once',
        );
      },
    );

    test(
      'server ack replaces the exact optimistic placeholder by localId, '
      'not by repeated text or list position',
      () async {
        const sessionId = 'optimistic-merge-2';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 9,
        );

        sync.testSetSessionMessages(sessionId, [
          {
            'id': 'local-1',
            'localId': 'local-1',
            'seq': 0,
            'role': 'user',
            'createdAt': 1700000000000,
            'sendStatus': 'sending',
            'content': 'continue',
          },
          {
            'id': 'local-2',
            'localId': 'local-2',
            'seq': 0,
            'role': 'user',
            'createdAt': 1700000001000,
            'sendStatus': 'sending',
            'content': 'continue',
          },
          {
            'id': 'local-3',
            'localId': 'local-3',
            'seq': 0,
            'role': 'user',
            'createdAt': 1700000002000,
            'sendStatus': 'sending',
            'content': 'continue',
          },
        ]);
        sync.testSetSessionLastSeq(sessionId, 0);

        sync.testUpsertSessionMessages(sessionId, [
          {
            'id': 'server-msg-2',
            'localId': 'local-2',
            'seq': 9,
            'role': 'user',
            'createdAt': 1700000003000,
            'sendStatus': 'sent',
            'content': 'continue',
          },
        ]);

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        expect(
          msgs!,
          hasLength(3),
          reason:
              'A server ack must replace one optimistic placeholder, '
              'not add a duplicate logical message',
        );

        expect(
          msgs.where((m) => m['id'] == 'local-1'),
          hasLength(1),
          reason:
              'The first repeated-text placeholder must remain because '
              'its localId was not acknowledged',
        );
        expect(
          msgs.where((m) => m['id'] == 'local-2'),
          isEmpty,
          reason:
              'Only the placeholder matching the acked localId may be '
              'replaced',
        );
        expect(
          msgs.where((m) => m['id'] == 'local-3'),
          hasLength(1),
          reason:
              'Later repeated-text placeholders must not be replaced by '
              'position',
        );

        final serverCopies = msgs
            .where((m) => m['id'] == 'server-msg-2')
            .toList();
        expect(serverCopies, hasLength(1));
        expect(serverCopies.single['localId'], 'local-2');
        expect(serverCopies.single['sendStatus'], 'sent');
      },
    );

    test(
      'server user record without localId replaces one matching optimistic '
      'row without collapsing repeated text',
      () {
        const sessionId = 'optimistic-merge-without-localid';
        sync.testSetSessionMessages(sessionId, [
          {
            'id': 'local-1',
            'localId': 'local-1',
            'seq': -1,
            'role': 'user',
            'createdAt': 1700000000000,
            'sendStatus': 'sending',
            'content': 'continue',
          },
          {
            'id': 'local-2',
            'localId': 'local-2',
            'seq': -1,
            'role': 'user',
            'createdAt': 1700000001000,
            'sendStatus': 'sending',
            'content': 'continue',
          },
        ]);

        sync.testUpsertSessionMessages(sessionId, [
          {
            'id': 'server-msg-1',
            'seq': 1,
            'role': 'user',
            'createdAt': 1700000000050,
            'content': 'continue',
          },
        ]);

        final msgs = sync.testSessionMessages(sessionId)!;
        expect(msgs, hasLength(2));
        expect(msgs.where((m) => m['id'] == 'local-1'), isEmpty);
        expect(msgs.where((m) => m['id'] == 'local-2'), hasLength(1));
        expect(
          msgs.singleWhere((m) => m['id'] == 'server-msg-1')['localId'],
          'local-1',
        );
      },
    );
  });

  group('sidechain merge-path regression', () {
    late Sync sync;

    setUp(() {
      sync = Sync();

      for (final id in sync.sessionMessages.keys.toList()) {
        sync.testSetSessionMessages(id, []);
      }
      sync.testSessions.clear();

      _stubAllSyncs(sync);
    });

    test(
      'sidechain messages must not remove Task tool-calls '
      'via shared localId',
      () {
        // Regression: When multiple Task/Agent tool-calls share the
        // same wire message localId, arriving sidechain-root messages
        // with that same localId would remove the last Task card via
        // the localIdToId reverse index, progressively deleting all
        // but the first agent.
        const sessionId = 'sidechain-merge-1';

        // Pre-populate with 3 Task tool-calls that share the same
        // localId (as they would from a single assistant wire message).
        const sharedLocalId = 'wire-msg-1';
        sync.testSetSessionMessages(sessionId, [
          {
            'id': 'task-1',
            'localId': sharedLocalId,
            'seq': 5,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Task',
            'createdAt': 1700000005000,
            'toolUseId': 'toolu_1',
            'state': 'running',
            'input': {'prompt': 'Task 1'},
          },
          {
            'id': 'task-2',
            'localId': sharedLocalId,
            'seq': 5,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Task',
            'createdAt': 1700000006000,
            'toolUseId': 'toolu_2',
            'state': 'running',
            'input': {'prompt': 'Task 2'},
          },
          {
            'id': 'task-3',
            'localId': sharedLocalId,
            'seq': 5,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Task',
            'createdAt': 1700000007000,
            'toolUseId': 'toolu_3',
            'state': 'running',
            'input': {'prompt': 'Task 3'},
          },
        ]);

        // Now upsert sidechain-root messages that also have the same
        // localId — this must NOT remove any Task card.
        sync.testUpsertSessionMessages(sessionId, [
          {
            'id': 'sidechain-root-1',
            'localId': sharedLocalId,
            'seq': 6,
            'createdAt': 1700000008000,
            'kind': 'sidechain-root',
            'isSidechain': true,
            'prompt': 'Task 1',
            'parentUuid': 'toolu_1',
          },
          {
            'id': 'sidechain-root-2',
            'localId': sharedLocalId,
            'seq': 7,
            'createdAt': 1700000009000,
            'kind': 'sidechain-root',
            'isSidechain': true,
            'prompt': 'Task 2',
            'parentUuid': 'toolu_2',
          },
          {
            'id': 'sidechain-root-3',
            'localId': sharedLocalId,
            'seq': 8,
            'createdAt': 1700000010000,
            'kind': 'sidechain-root',
            'isSidechain': true,
            'prompt': 'Task 3',
            'parentUuid': 'toolu_3',
          },
        ]);

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);

        // All 3 Task tool-calls must still be present
        for (final taskId in ['task-1', 'task-2', 'task-3']) {
          final count = msgs!
              .where((m) => m['id'] == taskId)
              .length;
          expect(
            count,
            1,
            reason:
                '$taskId must survive merge — sidechain-root '
                'messages must not remove it via shared localId',
          );
        }

        // Sidechain roots should also be present
        for (final scId in [
          'sidechain-root-1',
          'sidechain-root-2',
          'sidechain-root-3',
        ]) {
          expect(
            msgs!.any((m) => m['id'] == scId),
            isTrue,
            reason: '$scId should be present after merge',
          );
        }
      },
    );
  });

  group('cross-source deduplication', () {
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
      'HTTP fetch message + socket inline message for same ID '
      'results in one message',
      () async {
        const sessionId = 'cross-source-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10,
        );
        sync.testSetSessionMessages(sessionId, []);

        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        // HTTP fetch returns msg-x
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-x',
              seq: 10,
              content: 'from http',
            ),
          ]);
        };

        // Trigger fetch first
        await sync.fetchMessages(sessionId);
        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        // Now inject the same message via socket
        final encMsg = _makeEncryptedMessage(
          'msg-x',
          seq: 10,
          content: 'from socket',
        );
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': encMsg,
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);

        final withId = msgs!
            .where((m) => m['id'] == 'msg-x')
            .toList();
        expect(
          withId.length,
          1,
          reason:
              'Same ID from HTTP and socket must result in one entry',
        );
      },
    );

    test(
      'multiple rapid fetches do not create duplicates',
      () async {
        const sessionId = 'rapid-fetch-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        sync.testSetSessionMessages(sessionId, []);

        // Both fetches return an overlapping set of messages
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-1',
              seq: 3,
              content: 'message one',
            ),
            _makeEncryptedMessage(
              'msg-2',
              seq: 4,
              content: 'message two',
            ),
            _makeEncryptedMessage(
              'msg-3',
              seq: 5,
              content: 'message three',
            ),
          ]);
        };

        // Fire two concurrent fetches
        await Future.wait([
          sync.fetchMessages(sessionId),
          sync.fetchMessages(sessionId),
        ]);

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);

        // Each ID must appear exactly once
        for (final id in ['msg-1', 'msg-2', 'msg-3']) {
          final count = msgs!
              .where((m) => m['id'] == id)
              .length;
          expect(
            count,
            1,
            reason: '$id must appear exactly once after rapid fetches',
          );
        }
      },
    );

    test(
      'REST-acked message followed by later socket echo keeps one '
      'logical message',
    () async {
      const sessionId = 'cross-source-2';

      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        lastSeq: 11,
      );
      sync.testSetSessionMessages(sessionId, [
        {
          'id': 'srv-msg-1',
          'localId': 'local-1',
          'seq': 11,
          'role': 'user',
          'kind': 'text',
          'createdAt': 1700000011000,
          'content': 'continue',
          'sendStatus': 'sent',
        },
      ]);
      sync.testSetSessionLastSeq(sessionId, 11);

      sync.testVisibleSessionId = sessionId;
      sync.messagesSync[sessionId] = InvalidateSync(
        () => sync.fetchMessages(sessionId),
      );
      sync.testFetchMessagesOverride = (_, __, ___) async {
        return _buildMessagesResponse([]);
      };

      sync.handleUpdate({
        't': 'new-message',
        'sid': sessionId,
        'message': _makeEncryptedMessage(
          'srv-msg-1',
          seq: 11,
          content: 'continue',
          role: 'user',
          localId: 'local-1',
        ),
      });

      await Future<void>.delayed(const Duration(milliseconds: 200));

      final msgs = sync.testSessionMessages(sessionId);
      expect(msgs, isNotNull);

      final matching = msgs!.where((m) => m['id'] == 'srv-msg-1').toList();
      expect(
        matching,
        hasLength(1),
        reason:
            'A socket echo arriving after REST ack must not duplicate the '
            'already-acked logical message',
      );
      expect(matching.single['localId'], 'local-1');
    });

    test(
      'REST-acked message followed by later fetch overlap keeps one '
      'logical message',
    () async {
      const sessionId = 'cross-source-3';

      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        lastSeq: 11,
      );
      sync.testSetSessionMessages(sessionId, [
        {
          'id': 'srv-msg-1',
          'localId': 'local-1',
          'seq': 11,
          'role': 'user',
          'kind': 'text',
          'createdAt': 1700000011000,
          'content': 'continue',
          'sendStatus': 'sent',
        },
      ]);
      sync.testSetSessionLastSeq(sessionId, 10);

      sync.testFetchMessagesOverride = (_, __, ___) async {
        return _buildMessagesResponse([
          _makeEncryptedMessage(
            'srv-msg-1',
            seq: 11,
            content: 'continue',
            role: 'user',
            localId: 'local-1',
          ),
        ]);
      };

      await sync.fetchMessages(sessionId);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final msgs = sync.testSessionMessages(sessionId);
      expect(msgs, isNotNull);

      final matching = msgs!.where((m) => m['id'] == 'srv-msg-1').toList();
      expect(
        matching,
        hasLength(1),
        reason:
            'A fetch overlapping with an already-acked message must not '
            'create a second logical copy',
      );
      expect(matching.single['localId'], 'local-1');
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
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

void _stubAllSyncs(Sync instance) {
  try {
    instance.sessionsSync.dispose();
  } on Error {
    // Not yet initialized — ignore.
  }
  instance
    ..sessionsSync = InvalidateSync(() async {})
    ..settingsSync = InvalidateSync(() async {})
    ..profileSync = InvalidateSync(() async {})
    ..purchasesSync = InvalidateSync(() async {})
    ..machinesSync = InvalidateSync(() async {})
    ..pushTokenSync = InvalidateSync(() async {})
    ..nativeUpdateSync = InvalidateSync(() async {})
    ..artifactsSync = InvalidateSync(() async {})
    ..sessionGitStatusSync = InvalidateSync(() async {})
    ..messagesSync.clear();
}

/// Builds a fake-encrypted message in the wire format that
/// [SessionEncryption.decryptAndProcessMessages] can decode.
///
/// Uses the [_FakeEncryptor] format: `[0x01] + utf8(json)`.
///
/// By default creates an agent message.  Pass [role] = `'user'`
/// for user messages.  [localId] is forwarded to the wire
/// envelope for optimistic-merge tests.
Map<String, dynamic> _makeEncryptedMessage(
  String id, {
  required int seq,
  required String content,
  String role = 'agent',
  String? localId,
}) {
  final Map<String, dynamic> innerContent;
  if (role == 'user') {
    innerContent = {
      'role': 'user',
      'content': {'type': 'text', 'text': content},
    };
  } else {
    innerContent = {
      'role': 'agent',
      'content': {
        'type': 'output',
        'data': {
          'type': 'assistant',
          'message': content,
        },
      },
    };
  }
  final json = jsonEncode(innerContent);
  final bytes = utf8.encode(json);
  final output = Uint8List(bytes.length + 1);
  output[0] = 0x01;
  output.setRange(1, output.length, bytes);

  return {
    'id': id,
    'seq': seq,
    'role': role,
    'content': {
      't': 'encrypted',
      'c': base64Encode(output),
    },
    'createdAt': 1700000000000 + seq * 1000,
    if (localId != null) 'localId': localId,
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
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessions.putIfAbsent(
        sessionId,
        () => _FakeSessionEncryption(sessionId: sessionId),
      );

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
