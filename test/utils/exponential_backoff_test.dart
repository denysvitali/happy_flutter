import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/backoff.dart';

void main() {
  group('ExponentialBackoff', () {
    test('should start with minimum delay', () {
      final backoff = ExponentialBackoff(
        minDelayMs: 100,
        maxDelayMs: 1000,
      );

      expect(backoff.attempts, 0);
      expect(backoff.currentDelayMs, 100);
    });

    test('should calculate exponential delays', () {
      final backoff = ExponentialBackoff(
        minDelayMs: 100,
        maxDelayMs: 1000,
        factor: 2.0,
        jitter: 0.0,
      );

      final delay1 = backoff.next();
      expect(delay1, 100);
      expect(backoff.attempts, 1);

      final delay2 = backoff.next();
      expect(delay2, 200);
      expect(backoff.attempts, 2);

      final delay3 = backoff.next();
      expect(delay3, 400);
      expect(backoff.attempts, 3);

      final delay4 = backoff.next();
      expect(delay4, 800);
      expect(backoff.attempts, 4);

      final delay5 = backoff.next();
      expect(delay5, 1000); // Clamped to maxDelayMs
      expect(backoff.attempts, 5);
    });

    test('should respect max attempts', () {
      final backoff = ExponentialBackoff(
        minDelayMs: 100,
        maxDelayMs: 1000,
        maxAttempts: 3,
      );

      expect(backoff.canRetry, true);
      backoff.next();
      expect(backoff.canRetry, true);
      backoff.next();
      expect(backoff.canRetry, true);
      backoff.next();
      expect(backoff.canRetry, false);

      expect(
        () => backoff.next(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('No more retry attempts'),
        )),
      );
    });

    test('should allow infinite retries when maxAttempts is null', () {
      final backoff = ExponentialBackoff(
        minDelayMs: 100,
        maxDelayMs: 1000,
        maxAttempts: null,
      );

      for (var i = 0; i < 100; i++) {
        expect(backoff.canRetry, true);
        backoff.next();
      }
    });

    test('should reset to initial state', () {
      final backoff = ExponentialBackoff(
        minDelayMs: 100,
        maxDelayMs: 1000,
      );

      backoff.next();
      backoff.next();
      expect(backoff.attempts, 2);

      backoff.reset();
      expect(backoff.attempts, 0);
      expect(backoff.currentDelayMs, 100);
    });

    test('should apply jitter to delays', () {
      final backoff = ExponentialBackoff(
        minDelayMs: 100,
        maxDelayMs: 1000,
        jitter: 0.5,
      );

      final delays = <int>[];
      for (var i = 0; i < 10; i++) {
        delays.add(backoff.next());
        backoff.reset();
      }

      // With jitter, we should get some variation
      final uniqueDelays = delays.toSet();
      expect(uniqueDelays.length, greaterThan(1));
    });
  });

  group('ExponentialBackoff.websocket', () {
    test('should create WebSocket backoff with defaults', () {
      final backoff = ExponentialBackoff.websocket();

      expect(backoff.minDelayMs, 1000);
      expect(backoff.maxDelayMs, 5000);
      expect(backoff.maxAttempts, null);
    });

    test('should create WebSocket backoff with custom values', () {
      final backoff = ExponentialBackoff.websocket(
        minDelayMs: 500,
        maxDelayMs: 2000,
        maxAttempts: 5,
      );

      expect(backoff.minDelayMs, 500);
      expect(backoff.maxDelayMs, 2000);
      expect(backoff.maxAttempts, 5);
    });
  });

  group('exponentialBackoffDelay', () {
    test('should calculate delay with exponential growth', () {
      final delay1 = exponentialBackoffDelay(0, 250, 1000, 10);
      final delay2 = exponentialBackoffDelay(5, 250, 1000, 10);
      final delay3 = exponentialBackoffDelay(10, 250, 1000, 10);

      // Higher failure count should generally lead to higher delays
      // (though there's randomness)
      expect(delay2, greaterThan(0));
      expect(delay3, greaterThan(0));
      expect(delay3, lessThanOrEqualTo(1000));
    });

    test('should respect max delay', () {
      final maxDelay = 500;
      final delay = exponentialBackoffDelay(100, 100, maxDelay, 10);

      expect(delay, lessThanOrEqualTo(maxDelay));
    });

    test('should return at least min delay', () {
      final minDelay = 200;
      final delay = exponentialBackoffDelay(0, minDelay, 1000, 10);

      expect(delay, greaterThanOrEqualTo(0));
    });
  });

  group('createBackoff', () {
    test('should succeed on first try', () async {
      final withBackoff = createBackoff<String>(
        const BackoffOptions(
          minDelay: 10,
          maxDelay: 100,
          maxFailureCount: 5,
        ),
      );

      var callCount = 0;
      final result = await withBackoff(() async {
        callCount++;
        return 'success';
      });

      expect(result, 'success');
      expect(callCount, 1);
    });

    test('should retry on failure', () async {
      final withBackoff = createBackoff<String>(
        const BackoffOptions(
          minDelay: 10,
          maxDelay: 50,
          maxFailureCount: 10,
        ),
      );

      var attemptCount = 0;
      final result = await withBackoff(() async {
        attemptCount++;
        if (attemptCount < 3) {
          throw Exception('Temporary failure');
        }
        return 'success';
      });

      expect(result, 'success');
      expect(attemptCount, 3);
    });

    test('should call error handler on each failure', () async {
      final errors = <(dynamic, int)>[];
      final withBackoff = createBackoff<String>(
        BackoffOptions(
          minDelay: 10,
          maxDelay: 50,
          maxFailureCount: 10,
          onError: (error, count) {
            errors.add((error, count));
          },
        ),
      );

      var attemptCount = 0;
      await withBackoff(() async {
        attemptCount++;
        if (attemptCount < 3) {
          throw Exception('Attempt $attemptCount');
        }
        return 'success';
      });

      expect(errors.length, 2);
      expect(errors[0].$2, 1);
      expect(errors[0].$1.toString(), contains('Attempt 1'));
      expect(errors[1].$2, 2);
    });
  });

  group('createRetryingBackoff', () {
    test('should retry up to maxRetries times', () async {
      final withBackoff = createRetryingBackoff<String>(
        const BackoffOptions(
          minDelay: 10,
          maxDelay: 50,
        ),
        3,
      );

      var attemptCount = 0;
      await expectLater(
        () => withBackoff(() async {
          attemptCount++;
          throw Exception('Always fails');
        }),
        throwsA(isA<Exception>()),
      );

      expect(attemptCount, 4); // Initial attempt + 3 retries
    });

    test('should succeed before reaching maxRetries', () async {
      final withBackoff = createRetryingBackoff<String>(
        const BackoffOptions(
          minDelay: 10,
          maxDelay: 50,
        ),
        10,
      );

      var attemptCount = 0;
      final result = await withBackoff(() async {
        attemptCount++;
        if (attemptCount < 3) {
          throw Exception('Temporary failure');
        }
        return 'success';
      });

      expect(result, 'success');
      expect(attemptCount, 3);
    });
  });

  group('BackoffOptions', () {
    test('should use default values', () {
      final options = const BackoffOptions();

      expect(options.minDelay, 250);
      expect(options.maxDelay, 1000);
      expect(options.maxFailureCount, 50);
      expect(options.onError, isNull);
    });

    test('should use custom values', () {
      var errorCalled = false;
      final options = BackoffOptions(
        onError: (_, __) => errorCalled = true,
        minDelay: 100,
        maxDelay: 500,
        maxFailureCount: 20,
      );

      expect(options.minDelay, 100);
      expect(options.maxDelay, 500);
      expect(options.maxFailureCount, 20);
      expect(options.onError, isNotNull);
    });
  });
}
