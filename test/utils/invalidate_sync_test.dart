import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

void main() {
  group('InvalidateSync', () {
    test('runs action when invalidated', () async {
      var callCount = 0;
      final sync = InvalidateSync(() async {
        callCount++;
      });

      sync.invalidate();
      await sync.awaitQueue();

      expect(callCount, 1);
    });

    test('coalesces invalidations while running into one extra run', () async {
      final firstRunBlocker = Completer<void>();
      var callCount = 0;

      final sync = InvalidateSync(() async {
        callCount++;
        if (callCount == 1) {
          await firstRunBlocker.future;
        }
      });

      sync.invalidate();
      await Future<void>.delayed(Duration.zero);
      sync.invalidate();
      firstRunBlocker.complete();

      await sync.awaitQueue();

      expect(callCount, 2);
    });

    test('supports multiple invalidate cycles', () async {
      var callCount = 0;
      final sync = InvalidateSync(() async {
        callCount++;
      });

      sync.invalidate();
      await sync.awaitQueue();

      sync.invalidate();
      await sync.awaitQueue();

      expect(callCount, 2);
    });

    test('retries on failure and eventually succeeds', () async {
      var callCount = 0;
      final sync = InvalidateSync(() async {
        callCount++;
        if (callCount == 1) {
          throw StateError('transient error');
        }
      });

      sync.invalidate();
      await sync.awaitQueue();

      expect(callCount, 2);
    });
  });
}
