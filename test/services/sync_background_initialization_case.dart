import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/server_config.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

class _Encryption implements Encryption {
  @override
  String get anonId => 'cold-account';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OutboxStorage extends MMKVStorage {
  _OutboxStorage() : super.testConstructor();
  int reads = 0;
  int writes = 0;
  @override
  Future<String?> getOutboxEntries() async {
    reads++;
    return null;
  }

  @override
  Future<void> saveOutboxEntries(String value) async {
    writes++;
  }
}

/// Advances both real time (cache/outbox I/O) and the fake clock (sync
/// timers) until [done] holds or two simulated seconds have passed.
Future<void> _settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 20 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Stops the runtime and lets the MMKV compaction and socket connect
/// timers it scheduled expire before the fake clock's pending-timer check.
Future<void> _drainTimers(WidgetTester tester, Sync runtime) async {
  var stopped = false;
  unawaited(runtime.shutdown().then((_) => stopped = true));
  await _settle(tester, () => stopped);
  await tester.pump(const Duration(seconds: 20));
}

/// Cold restore while the app is backgrounded must not touch the network
/// or the persisted outbox until it is resumed ([cancel] false) or the
/// account is blocked ([cancel] true).
///
/// Each variant lives in its own test file: the `Sync` singleton keeps
/// async queues whose futures belong to a finished test's fake-async zone,
/// so a second restore in the same isolate never initializes.
void defineColdRestoreTest({required bool cancel}) {
  testWidgets('cold restore defers traffic (${cancel ? 'cancel' : 'resume'})', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await MMKVStorage.initialize();
    final previousServer = getServerUrl();
    setServerUrl('https://example.test');
    final api = ApiClient();
    await api.initialize(serverUrl: 'https://example.test');
    final storage = _OutboxStorage();
    messageOutbox.testStorage = storage;
    final runtime = createTestSync()..suspend();
    final dialAttempts = socketIoClient.testDialAttempt;
    var completed = false;
    unawaited(
      runtime
          .restore(
            const AuthCredentials(token: 'cold-token', secret: 'unused'),
            _Encryption(),
          )
          .then((_) => completed = true),
    );
    addTearDown(() async {
      // Both branches assert the restore completed. Awaiting it here
      // never resumes once the test's fake-async zone has finished.
      await runtime.shutdown();
      runtime
        ..setAuthenticationBlocked(false)
        ..resume();
      InvalidateSync.isBackgrounded = false;
      MMKVStorage.resetForTesting();
      setServerUrl(previousServer);
      api.dispose();
    });
    await _settle(tester, () => runtime.isInitialized);
    expect(runtime.isInitialized, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(completed, isFalse);
    expect(socketIoClient.testDialAttempt, dialAttempts);
    expect(storage.reads, 0);
    expect(storage.writes, 0);
    expect(InvalidateSync.isBackgrounded, isTrue);

    if (cancel) {
      runtime.setAuthenticationBlocked(true);
      await _settle(tester, () => completed);
      expect(completed, isTrue);
      expect(socketIoClient.testDialAttempt, dialAttempts);
      expect(storage.reads, 0);
      expect(storage.writes, 0);
      await _drainTimers(tester, runtime);
      return;
    }

    // Keep initialization/socket/outbox real, with domain HTTP actions stubbed.
    createTestSync();
    runtime.resume();
    await _settle(tester, () => completed);
    expect(completed, isTrue);
    expect(socketIoClient.testDialAttempt, dialAttempts + 1);
    expect(storage.reads, 1);
    expect(InvalidateSync.isBackgrounded, isFalse);
    await _drainTimers(tester, runtime);
  });
}
