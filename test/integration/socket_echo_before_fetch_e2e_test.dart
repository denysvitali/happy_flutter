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

/// E2E tests for two delivery-ordering gaps the canonical-localId merge
/// contract must withstand (ROADMAP P0, "Out-of-order delivery tests"):
///
///   1. A socket echo arrives BEFORE a fetch returns the same message.
///      A tail/history fetch returns the authoritative server record —
///      possibly WITHOUT the `localId` (older history records do not echo
///      the client id back) — alongside newer sibling messages. The merge
///      must dedupe by server `id` and preserve ordering.
///
///   2. Duplicate-broadcast sequencing: the server re-broadcasts the same
///      `new-message` socket event multiple times (reconnect replay, at-
///      least-once delivery). Against one optimistic placeholder this must
///      collapse to exactly one logical row.
///
/// Like `socket_echo_before_rest_e2e_test.dart`, these inject the socket
/// echo via the real inline path (`handleUpdate` with an encrypted body)
/// and the fetch result via the merge helper (`testUpsertSessionMessages`,
/// which is what `fetchMessages` funnels into after decrypt) so the race
/// ordering is fully deterministic.
void main() {
  group('socket echo before fetch / duplicate broadcast', () {
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
      'socket echo replaces the placeholder, then a fetch page returning '
      'the same message with newer siblings does not duplicate',
      () async {
        const sessionId = 'echo-before-fetch-1';
        const canonicalLocalId = 'local-fetch-1';

        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 9);
        sync.testSetSessionMessages(sessionId, [
          {
            'id': canonicalLocalId,
            'localId': canonicalLocalId,
            'seq': 0,
            'role': 'user',
            'kind': 'text',
            'createdAt': 1700000000000,
            'content': 'run tests',
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

        // 1. Socket echo lands first and carries the localId — the
        //    optimistic placeholder is replaced by the server record.
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': _makeEncryptedMessage(
            'srv-user-1',
            seq: 10,
            content: 'run tests',
            role: 'user',
            localId: canonicalLocalId,
          ),
        });
        await Future<void>.delayed(const Duration(milliseconds: 200));

        var msgs = sync.testSessionMessages(sessionId)!;
        expect(
          msgs.where((m) => m['id'] == canonicalLocalId),
          isEmpty,
          reason: 'placeholder must be replaced by the socket echo',
        );

        // 2. A tail fetch returns the authoritative page: the same user
        //    message (WITHOUT localId, as a history record) plus a newer
        //    agent reply. Dedup must key on the server `id`.
        sync.testUpsertSessionMessages(sessionId, [
          {
            'id': 'srv-user-1',
            'seq': 10,
            'role': 'user',
            'kind': 'text',
            'createdAt': 1700000010000,
            'content': 'run tests',
            'sendStatus': 'sent',
          },
          {
            'id': 'srv-reply-1',
            'seq': 11,
            'role': 'agent',
            'kind': 'text',
            'createdAt': 1700000011000,
            'content': 'tests passed',
          },
        ]);

        msgs = sync.testSessionMessages(sessionId)!;
        expect(
          msgs.where((m) => m['id'] == 'srv-user-1'),
          hasLength(1),
          reason:
              'fetch returning the same server id must merge, not '
              'duplicate, even when it omits the localId',
        );
        // After the server ack the canonical identity is the server `id`,
        // so a history fetch that omits `localId` may drop it — the
        // invariant is one logical row per server id, not localId survival.
        expect(msgs.where((m) => m['id'] == 'srv-reply-1'), hasLength(1));

        // Ordering: the user message precedes its reply (seq ascending).
        final userIdx = msgs.indexWhere((m) => m['id'] == 'srv-user-1');
        final replyIdx = msgs.indexWhere((m) => m['id'] == 'srv-reply-1');
        expect(
          userIdx,
          lessThan(replyIdx),
          reason: 'fetch overlap must preserve seq ordering',
        );
      },
    );

    test(
      'duplicate socket broadcast of the same message collapses to one '
      'row and replaces the optimistic placeholder exactly once',
      () async {
        const sessionId = 'dup-broadcast-1';
        const canonicalLocalId = 'local-dup-1';

        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 9);
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

        // The server re-broadcasts the identical new-message event three
        // times (at-least-once delivery / reconnect replay).
        for (var i = 0; i < 3; i++) {
          sync.handleUpdate({
            't': 'new-message',
            'sid': sessionId,
            'message': _makeEncryptedMessage(
              'srv-dup-1',
              seq: 10,
              content: 'continue',
              role: 'user',
              localId: canonicalLocalId,
            ),
          });
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }

        final msgs = sync.testSessionMessages(sessionId)!;
        expect(
          msgs.where((m) => m['id'] == canonicalLocalId),
          isEmpty,
          reason: 'placeholder replaced once, never resurrected',
        );
        expect(
          msgs.where((m) => m['id'] == 'srv-dup-1'),
          hasLength(1),
          reason: 'duplicate broadcasts of one id must collapse to one row',
        );
        expect(
          msgs.where((m) => m['localId'] == canonicalLocalId),
          hasLength(1),
        );
        expect(msgs, hasLength(1));
      },
    );

    test(
      'duplicate broadcast followed by a fetch overlap still yields one '
      'row',
      () async {
        const sessionId = 'dup-broadcast-then-fetch-1';
        const canonicalLocalId = 'local-dupfetch-1';

        sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 9);
        sync.testSetSessionMessages(sessionId, [
          {
            'id': canonicalLocalId,
            'localId': canonicalLocalId,
            'seq': 0,
            'role': 'user',
            'kind': 'text',
            'createdAt': 1700000000000,
            'content': 'ship it',
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

        // Two identical socket echoes.
        for (var i = 0; i < 2; i++) {
          sync.handleUpdate({
            't': 'new-message',
            'sid': sessionId,
            'message': _makeEncryptedMessage(
              'srv-df-1',
              seq: 10,
              content: 'ship it',
              role: 'user',
              localId: canonicalLocalId,
            ),
          });
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }

        // A later fetch returns the same record once more (history page).
        sync.testUpsertSessionMessages(sessionId, [
          {
            'id': 'srv-df-1',
            'localId': canonicalLocalId,
            'seq': 10,
            'role': 'user',
            'kind': 'text',
            'createdAt': 1700000010000,
            'content': 'ship it',
            'sendStatus': 'sent',
          },
        ]);

        final msgs = sync.testSessionMessages(sessionId)!;
        expect(
          msgs.where((m) => m['id'] == 'srv-df-1'),
          hasLength(1),
          reason: 'broadcast + fetch overlap must collapse to one row',
        );
        expect(msgs, hasLength(1));
        expect(msgs.single['sendStatus'], 'sent');
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test helpers (copied from socket_echo_before_rest_e2e_test.dart so the
// test is self-contained — do not extract until a shared fixture lib exists).
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
