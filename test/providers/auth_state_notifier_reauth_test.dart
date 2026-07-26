import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/storage_service.dart';
import 'package:happy_flutter/core/services/token_refresh_manager.dart';
import 'package:riverpod/riverpod.dart';

/// Regression: a 401 must actually end in a signed-out app.
///
/// The HTTP layer signals a rejected token through
/// `TokenRefreshManager.notifyReauthRequired()`. Its only listener used to
/// call `checkAuth()`, which merely reads the credentials off disk — so a
/// revoked token left the state `authenticated` forever while the sync
/// invalidations it kicked off 401'd again in a 10s loop. The listener must
/// go through `AuthService.getAuthState()`, which verifies against
/// `/v1/auth/verify` and signs out when the token is rejected.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStoragePlatform originalStoragePlatform;

  setUpAll(() {
    originalStoragePlatform = FlutterSecureStoragePlatform.instance;
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      <String, String>{},
    );
  });

  tearDownAll(() {
    FlutterSecureStoragePlatform.instance = originalStoragePlatform;
  });

  test('a server-rejected token signs the user out instead of staying '
      'authenticated', () async {
    final apiClient = ApiClient();
    await apiClient.initialize(serverUrl: 'https://test.example.com');
    apiClient.testDio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              data: const {'error': 'unauthorized'},
              statusCode: 401,
              requestOptions: options,
            ),
            true,
          );
        },
      ),
    );
    await TokenStorage().setCredentials(
      const AuthCredentials(token: 'revoked-token', secret: 'c2VjcmV0'),
    );

    final container = ProviderContainer();
    addTearDown(() async {
      container.dispose();
      apiClient.dispose();
      await TokenStorage().removeCredentials();
    });

    // Mount the notifier so it registers its re-auth listener.
    container.read(authStateNotifierProvider);

    // Exactly what RetryInterceptor does on a non-auth 401.
    tokenRefreshManager.notifyReauthRequired();

    // The verification is fire-and-forget; give it a bounded window.
    for (var i = 0; i < 100; i++) {
      if (await TokenStorage().getCredentials() == null) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(
      container.read(authStateNotifierProvider),
      AuthState.unauthenticated,
      reason: 'a token the server rejects must surface the sign-in screen',
    );
    expect(
      await TokenStorage().getCredentials(),
      isNull,
      reason: 'the rejected credentials must be cleared',
    );
  });
}
