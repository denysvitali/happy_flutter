import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

/// The reconnect watchdog escalates its probe delay 15s -> 30s -> 60s ->
/// 120s while the socket is down. That escalation must belong to ONE
/// outage: if the counter survives a successful connect, the next
/// unrelated outage starts its recovery two minutes late.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    sync.testCancelReconnectWatchdog();
    sync.testReconnectWatchdogAttempt = 0;
    socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;
  });

  test('a successful reconnect resets the watchdog backoff index', () {
    sync.sessionsSync = InvalidateSync(() async {});
    sync.machinesSync = InvalidateSync(() async {});
    sync.subscribeToUpdates();
    // An outage escalated the watchdog all the way to the 120s cap.
    sync.testReconnectWatchdogAttempt = 4;

    socketIoClient.testConnectionStatus = ConnectionStatus.connected;
    socketIoClient.testNotifyReconnected();

    expect(
      sync.testReconnectWatchdogAttempt,
      0,
      reason:
          'a later, unrelated outage must probe again after 15s, not '
          'inherit the previous outage\'s 120s backoff',
    );
  });
}
