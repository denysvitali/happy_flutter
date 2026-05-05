import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';

void main() {
  group('SocketIoClient disconnect lifecycle', () {
    tearDown(() {
      socketIoClient.testHasConnectedOnce = false;
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
