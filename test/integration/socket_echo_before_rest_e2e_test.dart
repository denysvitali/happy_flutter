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

/// E2E tests for the case where a socket echo arrives BEFORE any REST
/// response.  This exercises the canonical-localId merge contract under
/// inverted timing — the server may push via socket faster than the
/// REST POST response can travel back, especially on weak networks.
///
/// Invariants asserted:
///   - The optimistic placeholder is replaced by `localId` match, never
///     by text similarity or list position.
///   - A later REST ack carrying the same `localId` does NOT create a
///     duplicate.
///   - Final state has exactly ONE message with the canonical `localId`.
///
/// These tests inject the socket and REST events directly via the merge
/// helpers (`testUpsertSessionMessages`) so the ordering is fully
/// deterministic.  The full `Sync.sendMessage` flow is exercised by
/// `concurrent_send_message_e2e_test.dart` and
/// `message_deduplication_e2e_test.dart` — this file pins the precise
/// race ordering the merge code must withstand.

void main() {
  group('socket echo before REST success', () {
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
      'socket echo replaces optimistic placeholder by localId — '
      'subsequent REST ack must not duplicate',
      () async {
        const sessionId = 'echo-before-rest-1';
        const canonicalLocalId = 'local-echo-1';

        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 9);
        // Optimistic placeholder — same `id` as `localId` (matches the
        // shape produced by `_sync_messaging_send.dart`).
        sync.testSetSessionMessages(sessionId, [
          {
            'id': canonicalLocalId,
            'localId': canonicalLocalId,
            'seq': 0,
            'role': 'user',
            'kind': 'text',
            'createdAt': 1700000000000,
            'content': 'continue',
            'sendStatus': 'sending',
          },
        ]);
        sync.testSetSessionLastSeq(sessionId, 9);

        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );
        sync.testFetchMessagesOverride = (_, __, ___) async {
          return _buildMessagesResponse(<Map<String, dynamic>>[]);
        };

        // 1. Socket echo lands FIRST — server pushed the authoritative
        //    record before the REST POST round-trip completed.
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': _makeEncryptedMessage(
            'srv-msg-1',
            seq: 10,
            content: 'continue',
            role: 'user',
            localId: canonicalLocalId,
          ),
        });

        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Verify the optimistic placeholder has been replaced.
        var msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        final placeholders = msgs!
            .where((m) => m['id'] == canonicalLocalId)
            .toList();
        expect(
          placeholders,
          isEmpty,
          reason:
              'Optimistic placeholder must be replaced by the server '
              'record via localId match, even when the socket echo '
              'arrives before any REST response',
        );
        var serverCopies = msgs
            .where((m) => m['id'] == 'srv-msg-1')
            .toList();
        expect(serverCopies, hasLength(1));
        expect(serverCopies.single['localId'], canonicalLocalId);

        // 2. REST ack arrives LATE carrying the same `localId`. The
        //    merge layer must not create a second logical row.
        sync.testUpsertSessionMessages(sessionId, [
          {
            'id': 'srv-msg-1',
            'localId': canonicalLocalId,
            'seq': 10,
            'role': 'user',
            'kind': 'text',
            'createdAt': 1700000010000,
            'content': 'continue',
            'sendStatus': 'sent',
          },
        ]);

        msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        final byLocalId = msgs!
            .where((m) => m['localId'] == canonicalLocalId)
            .toList();
        expect(
          byLocalId,
          hasLength(1),
          reason:
              'A late REST ack carrying the same localId must merge '
              'into the existing logical message — no duplicate row',
        );
        serverCopies = msgs
            .where((m) => m['id'] == 'srv-msg-1')
            .toList();
        expect(
          serverCopies,
          hasLength(1),
          reason: 'Final state has exactly one message with the '
              'canonical localId',
        );
        expect(serverCopies.single['sendStatus'], 'sent');
      },
    );

    test(
      'socket echo before REST does not collapse a repeated-text '
      'sibling placeholder',
      () async {
        // The user typed "continue" twice. Two optimistic placeholders
        // share text but have distinct localIds. A socket echo for the
        // SECOND must replace ONLY that placeholder, never the first
        // (which would be a text/position-based merge bug).
        const sessionId = 'echo-before-rest-2';
        const firstLocalId = 'local-cont-1';
        const secondLocalId = 'local-cont-2';

        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 9);
        sync.testSetSessionMessages(sessionId, [
          {
            'id': firstLocalId,
            'localId': firstLocalId,
            'seq': 0,
            'role': 'user',
            'kind': 'text',
            'createdAt': 1700000000000,
            'content': 'continue',
            'sendStatus': 'sending',
          },
          {
            'id': secondLocalId,
            'localId': secondLocalId,
            'seq': 0,
            'role': 'user',
            'kind': 'text',
            'createdAt': 1700000001000,
            'content': 'continue',
            'sendStatus': 'sending',
          },
        ]);
        sync.testSetSessionLastSeq(sessionId, 9);

        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );
        sync.testFetchMessagesOverride = (_, __, ___) async {
          return _buildMessagesResponse(<Map<String, dynamic>>[]);
        };

        // Socket echo for the SECOND localId lands first — before any
        // REST POST has returned for either.
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': _makeEncryptedMessage(
            'srv-msg-2',
            seq: 11,
            content: 'continue',
            role: 'user',
            localId: secondLocalId,
          ),
        });

        await Future<void>.delayed(const Duration(milliseconds: 200));

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);

        // First placeholder must remain — never replaced by text or
        // position similarity.
        expect(
          msgs!.where((m) => m['id'] == firstLocalId),
          hasLength(1),
          reason:
              'First placeholder (localId=$firstLocalId) must survive '
              'the socket echo aimed at $secondLocalId',
        );
        // Second placeholder is gone, replaced by the server record.
        expect(
          msgs.where((m) => m['id'] == secondLocalId),
          isEmpty,
          reason:
              'Second placeholder must be replaced by srv-msg-2 via '
              'localId match',
        );
        expect(
          msgs.where((m) => m['id'] == 'srv-msg-2'),
          hasLength(1),
        );

        // Now the REST ack for the SECOND arrives — must not duplicate.
        sync.testUpsertSessionMessages(sessionId, [
          {
            'id': 'srv-msg-2',
            'localId': secondLocalId,
            'seq': 11,
            'role': 'user',
            'kind': 'text',
            'createdAt': 1700000011000,
            'content': 'continue',
            'sendStatus': 'sent',
          },
        ]);

        final after = sync.testSessionMessages(sessionId)!;
        expect(
          after.where((m) => m['id'] == 'srv-msg-2'),
          hasLength(1),
          reason: 'Late REST ack must not duplicate the socket-acked row',
        );
        // Both logical messages (first still sending, second sent) remain.
        expect(after, hasLength(2));
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test helpers (copied from message_deduplication_e2e_test.dart so the test
// is self-contained — do not extract until a shared fixture lib exists).
// ---------------------------------------------------------------------------

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
