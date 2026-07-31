import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
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

    // Jaeger showed 79 `websocket.dial` spans against ZERO
    // `websocket.disconnect` spans: disconnect() bumps the connection
    // generation before the library's own disconnect event fires, so the
    // guarded handler returned before emitting the span, the Sentry
    // transaction or the log line. The emission now happens at the call site,
    // and the caller-supplied reason is what makes a suspend, a logout and a
    // reconnect distinguishable.
    test('disconnect(reason:) emits the record with the caller reason', () {
      LoggerService().clear();
      socketIoClient.testConnectionStatus = ConnectionStatus.connected;

      socketIoClient.disconnect(
        preserveConnectionHistory: true,
        reason: DisconnectReason.lifecycleSuspend,
      );

      expect(
        LoggerService().getLogs().map((entry) => entry.message),
        contains(
          startsWith(
            'Socket.IO disconnected '
            'reason=${DisconnectReason.lifecycleSuspend}',
          ),
        ),
      );
    });

    test('disconnect() defaults to the io-client-disconnect facet', () {
      LoggerService().clear();
      socketIoClient.testConnectionStatus = ConnectionStatus.connected;

      socketIoClient.disconnect();

      expect(
        LoggerService().getLogs().map((entry) => entry.message),
        contains(
          startsWith(
            'Socket.IO disconnected '
            'reason=${DisconnectReason.ioClientDisconnect}',
          ),
        ),
      );
    });

    test('an already-disconnected teardown emits nothing', () {
      LoggerService().clear();
      socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;

      socketIoClient.disconnect(reason: DisconnectReason.appShutdown);

      expect(
        LoggerService()
            .getLogs()
            .where((e) => e.message.startsWith('Socket.IO disconnected')),
        isEmpty,
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

  group('SocketIoClient reconnect backoff', () {
    test('first attempt uses the 1s initial delay and caps at 10s', () {
      // P1-4b: initial reconnect delay lowered 2s -> 1s for faster
      // first-attempt recovery on resume (Jaeger traced reconnect spans
      // averaging ~4.4s). Exponential growth must still cap at 10s so
      // later attempts stay battery-friendly.
      expect(SocketIoClient.testBackoffDelayMs(0), 1000);
      expect(SocketIoClient.testBackoffDelayMs(1), 2000);
      expect(SocketIoClient.testBackoffDelayMs(2), 4000);
      expect(SocketIoClient.testBackoffDelayMs(3), 8000);
      // 1s * 2^4 = 16s is clamped to the 10s max.
      expect(SocketIoClient.testBackoffDelayMs(4), 10000);
      expect(SocketIoClient.testBackoffDelayMs(5), 10000);
      expect(SocketIoClient.testBackoffDelayMs(20), 10000);
    });
  });
}
