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

    group('dispose lifecycle', () {
      test('dispose completes awaitQueue normally', () async {
        final blocker = Completer<void>();
        final sync = InvalidateSync(() => blocker.future);

        sync.invalidate();
        // Yield so _run() starts and awaits the blocker.
        await Future<void>.delayed(Duration.zero);

        // Dispose while the action is in-flight.
        sync.dispose();

        // awaitQueue must complete without throwing.
        await sync.awaitQueue();
      });

      test(
        'dispose during in-flight op does not crash '
        'invalidateAndAwait callers',
        () async {
          final blocker = Completer<void>();
          final sync = InvalidateSync(() => blocker.future);

          final future = sync.invalidateAndAwait();
          await Future<void>.delayed(Duration.zero);

          sync.dispose();

          // Must complete normally — previously threw StateError.
          await future;
        },
      );

      test('revive after dispose runs new action', () async {
        var callCount = 0;
        final blocker = Completer<void>();
        final sync = InvalidateSync(() async {
          callCount++;
          if (callCount == 1) {
            await blocker.future;
          }
        });

        sync.invalidate();
        await Future<void>.delayed(Duration.zero);

        // Dispose while first action is in-flight.
        sync.dispose();

        // Revive by calling invalidate() again.
        sync.invalidate();
        await sync.awaitQueue();

        // The revived run should have executed.
        expect(callCount, 2);
      });

      test(
        'rapid suspend/resume cycle does not crash',
        () async {
          var callCount = 0;
          final blockers = <Completer<void>>[];
          final sync = InvalidateSync(() async {
            callCount++;
            final b = Completer<void>();
            blockers.add(b);
            await b.future;
          });

          // Simulate rapid suspend/resume cycling.
          for (var i = 0; i < 5; i++) {
            sync.invalidate();
            await Future<void>.delayed(Duration.zero);
            sync.dispose();
          }

          // Final revive.
          sync.invalidate();

          // Complete any pending blockers so the final run can
          // proceed if it reuses one.
          for (final b in blockers) {
            if (!b.isCompleted) b.complete();
          }

          await sync.awaitQueue();

          // At least the final run executed.
          expect(callCount, greaterThanOrEqualTo(1));
        },
      );
    });

    group('suspend lifecycle', () {
      test('suspend completes idle awaiters without disposing the instance', () async {
        var callCount = 0;
        final sync = InvalidateSync(() async {
          callCount++;
        });

        sync.invalidate();
        sync.suspend();
        await sync.awaitQueue();

        sync.invalidate();
        await sync.awaitQueue();

        expect(callCount, 2);
      });

      test(
        'suspend preserves an in-flight operation and allows reuse later',
        () async {
          final blocker = Completer<void>();
          var callCount = 0;
          final sync = InvalidateSync(() async {
            callCount++;
            if (callCount == 1) {
              await blocker.future;
            }
          });

          sync.invalidate();
          await Future<void>.delayed(Duration.zero);

          sync.suspend();
          blocker.complete();
          await sync.awaitQueue();

          sync.invalidate();
          await sync.awaitQueue();

          expect(callCount, 2);
        },
      );
    });

    test(
      'invalidateAndAwait completes after first success even when '
      're-invalidated repeatedly during the run',
      () async {
        // Regression test: if WebSocket events keep firing while
        // fetchSessions() is running (lots of Future.delayed yields),
        // invalidateAndAwait() must still complete after the first
        // successful run — not loop forever without completing.
        final blocker = Completer<void>();
        var callCount = 0;

        final sync = InvalidateSync(() async {
          callCount++;
          if (callCount == 1) {
            await blocker.future;
          }
        });

        // Start an invalidateAndAwait before the run begins.
        final awaitFuture = sync.invalidateAndAwait();

        // Yield so the run starts.
        await Future<void>.delayed(Duration.zero);

        // Simulate rapid WebSocket events re-invalidating while running.
        sync.invalidate();
        sync.invalidate();
        sync.invalidate();

        // Unblock the first run.
        blocker.complete();

        // Must resolve — previously this hung forever because the
        // Completer was never completed while _invalidated stayed true.
        await awaitFuture;

        // At least one run completed to unblock the awaiter.
        expect(callCount, greaterThanOrEqualTo(1));
      },
    );
  });
}
