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

void main() {
  for (final cancel in [false, true]) {
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
      final restoring = runtime
          .restore(
            const AuthCredentials(token: 'cold-token', secret: 'unused'),
            _Encryption(),
          )
          .then((_) => completed = true);
      addTearDown(() async {
        await runtime.shutdown();
        await restoring;
        runtime
          ..setAuthenticationBlocked(false)
          ..resume();
        InvalidateSync.isBackgrounded = false;
        MMKVStorage.resetForTesting();
        setServerUrl(previousServer);
        api.dispose();
      });
      for (var i = 0; i < 20 && !runtime.isInitialized; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(runtime.isInitialized, isTrue);
      await tester.pump(const Duration(seconds: 3));
      expect(completed, isFalse);
      expect(socketIoClient.testDialAttempt, dialAttempts);
      expect(storage.reads, 0);
      expect(storage.writes, 0);
      expect(InvalidateSync.isBackgrounded, isTrue);

      if (cancel) {
        runtime.setAuthenticationBlocked(true);
        await restoring;
        expect(completed, isTrue);
        expect(socketIoClient.testDialAttempt, dialAttempts);
        expect(storage.reads, 0);
        expect(storage.writes, 0);
        return;
      }

      // Keep initialization/socket/outbox real, with domain HTTP actions stubbed.
      createTestSync();
      runtime.resume();
      await restoring;
      await tester.pump();
      expect(completed, isTrue);
      expect(socketIoClient.testDialAttempt, dialAttempts + 1);
      expect(storage.reads, 1);
      expect(InvalidateSync.isBackgrounded, isFalse);
    });
  }
}
