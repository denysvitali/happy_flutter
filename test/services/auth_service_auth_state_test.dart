import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/services/auth_service.dart';
import 'package:happy_flutter/core/services/storage_service.dart';

/// `ApiClient` accepts every status (`validateStatus: (_) => true`), so a
/// rejected token comes back as an ordinary [Response] and never as a
/// [DioException]. These tests pin the behaviour of [AuthService.getAuthState]
/// on that shape: the 401/403 branch used to sit behind `on DioException` and
/// therefore never ran, turning a revoked token into a generic
/// [AuthState.error] with no logging and no sign-out.
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

  group('AuthService.getAuthState', () {
    late ApiClient apiClient;

    setUp(() async {
      apiClient = ApiClient();
      await apiClient.initialize(serverUrl: 'https://test.example.com');
      await TokenStorage().setCredentials(
        const AuthCredentials(token: 'stale-token', secret: 'c2VjcmV0'),
      );
    });

    tearDown(() async {
      apiClient.dispose();
      await TokenStorage().removeCredentials();
    });

    test('signs out when the server rejects the stored token with a 401 '
        'response (not a DioException)', () async {
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

      final state = await AuthService().getAuthState();

      expect(state, AuthState.unauthenticated);
      expect(AuthService().lastAuthFailure, AuthFailureKind.rejected);
      expect(
        await TokenStorage().getCredentials(),
        isNull,
        reason: 'a rejected token must be cleared, not kept',
      );
    });

    test('reports a transport failure as an error state and keeps the '
        'credentials', () async {
      apiClient.testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'offline',
              ),
            );
          },
        ),
      );

      final state = await AuthService().getAuthState();

      expect(state, AuthState.error);
      expect(
        AuthService().lastAuthFailure,
        AuthFailureKind.network,
        reason:
            'an offline device must be distinguishable from a rejected token',
      );
      expect(await TokenStorage().getCredentials(), isNotNull);
    });

    test('treats a 5xx from the verify endpoint as a server failure', () async {
      apiClient.testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<dynamic>(
                data: const {'error': 'boom'},
                statusCode: 500,
                requestOptions: options,
              ),
              true,
            );
          },
        ),
      );

      final state = await AuthService().getAuthState();

      expect(state, AuthState.error);
      expect(AuthService().lastAuthFailure, AuthFailureKind.server);
      expect(await TokenStorage().getCredentials(), isNotNull);
    });
  });
}
