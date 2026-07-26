import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

/// Regression: message page fetches must retry.
///
/// The page requests opt out of the Dio [RetryInterceptor] with
/// `disableRetry: true` (a stalled page must not be retried inside its own
/// receive-timeout budget). Every `messagesSync` [InvalidateSync] used to be
/// built with `maxRetries: 0`, so BOTH layers assumed the other one retried
/// and neither did: one transport stall permanently discarded a page and the
/// chat silently showed stale data until an unrelated event fired.
void main() {
  late Sync sync;

  setUp(() {
    sync = createTestSync();
    sync.encryption = _RetryFakeEncryption();
    sync.testIsInitialized = true;
    sync.testSocketConnectedOverride = true;
    sync.testSocketSendOverride = (_, __) {};
  });

  tearDown(() {
    sync.testFetchMessagesOverride = null;
    sync.testSocketConnectedOverride = null;
    sync.testSocketSendOverride = null;
    sync.testClearSessionMessageState('retry-s1');
    sync.testSetVisibleSessionId(null);
    sync.messagesSync.remove('retry-s1')?.dispose();
  });

  test(
    'messagesSync retries a stalled message page instead of discarding it',
    () async {
      const sessionId = 'retry-s1';
      sync.testSetVisibleSessionId(sessionId);
      sync.testSessions[sessionId] = _makeRetrySession(sessionId, lastSeq: 10);
      sync.testSetSessionLastSeq(sessionId, 0);

      var attempts = 0;
      var failNextPage = false;
      sync.testFetchMessagesOverride = (id, afterSeq, limit) async {
        attempts++;
        if (failNextPage) {
          failNextPage = false;
          // Exactly the production failure: a receive timeout on a page the
          // server had already produced.
          throw DioException(
            requestOptions: RequestOptions(path: '/v3/sessions/$id/messages'),
            type: DioExceptionType.receiveTimeout,
          );
        }
        return {'messages': <Map<String, dynamic>>[], 'hasMore': false};
      };

      // onSessionVisible builds the per-session InvalidateSync.
      await sync.onSessionVisible(sessionId);
      final messagesSync = sync.messagesSync[sessionId];
      expect(messagesSync, isNotNull);
      await messagesSync!.awaitQueue();

      attempts = 0;
      failNextPage = true;
      sync.testAddFetchProbe(sessionId);
      messagesSync.invalidate();
      await messagesSync.awaitQueue();

      expect(
        attempts,
        greaterThanOrEqualTo(2),
        reason:
            'a stalled page must be retried by InvalidateSync — the HTTP '
            'layer cannot retry it (disableRetry: true)',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  // The resume batch and the socket-event handler create the SAME per-session
  // instance (all creation sites are guarded by `!containsKey`), so whichever
  // fires first owns it for the session lifetime. If the resume path builds a
  // retry-less instance, onSessionVisible reuses it and the retry fix is
  // silently defeated on the most common path.
  test(
    'messagesSync created by the resume batch also retries a stalled page',
    () async {
      const sessionId = 'retry-s1';
      sync.testSessions[sessionId] = _makeRetrySession(sessionId, lastSeq: 10);
      sync.testSetSessionLastSeq(sessionId, 0);

      var attempts = 0;
      var failNextPage = false;
      sync.testFetchMessagesOverride = (id, afterSeq, limit) async {
        attempts++;
        if (failNextPage) {
          failNextPage = false;
          throw DioException(
            requestOptions: RequestOptions(path: '/v3/sessions/$id/messages'),
            type: DioExceptionType.receiveTimeout,
          );
        }
        return {'messages': <Map<String, dynamic>>[], 'hasMore': false};
      };

      // Build the instance via the resume path, NOT via onSessionVisible.
      sync.testSetPendingSocketMessages({sessionId});
      sync.testScheduleResumeMessageBatch();
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      final messagesSync = sync.messagesSync[sessionId];
      expect(
        messagesSync,
        isNotNull,
        reason: 'the resume batch must have created the per-session sync',
      );
      try {
        await messagesSync!.awaitQueue();
      } on Object {
        // First run outcome is irrelevant here.
      }

      // Now the visible-session path reuses that instance.
      sync.testSetVisibleSessionId(sessionId);
      await sync.onSessionVisible(sessionId);
      expect(identical(sync.messagesSync[sessionId], messagesSync), isTrue);

      attempts = 0;
      failNextPage = true;
      sync.testAddFetchProbe(sessionId);
      messagesSync!.invalidate();
      try {
        await messagesSync.awaitQueue();
      } on Object {
        // The retry itself is what we assert on.
      }

      expect(
        attempts,
        greaterThanOrEqualTo(2),
        reason:
            'the resume-batch instance must use Sync._messagesSyncMaxRetries '
            'too, otherwise a single receive timeout discards the page',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}

Session _makeRetrySession(String id, {required int lastSeq}) {
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

class _RetryFakeEncryption implements Encryption {
  final Map<String, _RetryFakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _RetryFakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RetryFakeSessionEncryption extends SessionEncryption {
  _RetryFakeSessionEncryption({required String sessionId})
    : super(
        sessionId: sessionId,
        encryptor: _RetryFakeEncryptor(),
        decryptor: _RetryFakeEncryptor(),
        cache: EncryptionCache(),
      );
}

class _RetryFakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async =>
      data.map((_) => Uint8List(0)).toList();

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async =>
      data.map((_) => null).toList();
}
