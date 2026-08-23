import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

/// E2E tests for the message outbox retry flow.
///
/// Exercises the full lifecycle of a failed send:
///   sendMessage → HTTP POST fails → OutboxEntry queued → retried →
///   eventually marked failed (or succeeds on retry).
///
/// Uses a Dio interceptor to control HTTP outcomes without a real server.
void main() {
  // The real exponential-backoff scheduler still drives every attempt;
  // only the wall-clock between attempts is scaled down (1 s/2 s/4 s →
  // 200 ms/400 ms/800 ms). Attempt counts and status transitions are
  // unchanged. The first retry must still land after the 100 ms
  // onSessionMessagesChanged debounce so 'pending' stays observable.
  setUp(() => MessageOutbox.testRetryDelayScale = 0.2);
  tearDown(() => MessageOutbox.testRetryDelayScale = 1.0);

  group('message send failure and status tracking', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late _AlwaysFailInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();
      interceptor = _AlwaysFailInterceptor();

      _stubAllSyncs(sync);
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      // Stub fetchMessages so onSessionVisible doesn't hit the test
      // interceptor and cause unhandled async errors.
      sync.testFetchMessagesOverride = (_, __, ___) async => {
        'messages': <dynamic>[],
        'hasMore': false,
      };
      // Stub fetchMessages so onSessionVisible doesn't hit the fail
      // interceptor and cause unhandled async errors.
      sync.testFetchMessagesOverride = (_, __, ___) async => {
        'messages': <dynamic>[],
        'hasMore': false,
      };
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      sync.testSessions['sess-1'] = _onlineSession('sess-1');
      // Clear stale messages from previous test runs
      // (Sync is a singleton so state persists).
      sync.testSetSessionMessages('sess-1', []);
      // Record a recent ephemeral event so
      // _resolveSendTargetSession trusts the 'online'
      // presence (cross-checks _lastEphemeralAt).
      sync.testSetLastEphemeralAt(
        'sess-1',
        DateTime.now().millisecondsSinceEpoch,
      );

      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);

      // Configure the global outbox so status changes propagate back into
      // sync's session-message state. Mirror what sync.create() does but
      // use a fast-failing deliver so retry timers fire quickly in tests.
      messageOutbox.dispose(); // reset any state from prior test
      // Swap out the real MMKVStorage to avoid native MMKV init failures
      // in CI where the native plugin is unavailable.
      messageOutbox.testStorage = _FakeMMKVStorage();
      messageOutbox.configure(
        // Permanent class → the small 3-attempt budget, so retries
        // exhaust fast in tests (transient would retry for hours).
        deliver: (_) async => OutboxDeliveryFailure.permanent,
        onStatusChanged: (sid, lid, status) {
          _applyOutboxStatus(sync, sid, lid, status);
        },
      );
    });

    tearDown(() {
      ApiClient().dispose();
      messageOutbox.dispose();
      messageOutbox.testStorage = MMKVStorage.testConstructor();
      sync.testFetchMessagesOverride = null;
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
      sync.testFetchSingleSessionOverride = null;
    });

    test(
      'failed HTTP POST marks message as failed after outbox exhausts',
      () async {
        await sync.sendMessage('sess-1', 'Hello from Flutter');
        await sync.lastCompleteSendFuture;

        // After _completeSend throws, the message is queued in the outbox
        // with 'pending' status. Wait for all retries to exhaust
        // (backoff 1 s, 2 s, 4 s — scaled by testRetryDelayScale).
        await _waitUntil(
          () => _firstSendStatus(sync, 'sess-1') == 'failed',
          reason:
              'Message should be marked failed after '
              'outbox exhausts all retries',
        );

        final msgs = sync.testSessionMessages('sess-1');
        expect(msgs, isNotNull);
        expect(msgs!, isNotEmpty);
        final msg = msgs.first;
        expect(
          msg['sendStatus'],
          'failed',
          reason:
              'Message should be marked failed after '
              'outbox exhausts all retries',
        );
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test('optimistic message remains in list after failure', () async {
      await sync.sendMessage('sess-1', 'Persist me');
      await sync.lastCompleteSendFuture;

      // Even though the send failed, the message must stay visible so
      // the user can see what happened.
      final msgs = sync.testSessionMessages('sess-1');
      expect(
        msgs,
        isNotNull,
        reason: 'Session messages list must still exist after failure',
      );
      expect(
        msgs!,
        isNotEmpty,
        reason:
            'Optimistic message must not be removed '
            'on send failure',
      );
    });

    test('message status transitions: sending → pending (→ failed)', () async {
      final statuses = <String>[];

      // Watch the stream for outbox-driven status
      // changes. The listener reads current state, so
      // fast transitions may be collapsed.
      final sub = sync.onSessionMessagesChanged.listen((_) {
        final msgs = sync.testSessionMessages('sess-1');
        if (msgs == null || msgs.isEmpty) return;
        final status = msgs.first['sendStatus'] as String?;
        if (status != null && (statuses.isEmpty || statuses.last != status)) {
          statuses.add(status);
        }
      });

      await sync.sendMessage('sess-1', 'Status test');

      // The optimistic insert sets 'sending' in-memory
      // before _completeSend runs. Read the status
      // directly — the stream listener is async and may
      // not have fired yet.
      final msgsAfterSend = sync.testSessionMessages('sess-1');
      expect(
        msgsAfterSend,
        isNotNull,
        reason: 'Messages must exist after send',
      );
      expect(
        msgsAfterSend!.first['sendStatus'],
        'sending',
        reason:
            'Message should be optimistically '
            'inserted as sending',
      );

      await sync.lastCompleteSendFuture;

      // After _completeSend fails, the outbox fires
      // 'pending' via its onStatusChanged callback.
      await _waitUntil(
        () => statuses.contains('pending'),
        reason: 'Outbox should fire pending after initial send failure',
      );
      expect(
        statuses,
        contains('pending'),
        reason:
            'Outbox should update status to pending '
            'after initial send failure',
      );

      await sub.cancel();
    });
  });

  group('send success flow', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late _AlwaysSucceedInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();
      interceptor = _AlwaysSucceedInterceptor();

      _stubAllSyncs(sync);
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      // Stub fetchMessages so onSessionVisible doesn't hit the test
      // interceptor and cause unhandled async errors.
      sync.testFetchMessagesOverride = (_, __, ___) async => {
        'messages': <dynamic>[],
        'hasMore': false,
      };
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      sync.testSessions['sess-2'] = _onlineSession('sess-2');
      sync.testSetSessionMessages('sess-2', []);
      sync.testSetLastEphemeralAt(
        'sess-2',
        DateTime.now().millisecondsSinceEpoch,
      );

      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);

      messageOutbox.dispose();
      messageOutbox.configure(
        deliver: (_) async => null,
        onStatusChanged: (sid, lid, status) {
          _applyOutboxStatus(sync, sid, lid, status);
        },
      );
    });

    tearDown(() {
      ApiClient().dispose();
      messageOutbox.dispose();
      messageOutbox.testStorage = MMKVStorage.testConstructor();
      sync.testFetchMessagesOverride = null;
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
      sync.testFetchSingleSessionOverride = null;
    });

    test('successful HTTP POST marks message as sent', () async {
      await sync.sendMessage('sess-2', 'Hello success');
      await sync.lastCompleteSendFuture;

      // Allow any async notifications to settle.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final msgs = sync.testSessionMessages('sess-2');
      expect(msgs, isNotNull);
      expect(msgs!, isNotEmpty);
      expect(
        msgs.first['sendStatus'],
        'sent',
        reason: 'Message should be marked sent after successful POST',
      );
    });

    test('successful send merges server fields (id, seq, createdAt)', () async {
      await sync.sendMessage('sess-2', 'Merge server fields');
      await sync.lastCompleteSendFuture;

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final msgs = sync.testSessionMessages('sess-2');
      expect(msgs, isNotNull);
      expect(msgs!, isNotEmpty);

      final msg = msgs.first;
      // Server-assigned id should replace the local placeholder id.
      expect(
        msg['id'],
        startsWith('srv-'),
        reason: 'Server-assigned id must replace local placeholder',
      );
      // seq and createdAt come from the server response.
      expect(
        msg['seq'],
        greaterThan(0),
        reason: 'Server-assigned seq must be set on the message',
      );
      expect(
        msg['createdAt'],
        isA<int>(),
        reason: 'Server-assigned createdAt must be present',
      );
      expect(msg['sendStatus'], 'sent');
    });

    test('outbox defers delivery while a spawned agent is starting', () async {
      sync.testSessions['sess-2'] = _coldStartingSession('sess-2');
      final failure = await sync.testDeliverOutboxEntryClassified(
        const OutboxEntry(
          localId: 'starting-local-id',
          sessionId: 'sess-2',
          text: 'wait for readiness',
          encryptedContent: 'encrypted',
          rawRecord: <String, dynamic>{'role': 'user'},
          queuedAt: 1,
        ),
      );

      expect(failure?.failureClass, OutboxFailureClass.transient);
      expect(failure?.reason, 'agent_starting');
      expect(interceptor.callCount, 0);
    });
  });

  group('retry after failure', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late _FailThenSucceedInterceptor interceptor;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();
      interceptor = _FailThenSucceedInterceptor(failUntil: 1);

      _stubAllSyncs(sync);
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      // Stub fetchMessages so onSessionVisible doesn't hit the test
      // interceptor and cause unhandled async errors.
      sync.testFetchMessagesOverride = (_, __, ___) async => {
        'messages': <dynamic>[],
        'hasMore': false,
      };
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      sync.testSessions['sess-3'] = _onlineSession('sess-3');
      sync.testSetSessionMessages('sess-3', []);
      sync.testSetLastEphemeralAt(
        'sess-3',
        DateTime.now().millisecondsSinceEpoch,
      );

      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(interceptor);

      messageOutbox.dispose();
      // Track outbox delivery attempts so the first one fails
      // (matching the interceptor) while subsequent ones succeed.
      var outboxDeliverCount = 0;
      messageOutbox.configure(
        deliver: (entry) async {
          outboxDeliverCount++;
          // Fail the first outbox delivery to keep the message
          // in 'pending' state after the initial HTTP POST fails.
          return outboxDeliverCount > 1
              ? null
              : OutboxDeliveryFailure.transient;
        },
        onStatusChanged: (sid, lid, status) {
          _applyOutboxStatus(sync, sid, lid, status);
        },
      );
    });

    tearDown(() {
      ApiClient().dispose();
      messageOutbox.dispose();
      messageOutbox.testStorage = MMKVStorage.testConstructor();
      sync.testFetchMessagesOverride = null;
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
      sync.testFetchSingleSessionOverride = null;
    });

    test('second manual send succeeds after initial failure', () async {
      // First call fails (interceptor rejects first request).
      await sync.sendMessage('sess-3', 'First attempt');
      await sync.lastCompleteSendFuture;

      // Allow async outbox status callbacks to settle: the failed send
      // enqueues its entry (unawaited) after the complete-send future.
      await _waitUntil(
        () => _firstSendStatus(sync, 'sess-3') == 'pending',
        reason: 'failed send should be queued in the outbox as pending',
      );

      // Verify that the first send failed and the message
      // is queued.
      final msgsAfterFail = sync.testSessionMessages('sess-3');
      expect(
        msgsAfterFail,
        isNotNull,
        reason:
            'Message must still be present after '
            'initial failure',
      );
      // sendStatus should be 'sending' (before outbox fires)
      // or 'pending' (after outbox queues it).
      final statusAfterFail = msgsAfterFail!.first['sendStatus'] as String?;
      expect(
        statusAfterFail,
        anyOf('sending', 'pending'),
        reason:
            'After first failure message should be '
            'sending or pending, not yet failed',
      );

      // Now the interceptor will succeed on subsequent calls.
      // Send a second message — this one goes through.
      await sync.sendMessage('sess-3', 'Second attempt');
      await sync.lastCompleteSendFuture;

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final msgsAfterSuccess = sync.testSessionMessages('sess-3');
      expect(msgsAfterSuccess, isNotNull);
      expect(msgsAfterSuccess!, isNotEmpty);

      // The most recently added message should be sent.
      final lastMsg = msgsAfterSuccess.last;
      expect(
        lastMsg['sendStatus'],
        'sent',
        reason:
            'Second message should succeed after '
            'interceptor no longer rejects',
      );
    });

    test('manual retry keeps the canonical localId and does not create a '
        'second logical message', () async {
      await sync.sendMessage('sess-3', 'Retry me');
      await sync.lastCompleteSendFuture;
      await _waitUntil(
        () => _firstSendStatus(sync, 'sess-3') == 'pending',
        reason: 'failed send should be queued in the outbox as pending',
      );

      final failedMsgs = sync.testSessionMessages('sess-3');
      expect(failedMsgs, isNotNull);
      expect(failedMsgs!, hasLength(1));

      final originalLocalId = failedMsgs.first['localId'] as String?;
      expect(originalLocalId, isNotNull);
      expect(messageOutbox.contains(originalLocalId!), isTrue);

      await messageOutbox.remove(originalLocalId);
      _applyOutboxStatus(sync, 'sess-3', originalLocalId, 'failed');

      messageOutbox.configure(
        deliver: sync.testDeliverOutboxEntryClassified,
        onStatusChanged: (sid, lid, status) {
          _applyOutboxStatus(sync, sid, lid, status);
        },
      );

      final retryResult = await sync.retryFailedMessage(
        'sess-3',
        originalLocalId,
      );
      expect(retryResult.outcome, MessageRetryOutcome.queued);
      // The queued retry fires after one (scaled) backoff delay.
      await _waitUntil(
        () => _firstSendStatus(sync, 'sess-3') == 'sent',
        reason: 'queued retry should deliver after the backoff delay',
      );

      final msgsAfterRetry = sync.testSessionMessages('sess-3');
      expect(msgsAfterRetry, isNotNull);
      expect(
        msgsAfterRetry!,
        hasLength(1),
        reason:
            'Retrying an existing failed message must not create a '
            'second logical message',
      );

      final retried = msgsAfterRetry.single;
      expect(retried['localId'], originalLocalId);
      expect(
        retried['id'],
        startsWith('srv-'),
        reason: 'Successful retry should merge the server-assigned id',
      );
      expect(retried['sendStatus'], 'sent');
      expect(
        interceptor.capturedLocalIds,
        [originalLocalId, originalLocalId],
        reason:
            'Initial POST and explicit retry must both use the same '
            'canonical localId',
      );
    });

    test(
      'retry returns actionable typed outcomes for unavailable payloads',
      () async {
        sync.testSetSessionMessages('sess-3', [
          <String, dynamic>{
            'id': 'missing-raw',
            'localId': 'missing-raw',
            'role': 'user',
            'content': 'continue',
            'sendStatus': 'failed',
          },
          <String, dynamic>{
            'id': 'stripped-image',
            'localId': 'stripped-image',
            'role': 'user',
            'content': '[image]',
            'sendStatus': 'failed',
            'raw': <String, dynamic>{
              'role': 'user',
              'content': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'image',
                  'source': <String, dynamic>{
                    'type': 'base64',
                    'data': '',
                    'omitted': true,
                  },
                },
              ],
            },
          },
        ]);

        final missingMessage = await sync.retryFailedMessage(
          'sess-3',
          'does-not-exist',
        );
        final missingRaw = await sync.retryFailedMessage(
          'sess-3',
          'missing-raw',
        );
        final strippedImage = await sync.retryFailedMessage(
          'sess-3',
          'stripped-image',
        );

        expect(missingMessage.outcome, MessageRetryOutcome.messageNotFound);
        expect(missingRaw.outcome, MessageRetryOutcome.rawDataUnavailable);
        expect(
          strippedImage.outcome,
          MessageRetryOutcome.attachmentDataUnavailable,
        );
        expect(
          sync
              .testSessionMessages('sess-3')!
              .where((m) => m['localId'] == 'stripped-image')
              .single['sendStatus'],
          'failed',
        );
      },
    );

    test('a fresh resend after failure creates a new localId and preserves '
        'the original failed message', () async {
      await sync.sendMessage('sess-3', 'continue');
      await sync.lastCompleteSendFuture;
      await _waitUntil(
        () => _firstSendStatus(sync, 'sess-3') == 'pending',
        reason: 'failed send should be queued in the outbox as pending',
      );

      final msgsAfterFail = sync.testSessionMessages('sess-3');
      expect(msgsAfterFail, isNotNull);
      expect(msgsAfterFail!, hasLength(1));

      final failedLocalId = msgsAfterFail.first['localId'] as String?;
      expect(failedLocalId, isNotNull);
      expect(messageOutbox.contains(failedLocalId!), isTrue);

      await messageOutbox.remove(failedLocalId);
      _applyOutboxStatus(sync, 'sess-3', failedLocalId, 'failed');

      await sync.sendMessage('sess-3', 'continue');
      await sync.lastCompleteSendFuture;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final msgsAfterResend = sync.testSessionMessages('sess-3');
      expect(msgsAfterResend, isNotNull);
      expect(
        msgsAfterResend!,
        hasLength(2),
        reason:
            'An explicit resend is a new user action and must produce '
            'a second logical message',
      );

      final failedCopies = msgsAfterResend
          .where((m) => m['localId'] == failedLocalId)
          .toList();
      expect(failedCopies, hasLength(1));
      expect(failedCopies.single['sendStatus'], 'failed');

      final sentCopies = msgsAfterResend
          .where((m) => m['localId'] != failedLocalId)
          .toList();
      expect(sentCopies, hasLength(1));
      expect(
        sentCopies.single['localId'],
        isNot(failedLocalId),
        reason: 'A fresh resend must mint a new localId',
      );
      expect(sentCopies.single['sendStatus'], 'sent');
      expect(sentCopies.single['content'], 'continue');
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Polls [condition] every 5 ms until it holds, failing with [reason] if it
/// has not within [timeout]. Replaces fixed "let it settle" sleeps so the
/// test resumes the moment the awaited state is reached.
Future<void> _waitUntil(
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('$reason (not observed within $timeout)');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

String? _firstSendStatus(Sync sync, String sessionId) {
  final msgs = sync.testSessionMessages(sessionId);
  if (msgs == null || msgs.isEmpty) return null;
  return msgs.first['sendStatus'] as String?;
}

/// Stub all 13 InvalidateSync fields to no-ops.
void _stubAllSyncs(Sync instance) {
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

/// Create an online session with minimal required fields.
Session _onlineSession(String id) => Session(
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
);

Session _coldStartingSession(String id) => Session(
  id: id,
  seq: 0,
  createdAt: 1700000000000,
  updatedAt: 1700000000000,
  active: true,
  activeAt: 1700000000000,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: false,
  presence: 'offline',
  lifecycleStateCleartext: 'starting',
  metadata: const Metadata(lifecycleState: 'starting'),
);

/// Apply an outbox status change directly into sync's in-memory messages.
///
/// Mirrors what [messageOutbox.configure(onStatusChanged: ...)] does in
/// production via [Sync._updateMessageSendStatus].
void _applyOutboxStatus(
  Sync sync,
  String sessionId,
  String localId,
  String status,
) {
  final msgs = sync.testSessionMessages(sessionId);
  if (msgs == null) return;
  final updated = msgs.map((m) {
    if (m['localId'] == localId || m['id'] == localId) {
      return <String, dynamic>{...m, 'sendStatus': status};
    }
    return m;
  }).toList();
  sync.testSetSessionMessages(sessionId, updated);
}

// ---------------------------------------------------------------------------
// Dio interceptors
// ---------------------------------------------------------------------------

/// Always rejects POST to the messages endpoint with a connection timeout.
class _AlwaysFailInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isMessagesEndpoint(options.path)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          message: 'Simulated connection timeout',
        ),
      );
      return;
    }
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
        data: <String, dynamic>{},
      ),
    );
  }
}

/// Always resolves POST to the messages endpoint with a 200 OK.
class _AlwaysSucceedInterceptor extends Interceptor {
  int _callCount = 0;

  int get callCount => _callCount;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isMessagesEndpoint(options.path)) {
      _callCount++;
      final localId = _extractLocalId(options.data);
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'srv-$_callCount',
                'seq': _callCount,
                'localId': localId,
                'createdAt': DateTime.now().millisecondsSinceEpoch,
              },
            ],
          },
        ),
      );
      return;
    }
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
        data: <String, dynamic>{},
      ),
    );
  }
}

/// Rejects the first [failUntil] calls to the messages endpoint, then
/// resolves subsequent calls with a 200 OK.
class _FailThenSucceedInterceptor extends Interceptor {
  _FailThenSucceedInterceptor({this.failUntil = 1});

  final int failUntil;
  int _postCount = 0;
  final List<String?> capturedLocalIds = <String?>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_isMessagesEndpoint(options.path)) {
      // Only count POSTs (actual sends), not GETs (fetches).
      final isPost = options.method.toUpperCase() == 'POST';
      if (isPost) _postCount++;
      final localId = _extractLocalId(options.data);
      if (isPost) {
        capturedLocalIds.add(localId);
      }
      if (isPost && _postCount <= failUntil) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
            message: 'Simulated failure #$_postCount',
          ),
        );
        return;
      }
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'srv-$_postCount',
                'seq': _postCount,
                'localId': localId,
                'createdAt': DateTime.now().millisecondsSinceEpoch,
              },
            ],
          },
        ),
      );
      return;
    }
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
        data: <String, dynamic>{},
      ),
    );
  }
}

bool _isMessagesEndpoint(String path) =>
    path.contains('/v3/sessions/') && path.contains('/messages');

String? _extractLocalId(dynamic data) {
  if (data is! Map<String, dynamic>) return null;
  final msgs = data['messages'];
  if (msgs is! List<dynamic> || msgs.isEmpty) return null;
  final first = msgs.first;
  if (first is! Map<String, dynamic>) return null;
  return first['localId'] as String?;
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
  String generateId() => 'test-local-${DateTime.now().microsecondsSinceEpoch}';

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
        if (item[0] == 0x01) {
          return jsonDecode(utf8.decode(item.sublist(1)));
        }
        return utf8.decode(item);
      } catch (_) {
        return null;
      }
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Fake MMKV storage for CI (native plugin unavailable)
// ---------------------------------------------------------------------------

class _FakeMMKVStorage extends MMKVStorage {
  _FakeMMKVStorage() : super.testConstructor();

  String? _outboxData;

  @override
  Future<String?> getOutboxEntries() async => _outboxData;

  @override
  Future<void> saveOutboxEntries(String json) async {
    _outboxData = json;
  }
}
