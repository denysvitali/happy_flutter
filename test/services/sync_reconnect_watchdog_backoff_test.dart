import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

/// The reconnect watchdog escalates its probe delay up to 600s while the
/// socket is down. That escalation must belong to ONE outage: if the
/// counter survives a successful connect, the next unrelated outage
/// starts its recovery minutes late.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    createTestSync()..testIsInitialized = true;
    InvalidateSync.isBackgrounded = false;
    sync.subscribeToUpdates();
  });

  tearDown(() async {
    await sync.shutdown();
    socketIoClient.testConnectionStatus = ConnectionStatus.disconnected;
    InvalidateSync.isBackgrounded = false;
  });

  test('a successful reconnect resets the watchdog backoff index', () {
    // An outage escalated the watchdog all the way to the 600s cap.
    sync.testReconnectWatchdogAttempt = 5;

    socketIoClient.testConnectionStatus = ConnectionStatus.connected;
    socketIoClient.testNotifyReconnected();

    expect(
      sync.testReconnectWatchdogAttempt,
      0,
      reason:
          'a later, unrelated outage must probe again after 15s, not '
          'inherit the previous outage\'s 600s backoff',
    );
  });

  test('an uninitialized runtime ignores reconnect callbacks', () {
    sync.testIsInitialized = false;
    sync.testReconnectWatchdogAttempt = 5;

    socketIoClient.testConnectionStatus = ConnectionStatus.connected;
    socketIoClient.testNotifyReconnected();

    expect(sync.testReconnectWatchdogAttempt, 5);
  });
}
