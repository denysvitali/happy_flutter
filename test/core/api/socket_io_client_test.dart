import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/services/power_diagnostics_service.dart';

void main() {
  group('SocketIoClient disconnect lifecycle', () {
    tearDown(() {
      socketIoClient.testHasConnectedOnce = false;
      socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;
    });

    test('disconnect() resets connection history by default', () {
      socketIoClient.testHasConnectedOnce = true;

      socketIoClient.disconnect();

      expect(
        socketIoClient.testHasConnectedOnce,
        isFalse,
        reason:
            'Full disconnect should reset connection history for logout '
            'or hard teardowns',
      );
    });

    test(
      'disconnect(preserveConnectionHistory: true) keeps reconnect state',
      () {
        socketIoClient.testHasConnectedOnce = true;

        socketIoClient.disconnect(preserveConnectionHistory: true);

        expect(
          socketIoClient.testHasConnectedOnce,
          isTrue,
          reason:
              'Lifecycle suspends must keep reconnect state so the next '
              'foreground connect is treated as a reconnection',
        );
      },
    );

    test('disconnect advances callback generation', () {
      final before = socketIoClient.testConnectionGeneration;

      socketIoClient.disconnect(preserveConnectionHistory: true);

      expect(
        socketIoClient.testConnectionGeneration,
        greaterThan(before),
        reason:
            'Late callbacks from a disposed lifecycle socket must be ignored',
      );
    });

    test('disconnect() records the status transition for power diagnostics '
        '(battery regression: app-initiated disconnects — suspend, logout, '
        'reconnect — bump the connection generation before the underlying '
        "socket.io library's own 'disconnect' event fires, so that event's "
        'generation guard drops it; without recording here, '
        'socketDisconnects stayed at 0 forever while socketConnects kept '
        'incrementing on every real onConnect, hiding how often the '
        'socket actually churned)', () {
      powerDiagnostics.reset();
      socketIoClient.testConnectionStatus = ConnectionStatus.connected;

      socketIoClient.disconnect();

      expect(powerDiagnostics.snapshot().socketDisconnects, equals(1));
    });

    test('disconnect() does not double-count when already disconnected', () {
      powerDiagnostics.reset();
      socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;

      socketIoClient.disconnect();

      expect(powerDiagnostics.snapshot().socketDisconnects, equals(0));
    });
  });

  group('onReconnectExhausted', () {
    late List<void Function()> unsubscribes;

    setUp(() {
      unsubscribes = [];
    });

    tearDown(() {
      for (final unsub in unsubscribes) {
        unsub();
      }
      socketIoClient.testHasConnectedOnce = false;
    });

    test('listener is registered and unsubscribed cleanly', () {
      var callCount = 0;
      final unsub = socketIoClient.onReconnectExhausted(() {
        callCount++;
      });
      unsubscribes.add(unsub);

      // Unsubscribe and verify no further calls could be made.
      unsub();
      expect(callCount, 0);
    });
  });
}
