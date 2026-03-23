import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

/// E2E tests for concurrent rapid sendMessage calls.
///
/// Exercises the scenario where the user sends multiple messages quickly
/// on the same session (or across sessions), verifying that:
///   - Optimistic messages appear immediately for every send
///   - All messages eventually complete as 'sent'
///   - Each message receives a unique localId
///   - The server receives every message
///   - Cross-session sends don't interfere with each other

void main() {
  group('concurrent sends on same session', () {
    late Sync sync;
    late _TrackingInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      _stubAllSyncs(sync);
      sync.testSessions.clear();
      sync.testSetSessionMessages('sess-1', []);
      sync.testSessions['sess-1'] = _makeSession('sess-1');
      sync.testSetLastEphemeralAt(
        'sess-1',
        DateTime.now().millisecondsSinceEpoch,
      );
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testFetchMessagesOverride =
          (_, __, ___) async => _emptyMessagesPage;

      interceptor = _TrackingInterceptor();
      await ApiClient().initialize(
        serverUrl: 'http://localhost',
      );
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test(
      '3 rapid sends all create optimistic messages',
      () async {
        const sessionId = 'sess-1';

        // Fire all 3 without awaiting.
        final f1 = sync.sendMessage(sessionId, 'msg A');
        final f2 = sync.sendMessage(sessionId, 'msg B');
        final f3 = sync.sendMessage(sessionId, 'msg C');

        // sendMessage is async: the optimistic insert runs
        // after _resolveSendTargetSession (which yields at
        // least once). Pump microtasks so all three inserts
        // complete before we inspect the message list.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final msgs = sync.testSessionMessages(sessionId);
        expect(
          msgs,
          isNotNull,
          reason:
              'Session messages should exist after sends',
        );
        final optimistic = msgs!
            .where((m) => m['sendStatus'] == 'sending')
            .toList();
        expect(
          optimistic.length,
          3,
          reason:
              'All 3 sends should insert an optimistic '
              'message',
        );

        // Drain futures to avoid dangling async work.
        await Future.wait([f1, f2, f3]);
        await sync.lastCompleteSendFuture;
      },
    );

    test(
      'all concurrent sends eventually complete as sent',
      () async {
        const sessionId = 'sess-1';

        await Future.wait([
          sync.sendMessage(sessionId, 'msg A'),
          sync.sendMessage(sessionId, 'msg B'),
          sync.sendMessage(sessionId, 'msg C'),
        ]);
        await sync.lastCompleteSendFuture;

        final msgs = sync.testSessionMessages(sessionId)!;
        // After background send completes, no message should still be
        // in 'sending' state — they should all be 'sent'.
        final stillSending = msgs
            .where((m) => m['sendStatus'] == 'sending')
            .toList();
        expect(
          stillSending,
          isEmpty,
          reason: 'No message should remain in "sending" state',
        );
        final sent = msgs
            .where((m) => m['sendStatus'] == 'sent')
            .toList();
        expect(
          sent.length,
          greaterThanOrEqualTo(3),
          reason: 'All 3 sends should reach "sent" status',
        );
      },
    );

    test('each send gets a unique localId', () async {
      const sessionId = 'sess-1';

      // Fire without awaiting to capture IDs from the
      // optimistic inserts.
      final f1 = sync.sendMessage(sessionId, 'msg A');
      final f2 = sync.sendMessage(sessionId, 'msg B');
      final f3 = sync.sendMessage(sessionId, 'msg C');

      // Let optimistic inserts complete.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final msgs =
          sync.testSessionMessages(sessionId)!;
      final localIds = msgs
          .map((m) => m['localId'] as String?)
          .where((id) => id != null)
          .toSet();

      expect(
        localIds.length,
        3,
        reason:
            'Each send must produce a distinct localId',
      );

      await Future.wait([f1, f2, f3]);
      await sync.lastCompleteSendFuture;
    });

    test('server receives all messages', () async {
      const sessionId = 'sess-1';

      await Future.wait([
        sync.sendMessage(sessionId, 'msg A'),
        sync.sendMessage(sessionId, 'msg B'),
        sync.sendMessage(sessionId, 'msg C'),
      ]);
      await sync.lastCompleteSendFuture;

      expect(
        interceptor.capturedLocalIds.length,
        3,
        reason: 'Server interceptor should have received 3 distinct localIds',
      );
      final uniqueIds = interceptor.capturedLocalIds.toSet();
      expect(
        uniqueIds.length,
        3,
        reason: 'Each POST must carry a different localId',
      );
    });
  });

  group('concurrent sends across sessions', () {
    late Sync sync;
    late _TrackingInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      _stubAllSyncs(sync);
      sync.testSessions.clear();
      sync.testSetSessionMessages('sess-A', []);
      sync.testSetSessionMessages('sess-B', []);
      sync.testSessions['sess-A'] = _makeSession('sess-A');
      sync.testSessions['sess-B'] = _makeSession('sess-B');
      final now = DateTime.now().millisecondsSinceEpoch;
      sync.testSetLastEphemeralAt('sess-A', now);
      sync.testSetLastEphemeralAt('sess-B', now);
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testFetchMessagesOverride =
          (_, __, ___) async => _emptyMessagesPage;

      interceptor = _TrackingInterceptor();
      await ApiClient().initialize(
        serverUrl: 'http://localhost',
      );
      ApiClient().testDio!.interceptors.add(interceptor);
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test(
      'sends to different sessions don\'t interfere',
      () async {
        // Send to both sessions concurrently.
        await Future.wait([
          sync.sendMessage('sess-A', 'hello from A'),
          sync.sendMessage('sess-B', 'hello from B'),
        ]);
        await sync.lastCompleteSendFuture;

        final msgsA = sync.testSessionMessages('sess-A');
        final msgsB = sync.testSessionMessages('sess-B');

        expect(msgsA, isNotNull, reason: 'sess-A should have messages');
        expect(msgsB, isNotNull, reason: 'sess-B should have messages');

        // Each session should have exactly its own message.
        final sentA = msgsA!
            .where((m) => m['content'] == 'hello from A')
            .toList();
        final sentB = msgsB!
            .where((m) => m['content'] == 'hello from B')
            .toList();
        expect(
          sentA.length,
          greaterThanOrEqualTo(1),
          reason: 'sess-A should contain the A message',
        );
        expect(
          sentB.length,
          greaterThanOrEqualTo(1),
          reason: 'sess-B should contain the B message',
        );

        // Cross-contamination check: A's message should not appear in B.
        final crossA = msgsB
            .where((m) => m['content'] == 'hello from A')
            .toList();
        final crossB = msgsA
            .where((m) => m['content'] == 'hello from B')
            .toList();
        expect(crossA, isEmpty, reason: 'sess-A message must not be in sess-B');
        expect(crossB, isEmpty, reason: 'sess-B message must not be in sess-A');
      },
    );

    test(
      'auto-restore and normal send don\'t block each other',
      () async {
        // sess-offline requires auto-restore (offline, no machineId/path set
        // on metadata → _resolveSendTargetSession falls through immediately
        // since machineId is null, so the send proceeds without spawning).
        // sess-A is online and completes normally.
        sync.testSetSessionMessages('sess-offline', []);
        sync.testSessions['sess-offline'] = _makeSession(
          'sess-offline',
          presence: 'offline',
        );

        final onlineDone = Completer<void>();
        final offlineDone = Completer<void>();

        // Launch both concurrently.
        sync.sendMessage('sess-A', 'online msg').then((_) {
          onlineDone.complete();
        });
        sync.sendMessage('sess-offline', 'offline msg').then((_) {
          offlineDone.complete();
        });

        // The online send should complete independently within a
        // reasonable time even if the offline send takes longer.
        await Future.any([
          onlineDone.future,
          Future<void>.delayed(const Duration(seconds: 5)),
        ]);

        expect(
          onlineDone.isCompleted,
          isTrue,
          reason: 'Online send should complete independently of offline send',
        );

        // Clean up remaining futures.
        await Future.wait([
          onlineDone.future,
          offlineDone.future,
        ]);
        await sync.lastCompleteSendFuture;
      },
    );
  });

  group('rapid fire ordering', () {
    late Sync sync;

    setUp(() async {
      sync = Sync();
      _stubAllSyncs(sync);
      sync.testSessions.clear();
      sync.testSetSessionMessages('sess-1', []);
      sync.testSessions['sess-1'] = _makeSession('sess-1');
      sync.testSetLastEphemeralAt(
        'sess-1',
        DateTime.now().millisecondsSinceEpoch,
      );
      sync.encryption = _FakeEncryption();
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testFetchMessagesOverride =
          (_, __, ___) async => _emptyMessagesPage;

      await ApiClient().initialize(
        serverUrl: 'http://localhost',
      );
      ApiClient().testDio!.interceptors.add(
        _TrackingInterceptor(),
      );
    });

    tearDown(() {
      ApiClient().dispose();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testFetchMessagesOverride = null;
    });

    test(
      'messages maintain insertion order',
      () async {
        const sessionId = 'sess-1';

        // Fire without awaiting.
        final f1 = sync.sendMessage(sessionId, 'msg A');
        final f2 = sync.sendMessage(sessionId, 'msg B');
        final f3 = sync.sendMessage(sessionId, 'msg C');

        // Let optimistic inserts complete.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Capture insertion order after optimistic
        // inserts.
        final msgs =
            sync.testSessionMessages(sessionId)!;
        final optimistic = msgs
            .where(
              (m) =>
                  m['content'] == 'msg A' ||
                  m['content'] == 'msg B' ||
                  m['content'] == 'msg C',
            )
            .toList();

        expect(
          optimistic.length,
          3,
          reason: 'All 3 messages should be present',
        );
        expect(
          optimistic[0]['content'],
          'msg A',
          reason:
              'First inserted message should be msg A',
        );
        expect(
          optimistic[1]['content'],
          'msg B',
          reason:
              'Second inserted message should be msg B',
        );
        expect(
          optimistic[2]['content'],
          'msg C',
          reason:
              'Third inserted message should be msg C',
        );

        await Future.wait([f1, f2, f3]);
        await sync.lastCompleteSendFuture;
      },
    );
  });
}

// ---------------------------------------------------------------------------
// HTTP tracking interceptor
// ---------------------------------------------------------------------------

class _TrackingInterceptor extends Interceptor {
  final List<String> capturedLocalIds = [];
  int _seqCounter = 1;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final isMessagesPath =
        options.path.contains('/v3/sessions/') &&
        options.path.contains('/messages');
    final isPost =
        options.method.toUpperCase() == 'POST';

    // Only intercept POST to the messages endpoint.
    if (isMessagesPath && isPost) {
      final localId = _extractLocalId(options.data);
      if (localId != null) {
        capturedLocalIds.add(localId);
      }
      final seq = _seqCounter++;
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'srv-$seq',
                'seq': seq,
                'localId': localId,
                'createdAt': DateTime.now()
                    .millisecondsSinceEpoch,
              },
            ],
          },
        ),
      );
      return;
    }

    // GET or other requests: return 200 with empty data
    // so fetchMessages doesn't trigger 404 cleanup.
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: <String, dynamic>{
          'messages': <Map<String, dynamic>>[],
          'hasMore': false,
        },
      ),
    );
  }

  String? _extractLocalId(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final msgs = data['messages'] as List<dynamic>?;
    if (msgs == null || msgs.isEmpty) return null;
    final first = msgs.first;
    if (first is! Map<String, dynamic>) return null;
    return first['localId'] as String?;
  }
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
      final jsonStr = jsonEncode(item);
      final bytes = utf8.encode(jsonStr);
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

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Empty response for [Sync.testFetchMessagesOverride] so
/// fetchMessages does not inject extra rows or trigger 404
/// session cleanup.
const _emptyMessagesPage = <String, dynamic>{
  'messages': <Map<String, dynamic>>[],
  'hasMore': false,
};

Session _makeSession(
  String id, {
  String presence = 'online',
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
  );
}

void _stubAllSyncs(
  Sync instance, {
  Future<void> Function()? sessionsFn,
}) {
  instance.sessionsSync =
      InvalidateSync(sessionsFn ?? () async {});
  instance.settingsSync = InvalidateSync(() async {});
  instance.profileSync = InvalidateSync(() async {});
  instance.purchasesSync = InvalidateSync(() async {});
  instance.machinesSync = InvalidateSync(() async {});
  instance.pushTokenSync = InvalidateSync(() async {});
  instance.nativeUpdateSync = InvalidateSync(() async {});
  instance.artifactsSync = InvalidateSync(() async {});
  instance.friendsSync = InvalidateSync(() async {});
  instance.friendRequestsSync = InvalidateSync(() async {});
  instance.feedSync = InvalidateSync(() async {});
  instance.todosSync = InvalidateSync(() async {});
  instance.sessionGitStatusSync = InvalidateSync(() async {});
  instance.messagesSync.clear();
}
