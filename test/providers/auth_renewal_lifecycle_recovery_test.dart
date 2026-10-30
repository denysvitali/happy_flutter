import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/storage_service.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/token_refresh_manager.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_helpers.dart';

class _OutboxStorage extends MMKVStorage {
  _OutboxStorage() : super.testConstructor();
  @override
  Future<String?> getOutboxEntries() async => null;
  @override
  Future<void> saveOutboxEntries(String value) async {}
}

class _Encryption implements Encryption {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _token(DateTime expiry) {
  final payload = base64UrlEncode(
    utf8.encode(
      jsonEncode({
        'user': 'account',
        'sub': 'account',
        'iss': 'handy',
        'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      }),
    ),
  ).replaceAll('=', '');
  return 'header.$payload.signature';
}

void main() {
  testWidgets(
    'rejected lifecycle resumes preserve outbox until renewal recovers',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final credentials = AuthCredentials(
        token: _token(DateTime.now().add(const Duration(days: 2))),
        secret: base64Encode(List<int>.filled(32, 7)),
      );
      await TokenStorage().setCredentials(credentials);
      final runtime = createTestSync()
        ..credentials = credentials
        ..encryption = _Encryption()
        ..testIsInitialized = true
        ..testResetLastResumeAtMs();
      final api = ApiClient();
      await api.initialize(serverUrl: 'https://example.test');
      api.updateToken(credentials.token);
      var validResponse = false;
      var serverRejects = false;
      Completer<void>? renewalStarted;
      Completer<void>? renewalRelease;
      api.testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path == '/v1/auth/refresh' && renewalRelease != null) {
              renewalStarted!.complete();
              await renewalRelease.future;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: serverRejects ? 401 : 200,
                data: {
                  'token': validResponse
                      ? _token(DateTime.now().add(const Duration(days: 30)))
                      : 'malformed',
                },
              ),
            );
          },
        ),
      );
      var deliveries = 0;
      messageOutbox
        ..testStorage = _OutboxStorage()
        ..configure(
          deliver: (_) async {
            deliveries++;
            return null;
          },
          ownerScope: 'account',
        );
      await messageOutbox.restoreAndFlush();
      messageOutbox.testInsertPending(
        OutboxEntry(
          localId: 'retained-send',
          sessionId: 'session',
          text: 'retained',
          encryptedContent: 'encrypted',
          rawRecord: const {},
          queuedAt: 1,
        ),
      );
      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await runtime.shutdown();
        runtime.setAuthenticationBlocked(false);
        InvalidateSync.isBackgrounded = false;
        messageOutbox.dispose();
        api
          ..clearToken()
          ..dispose();
        await TokenStorage().removeCredentials();
        tokenRefreshManager.reset();
      });
      final notifier = container.read(authStateNotifierProvider.notifier);

      // An invalid renewal response keeps the runtime's pending sends.
      await notifier.checkAuth(showProgress: false);
      expect(container.read(authStateNotifierProvider), AuthState.error);
      expect(messageOutbox.contains('retained-send'), isTrue);

      // Both foreground and connectivity restoration enter Sync.resume().
      runtime
        ..resume()
        ..resume();
      await tester.pump(const Duration(seconds: 2));
      expect(InvalidateSync.isBackgrounded, isTrue);
      expect(deliveries, 0);
      expect(messageOutbox.contains('retained-send'), isTrue);

      // This failure did not set requiresVerification: recovery must still
      // resume pending sends after a valid same-account bearer is committed.
      validResponse = true;
      await notifier.checkAuth(showProgress: false);
      expect(
        container.read(authStateNotifierProvider),
        AuthState.authenticated,
      );
      expect(InvalidateSync.isBackgrounded, isFalse);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(deliveries, 1);
      expect(messageOutbox.contains('retained-send'), isFalse);

      // A real server rejection must remain blocked over foreground resumes.
      messageOutbox.testInsertPending(
        OutboxEntry(
          localId: 'after-rejection',
          sessionId: 'session',
          text: 'retained',
          encryptedContent: 'encrypted',
          rawRecord: const {},
          queuedAt: 2,
        ),
      );
      serverRejects = true;
      tokenRefreshManager.notifyReauthRequired();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        if (container.read(authStateNotifierProvider) == AuthState.error) break;
      }
      expect(container.read(authStateNotifierProvider), AuthState.error);
      runtime.resume();
      await tester.pump(const Duration(seconds: 2));
      expect(InvalidateSync.isBackgrounded, isTrue);
      expect(deliveries, 1);
      expect(messageOutbox.contains('after-rejection'), isTrue);

      serverRejects = false;
      await notifier.checkAuth(showProgress: false);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(
        container.read(authStateNotifierProvider),
        AuthState.authenticated,
      );
      expect(InvalidateSync.isBackgrounded, isFalse);
      expect(deliveries, 2);
      expect(messageOutbox.contains('after-rejection'), isFalse);

      // An already-started renewal may finish after the OS backgrounds us.
      final expiring = AuthCredentials(
        token: _token(DateTime.now().add(const Duration(days: 2))),
        secret: credentials.secret,
      );
      await TokenStorage().setCredentials(expiring);
      runtime.credentials = expiring;
      api.updateToken(expiring.token);
      messageOutbox.testInsertPending(
        OutboxEntry(
          localId: 'background-renewal',
          sessionId: 'session',
          text: 'retained',
          encryptedContent: 'encrypted',
          rawRecord: const {},
          queuedAt: 3,
        ),
      );
      renewalStarted = Completer<void>();
      renewalRelease = Completer<void>();
      final pendingCheck = notifier.checkAuth(showProgress: false);
      await renewalStarted.future;
      runtime.suspend();
      renewalRelease.complete();
      await pendingCheck;
      await tester.pump(const Duration(seconds: 2));
      expect(
        container.read(authStateNotifierProvider),
        AuthState.authenticated,
      );
      expect(runtime.isLifecycleSuspended, isTrue);
      expect(InvalidateSync.isBackgrounded, isTrue);
      expect(deliveries, 2);
      expect(messageOutbox.contains('background-renewal'), isTrue);
      expect(
        (await TokenStorage().getCredentials())?.token,
        isNot(expiring.token),
      );

      runtime.resume();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(runtime.isLifecycleSuspended, isFalse);
      expect(InvalidateSync.isBackgrounded, isFalse);
      expect(deliveries, 3);
      expect(messageOutbox.contains('background-renewal'), isFalse);
    },
  );
}
