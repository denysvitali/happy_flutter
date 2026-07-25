import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';

/// Regression coverage for the overlapping-dial defect.
///
/// Five independent callers (lifecycle resume, reconnect watchdog,
/// forceReconnect, network-restored, reconnect-exhausted) can request a
/// reconnect within the same second. Before the in-flight guard each one
/// tore down the half-open socket and dialled again, so the server saw
/// overlapping connections and booked the abandoned ones as involuntary
/// disconnects.
void main() {
  void resetClient() {
    // Drop any Manager a test dial created — a leftover `_socket` makes
    // later cases wait on a status stream that never fires.
    socketIoClient.disconnect();
    socketIoClient.testSetCredentials();
    socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;
    socketIoClient.testLastConnectStartedAtMs = null;
    socketIoClient.testHasConnectedOnce = false;
  }

  setUp(resetClient);
  tearDown(resetClient);

  group('SocketIoClient.reconnect in-flight guard', () {
    void withCredentials() {
      socketIoClient.testSetCredentials(
        serverUrl: 'https://example.invalid',
        token: 'token',
        clientType: 'user-scoped',
      );
    }

    test('skips a redial while a fresh dial is still negotiating', () {
      withCredentials();
      final skippedBefore = socketIoClient.testReconnectSkipped;
      socketIoClient.testConnectionStatus = ConnectionStatus.connecting;
      socketIoClient.testLastConnectStartedAtMs =
          DateTime.now().millisecondsSinceEpoch;

      socketIoClient.reconnect(reason: DialReason.watchdog);

      expect(
        socketIoClient.testReconnectSkipped,
        skippedBefore + 1,
        reason:
            'a dial that started moments ago is still negotiating — the '
            'server allows 20s for the handshake, so abandoning it here '
            'produces an involuntary disconnect on the server side',
      );
    });

    test('allows a redial once the in-flight window has elapsed', () {
      withCredentials();
      final skippedBefore = socketIoClient.testReconnectSkipped;
      socketIoClient.testConnectionStatus = ConnectionStatus.connecting;
      // 30s ago — far outside the in-flight window.
      socketIoClient.testLastConnectStartedAtMs =
          DateTime.now().millisecondsSinceEpoch - 30000;

      socketIoClient.reconnect(reason: DialReason.watchdog);

      expect(socketIoClient.testReconnectSkipped, skippedBefore);
    });

    test('never skips a disconnected socket', () {
      withCredentials();
      final skippedBefore = socketIoClient.testReconnectSkipped;
      socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;
      socketIoClient.testLastConnectStartedAtMs =
          DateTime.now().millisecondsSinceEpoch;

      socketIoClient.reconnect(reason: DialReason.networkRestored);

      expect(socketIoClient.testReconnectSkipped, skippedBefore);
    });

    test('force: true bypasses the guard', () {
      withCredentials();
      final skippedBefore = socketIoClient.testReconnectSkipped;
      socketIoClient.testConnectionStatus = ConnectionStatus.connecting;
      socketIoClient.testLastConnectStartedAtMs =
          DateTime.now().millisecondsSinceEpoch;

      // A rotated token or a zombie socket makes the in-flight dial
      // useless — waiting it out only delays recovery.
      socketIoClient.reconnect(reason: DialReason.tokenRefresh, force: true);

      expect(socketIoClient.testReconnectSkipped, skippedBefore);
    });

    test('reconnect without stored credentials stays a no-op', () {
      final requestsBefore = socketIoClient.testReconnectRequests;
      final skippedBefore = socketIoClient.testReconnectSkipped;

      socketIoClient.reconnect(reason: DialReason.userManual);

      expect(socketIoClient.testReconnectRequests, requestsBefore + 1);
      expect(socketIoClient.testReconnectSkipped, skippedBefore);
    });
  });

  group('SocketIoClient.emitWithAck null-socket guard', () {
    test(
      'reports a missing socket as SocketNotConnectedException rather '
      'than a "Null check operator used on a null value" TypeError',
      () async {
        // `_status == connected` with a null `_socket` is exactly the
        // state a lifecycle suspend or a watchdog-driven reconnect leaves
        // behind while a caller is parked in emitWithAck's await gap.
        socketIoClient.testConnectionStatus = ConnectionStatus.connected;

        await expectLater(
          socketIoClient.emitWithAck('rpc-call', <String, dynamic>{}),
          throwsA(isA<SocketNotConnectedException>()),
        );
      },
    );

    test('fails fast instead of burning the caller-supplied budget', () async {
      socketIoClient.testConnectionStatus = ConnectionStatus.connected;
      final sw = Stopwatch()..start();

      await expectLater(
        socketIoClient.emitWithAck(
          'rpc-call',
          <String, dynamic>{},
          timeout: const Duration(seconds: 30),
        ),
        throwsA(isA<SocketNotConnectedException>()),
      );

      expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
    });
  });
}
