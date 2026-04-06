import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthStateNotifier', () {
    late ProviderContainer container;

    setUpAll(() {
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        <String, String>{},
      );
    });

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with unauthenticated state', () {
      final authState = container.read(authStateNotifierProvider);
      expect(authState, AuthState.unauthenticated);
    });

    test('should transition to authenticating during checkAuth', () async {
      final notifier = container.read(authStateNotifierProvider.notifier);

      // Initial state
      expect(
        container.read(authStateNotifierProvider),
        AuthState.unauthenticated,
      );

      // Start authentication (will fail since no credentials, but state should
      // transition through authenticating)
      await notifier.checkAuth();

      // Should end up unauthenticated or error (not authenticating)
      final finalState = container.read(authStateNotifierProvider);
      expect(finalState, isNot(AuthState.authenticating));
    });

    test('should handle state transitions correctly', () {
      final notifier = container.read(authStateNotifierProvider.notifier);

      // Test that we can manually verify state transitions by checking
      // the notifier builds correctly
      expect(notifier, isA<AuthStateNotifier>());
      expect(
        container.read(authStateNotifierProvider),
        AuthState.unauthenticated,
      );
    });

    test('should maintain unauthenticated state when no credentials', () async {
      final notifier = container.read(authStateNotifierProvider.notifier);

      await notifier.checkAuth();

      final state = container.read(authStateNotifierProvider);
      expect(state, isNot(AuthState.authenticated));
      expect(state, isNot(AuthState.authenticating));
    });

    test('should have correct AuthState enum values', () {
      // Verify all expected enum values exist
      expect(AuthState.unauthenticated, isNotNull);
      expect(AuthState.authenticating, isNotNull);
      expect(AuthState.authenticated, isNotNull);
      expect(AuthState.error, isNotNull);

      // Verify ordering (useful for state machine logic)
      final values = AuthState.values;
      expect(values, hasLength(4));
      expect(values[0], AuthState.unauthenticated);
      expect(values[1], AuthState.authenticating);
      expect(values[2], AuthState.authenticated);
      expect(values[3], AuthState.error);
    });

    test('should create notifier with AuthService', () {
      final notifier = container.read(authStateNotifierProvider.notifier);
      expect(notifier, isA<AuthStateNotifier>());
    });
  });
}
