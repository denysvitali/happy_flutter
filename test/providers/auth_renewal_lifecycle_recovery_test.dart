import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/profile_notifier.dart';
import 'package:happy_flutter/core/providers/settings_notifier.dart';
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

/// The runtime under test has no settings manager; post-auth loading only
/// needs notifiers that do not touch it.
class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings();

  @override
  void loadFromSync() {}
}

class _StorageFreeProfileNotifier extends ProfileNotifier {
  @override
  void loadFromSync() {}
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

/// Drives [future] to completion inside the widget test's fake-async zone.
///
/// The renewal request path only progresses while the fake clock advances,
/// so a bare `await` on it never completes under `testWidgets`.
Future<T> _settle<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  late T value;
  Object? error;
  StackTrace? stack;
  future.then(
    (result) {
      value = result;
      done = true;
    },
    onError: (Object e, StackTrace s) {
      error = e;
      stack = s;
      done = true;
    },
  );
  for (var i = 0; i < 500 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
  if (error != null) Error.throwWithStackTrace(error!, stack!);
  if (!done) fail('future did not settle');
  return value;
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
      final container = ProviderContainer(
        overrides: [
          settingsNotifierProvider.overrideWith(
            _StorageFreeSettingsNotifier.new,
          ),
          profileNotifierProvider.overrideWith(_StorageFreeProfileNotifier.new),
        ],
      );
      // Cancels the outbox, runtime and renewal timers. It must also run
      // inside the body: addTearDown fires after the pending-timer check.
      var released = false;
      Future<void> releaseRuntime() async {
        if (released) return;
        released = true;
        container.dispose();
        await runtime.shutdown();
        runtime.setAuthenticationBlocked(false);
        InvalidateSync.isBackgrounded = false;
        messageOutbox.dispose();
        api
          ..clearToken()
          ..dispose();
        tokenRefreshManager.reset();
      }

      addTearDown(() async {
        await releaseRuntime();
        // removeCredentials() blocks in this harness while persisting its
        // MMKV logout marker; the file's isolate only needs the mock reset.
        FlutterSecureStorage.setMockInitialValues({});
      });
      final notifier = container.read(authStateNotifierProvider.notifier);

      // An invalid renewal response keeps the runtime's pending sends.
      await _settle(tester, notifier.checkAuth(showProgress: false));
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
      await _settle(tester, notifier.checkAuth(showProgress: false));
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
      await _settle(tester, notifier.checkAuth(showProgress: false));
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
      await _settle(tester, renewalStarted.future);
      runtime.suspend();
      renewalRelease.complete();
      await _settle(tester, pendingCheck);
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

      // Shutdown awaits real I/O, which fake time cannot advance.
      await tester.runAsync(releaseRuntime);
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
