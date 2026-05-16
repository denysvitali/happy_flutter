// E2E test: tool result arrives via one path before its tool-call
// arrives via another. The pending-tool-results queue must preserve
// unmatched results until the matching tool-call appears.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

void main() {
  group('cross-path tool result preservation', () {
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
      'tool result via socket preserved when tool-call arrives '
      'via later HTTP fetch',
      () async {
        const sessionId = 'cross-tool-1';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 0,
        );
        sync.testSetSessionMessages(sessionId, []);
        sync.testSetSessionLastSeq(sessionId, 0);

        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        // Step 1: tool result arrives via socket inline message
        // before the tool-call exists in the message list.
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': _makeEncryptedToolResult(
            'msg-result-1',
            seq: 1,
            toolUseId: 'tu-cross-1',
            result: 'file contents here',
          ),
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        // The tool result is queued as pending — no messages in list yet.
        final pending = sync.testPendingToolResults(sessionId);
        expect(pending, isNotEmpty,
            reason: 'tool result should be queued as pending');
        expect(pending.first['toolUseId'], 'tu-cross-1');

        // Step 2: HTTP fetch returns the tool-call message that matches.
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedToolCall(
              'msg-tool-1',
              seq: 2,
              toolUseId: 'tu-cross-1',
              toolName: 'Read',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);
        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        // The tool-call should be completed, not still running.
        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        final toolCall = msgs!.firstWhere(
            (m) => m['toolUseId'] == 'tu-cross-1');
        expect(toolCall['state'], 'completed',
            reason: 'pending tool result should have been applied '
                'when the tool-call arrived via fetch');
        expect(toolCall['result'], 'file contents here');

        // Pending queue should be drained for the matched ID.
        final pendingAfter =
            sync.testPendingToolResults(sessionId);
        expect(
          pendingAfter.where(
              (r) => r['toolUseId'] == 'tu-cross-1'),
          isEmpty,
          reason: 'matched result should be removed from pending',
        );
      },
    );

    test(
      'unmatched tool result survives a fetch that does not contain '
      'its tool-call',
      () async {
        const sessionId = 'cross-tool-2';

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 0,
        );
        sync.testSetSessionMessages(sessionId, []);
        sync.testSetSessionLastSeq(sessionId, 0);

        sync.testVisibleSessionId = sessionId;
        sync.messagesSync[sessionId] = InvalidateSync(
          () => sync.fetchMessages(sessionId),
        );

        // Enqueue two tool results via socket.
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': _makeEncryptedToolResult(
            'msg-result-a',
            seq: 1,
            toolUseId: 'tu-a',
            result: 'result a',
          ),
        });
        sync.handleUpdate({
          't': 'new-message',
          'sid': sessionId,
          'message': _makeEncryptedToolResult(
            'msg-result-b',
            seq: 2,
            toolUseId: 'tu-b',
            result: 'result b',
          ),
        });

        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        // Fetch returns only the tool-call for tu-a.
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedToolCall(
              'msg-tool-a',
              seq: 3,
              toolUseId: 'tu-a',
              toolName: 'Read',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);
        await Future<void>.delayed(
          const Duration(milliseconds: 200),
        );

        // tu-a should be completed.
        final msgs = sync.testSessionMessages(sessionId)!;
        final toolA = msgs.firstWhere(
            (m) => m['toolUseId'] == 'tu-a');
        expect(toolA['state'], 'completed');

        // tu-b should still be pending (not lost).
        final pendingAfter =
            sync.testPendingToolResults(sessionId);
        final pendingB = pendingAfter.where(
            (r) => r['toolUseId'] == 'tu-b');
        expect(pendingB, isNotEmpty,
            reason: 'tu-b result should survive the fetch that '
                'did not contain its tool-call');
      },
    );
  });
}

// ── Helpers ──────────────────────────────────────────

void _stubAllSyncs(Sync sync) {
  sync.sessionsSync = InvalidateSync(() async {});
  sync.settingsSync = InvalidateSync(() async {});
  sync.profileSync = InvalidateSync(() async {});
  sync.purchasesSync = InvalidateSync(() async {});
  sync.machinesSync = InvalidateSync(() async {});
  sync.pushTokenSync = InvalidateSync(() async {});
  sync.nativeUpdateSync = InvalidateSync(() async {});
  sync.artifactsSync = InvalidateSync(() async {});
  sync.sessionGitStatusSync = InvalidateSync(() async {});
}

Session _makeSession(String id, {int lastSeq = 0}) {
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
    presence: 'online',
    lastSeq: lastSeq,
  );
}

Map<String, dynamic> _makeEncryptedToolResult(
  String id, {
  required int seq,
  required String toolUseId,
  required String result,
}) {
  final plaintext = jsonEncode({
    'role': 'agent',
    'content': {
      'type': 'output',
      'data': {
        'type': 'user',
        'message': {
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': toolUseId,
              'content': result,
              'is_error': false,
            },
          ],
        },
      },
    },
  });
  final bytes = Uint8List.fromList([0x01, ...utf8.encode(plaintext)]);
  final b64 = base64Encode(bytes);
  return {
    'id': id,
    'seq': seq,
    'createdAt': 1700000000000 + seq * 1000,
    'content': {'t': 'encrypted', 'c': b64},
  };
}

Map<String, dynamic> _makeEncryptedToolCall(
  String id, {
  required int seq,
  required String toolUseId,
  required String toolName,
}) {
  final plaintext = jsonEncode({
    'role': 'agent',
    'content': {
      'type': 'output',
      'data': {
        'type': 'assistant',
        'uuid': 'uuid-$id',
        'message': {
          'content': [
            {
              'type': 'tool_use',
              'id': toolUseId,
              'name': toolName,
              'input': {'path': '/test'},
            },
          ],
        },
      },
    },
  });
  final bytes = Uint8List.fromList([0x01, ...utf8.encode(plaintext)]);
  final b64 = base64Encode(bytes);
  return {
    'id': id,
    'seq': seq,
    'createdAt': 1700000000000 + seq * 1000,
    'content': {'t': 'encrypted', 'c': b64},
  };
}

Map<String, dynamic> _buildMessagesResponse(
  List<Map<String, dynamic>> messages,
) {
  return {'messages': messages, 'hasMore': false};
}

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
