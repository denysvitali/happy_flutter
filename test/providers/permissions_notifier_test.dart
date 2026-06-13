import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('PermissionsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      sync.testIsInitialized = false;
    });

    tearDown(() {
      sync.testIsInitialized = false;
      container.dispose();
    });

    test('build returns a notifier', () {
      final notifier = container.read(permissionsNotifierProvider.notifier);
      expect(notifier, isA<PermissionsNotifier>());
    });

    test('allow throws StateError when sync is not initialized', () async {
      final notifier = container.read(permissionsNotifierProvider.notifier);

      await expectLater(
        () => notifier.allow('session-1', 'perm-1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Sync is not initialized',
          ),
        ),
      );
    });

    test('deny throws StateError when sync is not initialized', () async {
      final notifier = container.read(permissionsNotifierProvider.notifier);

      await expectLater(
        () => notifier.deny('session-1', 'perm-1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Sync is not initialized',
          ),
        ),
      );
    });

    test('allow preserves optional parameters in the guard path', () async {
      final notifier = container.read(permissionsNotifierProvider.notifier);

      await expectLater(
        () => notifier.allow(
          'session-1',
          'perm-1',
          mode: 'default',
          decision: 'approve',
          updatedInput: <String, dynamic>{'answer': 'yes'},
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Sync is not initialized',
          ),
        ),
      );
    });
  });
}
