import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

void main() {
  test(
    'critical failure remains active until a later successful refresh',
    () async {
      final sync = createTestSync()..testIsInitialized = true;
      addTearDown(() => sync.testIsInitialized = false);
      var shouldFail = true;
      final manager = InvalidateSync(() async {
        if (shouldFail) throw StateError('statusCode=503');
      }, maxRetries: 0);
      sync.machinesSync = manager;

      manager.invalidate();
      await expectLater(manager.awaitQueue(), throwsStateError);

      expect(sync.hasUnrecoveredCriticalSyncFailure, isTrue);

      shouldFail = false;
      manager.invalidate();
      await manager.awaitQueue();

      expect(sync.hasUnrecoveredCriticalSyncFailure, isFalse);
    },
  );

  test('failure stays hidden while its retry cycle is pending', () async {
    final gate = Completer<void>();
    final manager = InvalidateSync(
      () => gate.future,
      maxRetries: 0,
    )..invalidate();

    expect(manager.isPending, isTrue);
    expect(hasUnrecoveredSyncFailure(manager), isFalse);

    gate.complete();
    await manager.awaitQueue();
  });
}
