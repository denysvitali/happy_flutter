import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/canary_mode.dart';

void main() {
  group('CanaryAssert (compile-time gated)', () {
    setUp(CanaryAssert.reset);

    test('kCanary defaults to false in tests (no overhead in prod)', () {
      // The test environment doesn't pass --dart-define so the build
      // flag is the same as a default production build.
      expect(kCanary, false);
    });

    test('check() is a no-op when kCanary is false', () {
      CanaryAssert.check(false, invariant: 'something_violated');
      // No violation should be recorded — the entire branch is dead
      // when kCanary is false.
      expect(CanaryAssert.violationCount, 0);
      expect(CanaryAssert.lastViolation, isNull);
    });

    test('noDuplicateLocalId is a no-op when kCanary is false', () {
      CanaryAssert.noDuplicateLocalId(localId: 'x', rowCount: 5);
      expect(CanaryAssert.violationCount, 0);
    });

    test('ackMatchedOptimistic is a no-op when kCanary is false', () {
      CanaryAssert.ackMatchedOptimistic(
        localId: 'x',
        optimisticFound: false,
      );
      expect(CanaryAssert.violationCount, 0);
    });

    test('retryPreservesLocalId is a no-op when kCanary is false', () {
      CanaryAssert.retryPreservesLocalId(expected: 'a', observed: 'b');
      expect(CanaryAssert.violationCount, 0);
    });
  });
}
