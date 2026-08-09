import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/services/power_diagnostics_service.dart';

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

    test('does not replace the Manager retry loop after connect error', () {
      socketIoClient.connect(serverUrl: 'http://127.0.0.1:1', token: 'token');
      final skippedBefore = socketIoClient.testReconnectSkipped;
      socketIoClient.testConnectionStatus = ConnectionStatus.error;
      socketIoClient.testManagerReconnecting = true;

      socketIoClient.reconnect(reason: DialReason.watchdog);

      expect(
        socketIoClient.testReconnectSkipped,
        skippedBefore + 1,
        reason:
            'Socket.IO already owns a bounded retry loop; replacing its '
            'Manager turns one outage into overlapping connect/disconnect '
            'cycles and strands ACK callers on the discarded generation',
      );
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

    test('a socket torn down inside the await gap throws '
        'SocketNotConnectedException, not a null-check TypeError', () async {
      // Install a real Socket object (it never reaches the unroutable
      // port, which is fine — we only need `_socket != null`) so
      // waitForConnection takes its "already connected" fast path
      // instead of the null short-circuit.
      socketIoClient.connect(serverUrl: 'http://127.0.0.1:1', token: 'token');
      socketIoClient.testConnectionStatus = ConnectionStatus.connected;

      // emitWithAck runs up to its `await waitForConnection(...)` and
      // suspends. Tearing the socket down here — exactly what a
      // lifecycle suspend or watchdog reconnect does — nulls `_socket`
      // before the emit resumes.
      final pending = socketIoClient.emitWithAck(
        'rpc-call',
        <String, dynamic>{},
      );
      socketIoClient.disconnect();

      await expectLater(pending, throwsA(isA<SocketNotConnectedException>()));
    });
  });

  group('SocketIoClient.emitWithAck budget exhaustion', () {
    test(
      'does not put the payload on the wire when no budget is left',
      () async {
        socketIoClient.connect(serverUrl: 'http://127.0.0.1:1', token: 'token');
        socketIoClient.testConnectionStatus = ConnectionStatus.connected;

        final acksBefore = powerDiagnostics.snapshot().socketAckCalls;

        // Zero budget models the real case: waitForConnection consumed the
        // whole timeout and the socket connected at the last millisecond.
        await expectLater(
          socketIoClient.emitWithAck(
            'rpc-call',
            <String, dynamic>{},
            timeout: Duration.zero,
          ),
          throwsA(isA<SocketAckTimeoutException>()),
        );

        expect(
          powerDiagnostics.snapshot().socketAckCalls,
          acksBefore,
          reason:
              'emitting and then immediately reporting an ACK timeout makes '
              'the caller retry a message the server already received',
        );
      },
    );
  });
}
