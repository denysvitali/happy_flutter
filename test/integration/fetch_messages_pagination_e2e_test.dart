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

/// E2E tests for fetchMessages pagination.
///
/// Exercises the full pagination pipeline including:
/// - Single page fetch (hasMore=false)
/// - Multi-page pagination (hasMore=true → follow-up pages)
/// - Large-gap tail refresh (offset calculation)
/// - Edge cases (empty response, non-sequential seqs)
void main() {
  // ---------------------------------------------------------------------------
  // Shared helpers
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

  void _clearSyncState(Sync sync) {
    for (final id in sync.sessionMessages.keys.toList()) {
      sync.testSetSessionMessages(id, []);
    }
    for (final id in sync.testSessions.keys.toList()) {
      sync.testSetSessionLastSeq(id, 0);
    }
  }

  // ---------------------------------------------------------------------------
  // Group 1: single page fetch
  // ---------------------------------------------------------------------------

  group('single page fetch', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      _clearSyncState(sync);
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
    });

    test(
      'fetches all messages in single page when hasMore is false',
      () async {
        const sessionId = 'sess-single-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );

        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedMessage('msg-1', seq: 1, content: 'A'),
            _makeEncryptedMessage('msg-2', seq: 2, content: 'B'),
            _makeEncryptedMessage('msg-3', seq: 3, content: 'C'),
            _makeEncryptedMessage('msg-4', seq: 4, content: 'D'),
            _makeEncryptedMessage('msg-5', seq: 5, content: 'E'),
          ]);
        };

        await sync.fetchMessages(sessionId);

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        expect(
          msgs!.length,
          5,
          reason: 'All 5 messages should be present',
        );
      },
    );

    test(
      'cursor advances to max seq after single page fetch',
      () async {
        const sessionId = 'sess-single-2';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );

        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedMessage('msg-1', seq: 1, content: 'A'),
            _makeEncryptedMessage('msg-3', seq: 3, content: 'B'),
            _makeEncryptedMessage('msg-5', seq: 5, content: 'C'),
          ]);
        };

        await sync.fetchMessages(sessionId);

        // After fetching, cursor should be at the max seq returned (5).
        // Verify by confirming a subsequent fetch with cursor==server skips.
        final fetchCalls = <int>[];
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          fetchCalls.add(afterSeq);
          return _buildMessagesResponse([]);
        };

        // Re-set server lastSeq to match where we expect the cursor to be.
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        // Pre-populate messages so isFirstLoad=false.
        sync.testSetSessionMessages(sessionId, [
          {'id': 'x', 'seq': 5, 'role': 'agent'},
        ]);

        await sync.fetchMessages(sessionId);

        expect(
          fetchCalls,
          isEmpty,
          reason:
              'Cursor should be at seq=5 (==server), '
              'so second fetch is skipped',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 2: multi-page pagination
  // ---------------------------------------------------------------------------

  group('multi-page pagination', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      _clearSyncState(sync);
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
      'paginates when hasMore is true',
      () async {
        const sessionId = 'sess-multi-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        // Session must be visible so the page>0 guard does not abort.
        sync.testVisibleSessionId = sessionId;

        var callCount = 0;
        final capturedAfterSeqs = <int>[];

        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          capturedAfterSeqs.add(afterSeq);
          callCount++;
          if (callCount == 1) {
            // First page: seq 1-3, hasMore=true
            return _buildMessagesResponse(
              [
                _makeEncryptedMessage(
                  'msg-1',
                  seq: 1,
                  content: 'Msg1',
                ),
                _makeEncryptedMessage(
                  'msg-2',
                  seq: 2,
                  content: 'Msg2',
                ),
                _makeEncryptedMessage(
                  'msg-3',
                  seq: 3,
                  content: 'Msg3',
                ),
              ],
              hasMore: true,
            );
          }
          // Second page: seq 4-5, hasMore=false
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-4',
              seq: 4,
              content: 'Msg4',
            ),
            _makeEncryptedMessage(
              'msg-5',
              seq: 5,
              content: 'Msg5',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);

        expect(
          callCount,
          2,
          reason: 'fetchMessages should call the override twice',
        );
        expect(
          capturedAfterSeqs.length,
          2,
          reason: 'Should record two afterSeq values',
        );
        // First call starts at the tail position (lastSeq=5 <= 200 → 0).
        expect(
          capturedAfterSeqs[0],
          0,
          reason: 'First page starts at afterSeq=0 (tail load)',
        );
        // Second call starts after the max seq of the first page (3).
        expect(
          capturedAfterSeqs[1],
          3,
          reason: 'Second page starts at afterSeq=3 (max seq of page 1)',
        );
      },
    );

    test(
      'all messages from all pages are present after pagination',
      () async {
        const sessionId = 'sess-multi-2';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        sync.testVisibleSessionId = sessionId;

        var callCount = 0;
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          callCount++;
          if (callCount == 1) {
            return _buildMessagesResponse(
              [
                _makeEncryptedMessage(
                  'msg-1',
                  seq: 1,
                  content: 'Msg1',
                ),
                _makeEncryptedMessage(
                  'msg-2',
                  seq: 2,
                  content: 'Msg2',
                ),
                _makeEncryptedMessage(
                  'msg-3',
                  seq: 3,
                  content: 'Msg3',
                ),
              ],
              hasMore: true,
            );
          }
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-4',
              seq: 4,
              content: 'Msg4',
            ),
            _makeEncryptedMessage(
              'msg-5',
              seq: 5,
              content: 'Msg5',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        expect(
          msgs!.length,
          5,
          reason: 'All 5 messages from both pages should be present',
        );
        final ids = msgs.map((m) => m['id'] as String).toSet();
        for (var i = 1; i <= 5; i++) {
          expect(
            ids.contains('msg-$i'),
            isTrue,
            reason: 'msg-$i should be in the message list',
          );
        }
      },
    );

    test(
      'cursor advances to max seq from last page',
      () async {
        const sessionId = 'sess-multi-3';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        sync.testVisibleSessionId = sessionId;

        var callCount = 0;
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          callCount++;
          if (callCount == 1) {
            return _buildMessagesResponse(
              [
                _makeEncryptedMessage(
                  'msg-1',
                  seq: 1,
                  content: 'Msg1',
                ),
                _makeEncryptedMessage(
                  'msg-3',
                  seq: 3,
                  content: 'Msg3',
                ),
              ],
              hasMore: true,
            );
          }
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-5',
              seq: 5,
              content: 'Msg5',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);

        // After pagination, verify the cursor is at seq=5 by confirming
        // a subsequent fetch with server lastSeq=5 is skipped.
        final followUpCalls = <int>[];
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          followUpCalls.add(afterSeq);
          return _buildMessagesResponse([]);
        };

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        sync.testSetSessionMessages(sessionId, [
          {'id': 'x', 'seq': 5, 'role': 'agent'},
        ]);

        await sync.fetchMessages(sessionId);

        expect(
          followUpCalls,
          isEmpty,
          reason:
              'Cursor should be at seq=5 after full pagination, '
              'so the follow-up fetch is skipped',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 3: large gap pagination
  // ---------------------------------------------------------------------------

  group('large gap pagination', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      _clearSyncState(sync);
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
    });

    test(
      'tail refresh with large gap fetches from correct offset',
      () async {
        // Session with lastSeq=500, cursor at 100.
        // gap = 500 - 100 = 400 > initialLoad(200) → gapTooLarge.
        // Expected afterSeq = lastSeq - initialLoad = 500 - 200 = 300.
        const sessionId = 'sess-gap-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 500,
        );
        sync.testSetSessionLastSeq(sessionId, 100);
        // Pre-populate messages so isFirstLoad=false.
        sync.testSetSessionMessages(sessionId, [
          {'id': 'old-msg', 'seq': 100, 'role': 'agent'},
        ]);

        final capturedAfterSeqs = <int>[];
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          capturedAfterSeqs.add(afterSeq);
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-301',
              seq: 301,
              content: 'Recent',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);

        expect(
          capturedAfterSeqs,
          isNotEmpty,
          reason: 'Should perform a fetch for the large-gap session',
        );
        expect(
          capturedAfterSeqs.first,
          300,
          reason:
              'Gap recovery should start at '
              'lastSeq(500) - initialLoad(200) = 300',
        );
      },
    );

    test(
      'first load fetches from tail position',
      () async {
        // No messages in memory, lastSeq=300.
        // Expected afterSeq = lastSeq - initialLoad = 300 - 200 = 100.
        const sessionId = 'sess-gap-2';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 300,
        );
        // No cursor set, no messages (isFirstLoad=true).

        final capturedAfterSeqs = <int>[];
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          capturedAfterSeqs.add(afterSeq);
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-101',
              seq: 101,
              content: 'Tail message',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);

        expect(
          capturedAfterSeqs,
          isNotEmpty,
          reason: 'Should perform a fetch on first load',
        );
        expect(
          capturedAfterSeqs.first,
          100,
          reason:
              'First load should start at '
              'lastSeq(300) - initialLoad(200) = 100',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 3b: page limit re-trigger
  // ---------------------------------------------------------------------------

  group('page limit re-trigger', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      _clearSyncState(sync);
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
      'invalidates messagesSync after hitting page limit',
      () async {
        const sessionId = 'sess-pagelimit-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10,
        );
        sync.testVisibleSessionId = sessionId;

        // Ensure messagesSync exists for the session so we can
        // track invalidation.
        var invalidateCount = 0;
        sync.messagesSync[sessionId] = InvalidateSync(
          () async {
            invalidateCount++;
          },
        );

        var callCount = 0;
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          callCount++;
          // Always return hasMore=true to trigger page limit.
          return _buildMessagesResponse(
            [
              _makeEncryptedMessage(
                'msg-$callCount',
                seq: callCount,
                content: 'Msg$callCount',
              ),
            ],
            hasMore: true,
          );
        };

        await sync.fetchMessages(sessionId);

        expect(
          callCount,
          12,
          reason: 'Should stop after 12 pages (maxPages)',
        );
        // The messagesSync should have been invalidated so a
        // follow-up cycle is scheduled.
        expect(
          invalidateCount,
          greaterThan(0),
          reason:
              'messagesSync should be invalidated after page '
              'limit so the crawl continues in the next cycle',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Group 4: edge cases
  // ---------------------------------------------------------------------------

  group('edge cases', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      _clearSyncState(sync);
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
    });

    test(
      'empty server response does not crash and cursor unchanged',
      () async {
        const sessionId = 'sess-empty-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 5,
        );
        sync.testSetSessionLastSeq(sessionId, 3);
        sync.testSetSessionMessages(sessionId, [
          {'id': 'msg-1', 'seq': 1, 'role': 'agent'},
          {'id': 'msg-2', 'seq': 3, 'role': 'agent'},
        ]);

        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([]);
        };

        // Should complete without throwing.
        await expectLater(
          sync.fetchMessages(sessionId),
          completes,
          reason: 'Empty server response should not throw',
        );

        // The existing messages should still be intact.
        final msgs = sync.testSessionMessages(sessionId);
        expect(
          msgs,
          isNotNull,
          reason: 'Messages should still exist after empty response',
        );
        expect(
          msgs!.length,
          greaterThanOrEqualTo(2),
          reason: 'Pre-existing messages should be preserved',
        );
      },
    );

    test(
      'server returns messages with non-sequential seqs',
      () async {
        const sessionId = 'sess-nonseq-1';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10,
        );

        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          return _buildMessagesResponse([
            _makeEncryptedMessage(
              'msg-1',
              seq: 1,
              content: 'First',
            ),
            _makeEncryptedMessage(
              'msg-5',
              seq: 5,
              content: 'Fifth',
            ),
            _makeEncryptedMessage(
              'msg-10',
              seq: 10,
              content: 'Tenth',
            ),
          ]);
        };

        await sync.fetchMessages(sessionId);

        final msgs = sync.testSessionMessages(sessionId);
        expect(msgs, isNotNull);
        expect(
          msgs!.length,
          3,
          reason: 'All 3 non-sequential messages should be present',
        );
        final ids = msgs.map((m) => m['id'] as String).toSet();
        expect(ids.contains('msg-1'), isTrue);
        expect(ids.contains('msg-5'), isTrue);
        expect(ids.contains('msg-10'), isTrue);

        // Cursor should be at the max seq (10).
        // Verify with a follow-up fetch that is skipped.
        final followUpCalls = <int>[];
        sync.testFetchMessagesOverride =
            (sid, afterSeq, limit) async {
          followUpCalls.add(afterSeq);
          return _buildMessagesResponse([]);
        };

        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          lastSeq: 10,
        );
        sync.testSetSessionMessages(sessionId, [
          {'id': 'x', 'seq': 10, 'role': 'agent'},
        ]);

        await sync.fetchMessages(sessionId);

        expect(
          followUpCalls,
          isEmpty,
          reason:
              'Cursor should be at seq=10 (max), '
              'so follow-up fetch is skipped',
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
  int lastSeq = 10,
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
    presence: 'offline',
    lastSeq: lastSeq,
  );
}

/// Creates a fake-encrypted agent message in the format expected by Sync.
///
/// Uses the legacy `type: assistant` + string content format so that
/// [processDecryptedMessages] produces a real display-ready message entry
/// (kind: 'text') rather than dropping the message silently.
///
/// The content bytes are encoded as [0x01] + utf8(json) to match
/// [_FakeEncryptor.decrypt].
Map<String, dynamic> _makeEncryptedMessage(
  String id, {
  required int seq,
  required String content,
}) {
  // Wire format the message processor understands:
  // role=agent, content.type=output, data.type=assistant,
  // data.message.content=<string>  (legacy bare-string path).
  final innerContent = {
    'role': 'agent',
    'content': {
      'type': 'output',
      'data': {
        'type': 'assistant',
        'message': {
          'content': content,
        },
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
          results.add(jsonDecode(utf8.decode(item.sublist(1))));
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
