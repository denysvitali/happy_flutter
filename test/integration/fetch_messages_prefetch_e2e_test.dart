import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import 'fake_session_encryption.dart';
import 'mock_sync_server.dart';

/// Contract tests for the fetchMessages HTTP/decrypt pipelining
/// (next-page prefetch).
///
/// Unlike the pagination tests that stub `testFetchMessagesOverride`,
/// these go through the real Dio request path (via MockSyncServer's
/// interceptor) so the speculative prefetch branch is actually
/// exercised.
///
/// Core invariants pinned here:
/// - every page is requested exactly once (no duplicate or skipped
///   pages from the prefetch),
/// - the merged message list contains every message exactly once, in
///   seq order (one logical message per wire message).
void main() {
  late Sync sync;
  late MockSyncServer mockServer;

  setUp(() async {
    sync = Sync()
      ..encryption = _FakeEncryption()
      ..testIsInitialized = true
      ..testSocketConnectedOverride = true
      ..testSocketSendOverride = (_, _) {}
      ..testSessions.clear()
      ..testFetchMessagesOverride = null;
    _stubAllSyncs(sync);

    mockServer = MockSyncServer();
    await mockServer.setUp();
  });

  tearDown(() async {
    sync
      ..testSetVisibleSessionId(null)
      ..testSocketConnectedOverride = null
      ..testSocketSendOverride = null;
    await mockServer.tearDown();
  });

  test(
    'multi-page fetch with prefetch requests each page exactly once '
    'and merges every message exactly once',
    () async {
      const sessionId = 'sess-prefetch-1';
      const lastSeq = 300;
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: lastSeq);
      sync.testSetVisibleSessionId(sessionId);

      // Server caps pages at 100 (smaller than the client limit), so the
      // initial 200-message tail-load needs two pages and the prefetch
      // branch fires for page 1 while page 0 decrypts.
      mockServer.maxMessagePageSize = 100;
      mockServer.stubMessages(sessionId, [
        for (var seq = 1; seq <= lastSeq; seq++)
          _makeEncryptedMessage('msg-$seq', seq: seq, content: 'Message $seq'),
      ]);

      await sync.fetchMessages(sessionId);

      // Tail-load window: afterSeq = lastSeq - initialLoad = 100, so the
      // two pages start at after_seq 100 and 200. Exactly one request
      // per page — the prefetched page must be consumed, not re-fetched.
      expect(mockServer.messageRequestLog, [100, 200]);

      final messages = sync.messagesForSession(sessionId);
      final ids = messages.map((m) => m['id']).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'No duplicate logical messages after pipelined merge',
      );
      final seqs = messages
          .map((m) => m['seq'] as int? ?? 0)
          .where((s) => s > 0)
          .toList();
      expect(seqs, List<int>.generate(200, (i) => 101 + i));
    },
  );

  test(
    'catch-up fetch across three pages keeps cursor continuity '
    'with prefetch active',
    () async {
      const sessionId = 'sess-prefetch-2';
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 100);
      sync.testSetVisibleSessionId(sessionId);

      mockServer.maxMessagePageSize = 50;
      mockServer.stubMessages(sessionId, [
        for (var seq = 1; seq <= 100; seq++)
          _makeEncryptedMessage('msg-$seq', seq: seq, content: 'Message $seq'),
      ]);

      // First load: seq 1..100 (window fits entirely; rounded to 0),
      // paged as 0 → 50 → (no more).
      await sync.fetchMessages(sessionId);
      expect(sync.messagesForSession(sessionId), hasLength(100));
      mockServer.messageRequestLog.clear();

      // New messages arrive: seq 101..220. Catch-up crawl from the
      // established cursor needs three pages (50 + 50 + 20).
      sync.testSessions[sessionId] = _makeSession(sessionId, lastSeq: 220);
      for (var seq = 101; seq <= 220; seq++) {
        mockServer.appendStubbedMessage(
          sessionId,
          _makeEncryptedMessage('msg-$seq', seq: seq, content: 'Message $seq'),
        );
      }

      await sync.fetchMessages(sessionId);

      expect(mockServer.messageRequestLog, [100, 150, 200]);
      final messages = sync.messagesForSession(sessionId);
      final ids = messages.map((m) => m['id']).toList();
      expect(ids.toSet().length, ids.length);
      expect(messages, hasLength(220));
    },
  );
}

void _stubAllSyncs(Sync sync) {
  sync
    ..sessionsSync = InvalidateSync(() async {})
    ..settingsSync = InvalidateSync(() async {})
    ..profileSync = InvalidateSync(() async {})
    ..purchasesSync = InvalidateSync(() async {})
    ..machinesSync = InvalidateSync(() async {})
    ..pushTokenSync = InvalidateSync(() async {})
    ..nativeUpdateSync = InvalidateSync(() async {})
    ..artifactsSync = InvalidateSync(() async {})
    // friendsSync / friendRequestsSync / feedSync / todosSync were
    // consolidated into a single invalidation path on Sync; no
    // first-class setters remain.
    ..sessionGitStatusSync = InvalidateSync(() async {});
}

Session _makeSession(String id, {required int lastSeq}) {
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
    'createdAt': 1700000000000 + seq,
  };
}

class _FakeEncryption implements Encryption {
  final Map<String, FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => FakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  String generateId() => 'test-local-${DateTime.now().microsecondsSinceEpoch}';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
