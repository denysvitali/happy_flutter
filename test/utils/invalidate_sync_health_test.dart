import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

void main() {
  test('exposes only bounded failure health metadata and recovers', () async {
    var shouldFail = true;
    final manager = InvalidateSync(() async {
      if (shouldFail) throw TimeoutException('secret backend detail');
    }, maxRetries: 0);

    await expectLater(
      manager.invalidateAndAwait(),
      throwsA(isA<TimeoutException>()),
    );
    expect(manager.lastFailureAtMs, isNotNull);
    expect(manager.lastFailureKind, 'timeout');
    expect(manager.lastSuccessAtMs, isNull);

    shouldFail = false;
    await manager.invalidateAndAwait();

    expect(manager.lastSuccessAtMs, isNotNull);
    expect(manager.lastFailureKind, 'timeout');
  });
}
