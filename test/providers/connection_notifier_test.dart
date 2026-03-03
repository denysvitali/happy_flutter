import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('ConnectionNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with disconnected state', () {
      final status = container.read(connectionNotifierProvider);
      expect(status, ConnectionStatus.disconnected);
    });

    test('should create notifier with connection methods', () {
      final notifier = container.read(connectionNotifierProvider.notifier);
      expect(notifier, isA<ConnectionNotifier>());
      expect(notifier.connect, isA<Function>());
      expect(notifier.disconnect, isA<Function>());
    });

    test('should have all connection status enum values', () {
      expect(ConnectionStatus.values, hasLength(4));
      expect(ConnectionStatus.disconnected, isNotNull);
      expect(ConnectionStatus.connecting, isNotNull);
      expect(ConnectionStatus.connected, isNotNull);
      expect(ConnectionStatus.error, isNotNull);
    });

    test('should handle disconnect when already disconnected', () {
      final notifier = container.read(connectionNotifierProvider.notifier);

      // Should not throw when disconnecting already disconnected client
      notifier.disconnect();

      final status = container.read(connectionNotifierProvider);
      expect(status, ConnectionStatus.disconnected);
    });

    test('should handle connection status transitions', () {
      // Test that we can read the notifier and it has the expected interface
      final notifier = container.read(connectionNotifierProvider.notifier);
      expect(notifier, isA<ConnectionNotifier>());

      // Initial state should be disconnected
      expect(container.read(connectionNotifierProvider), ConnectionStatus.disconnected);
    });

    test('ConnectionStatus enum should have correct indices', () {
      expect(ConnectionStatus.disconnected.index, 0);
      expect(ConnectionStatus.connecting.index, 1);
      expect(ConnectionStatus.connected.index, 2);
      expect(ConnectionStatus.error.index, 3);
    });

    test('should create multiple notifiers independently', () {
      final container1 = ProviderContainer();
      final container2 = ProviderContainer();

      final notifier1 = container1.read(connectionNotifierProvider.notifier);
      final notifier2 = container2.read(connectionNotifierProvider.notifier);

      expect(notifier1, isNot(equals(notifier2)));

      container1.dispose();
      container2.dispose();
    });

    test(
      'should handle connect call with null socket',
      skip: 'Makes real WebSocket connection in test env',
      () {
        final notifier =
            container.read(connectionNotifierProvider.notifier);

        notifier.connect('https://test.example.com', 'test-token');

        expect(
          container.read(connectionNotifierProvider),
          isA<ConnectionStatus>(),
        );
      },
    );
  });
}
