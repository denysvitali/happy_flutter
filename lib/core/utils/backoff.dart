/// Exponential backoff utility for retry logic with jitter
///
/// Provides both the original ExponentialBackoff class and
/// backoff functions with exponential delay and retry capabilities.
library;

import 'dart:async';
import 'dart:math';

import '../services/logger_service.dart';

class ExponentialBackoff {

  ExponentialBackoff({
    required this.minDelayMs,
    required this.maxDelayMs,
    this.maxAttempts,
    this.factor = 2.0,
    this.jitter = 0.2,
  }) : _currentDelayMs = minDelayMs;
  /// Minimum delay in milliseconds
  final int minDelayMs;

  /// Maximum delay in milliseconds
  final int maxDelayMs;

  /// Maximum number of attempts (null for infinite)
  final int? maxAttempts;

  /// Factor by which to multiply delay each iteration
  final double factor;

  /// Random jitter factor (0.0 to 1.0)
  final double jitter;

  int _attempts = 0;
  int _currentDelayMs;

  /// Get current delay in milliseconds
  int get currentDelayMs => _currentDelayMs;

  /// Get current attempt number (0-indexed)
  int get attempts => _attempts;

  /// Check if more attempts are allowed
  bool get canRetry {
    if (maxAttempts == null) {
      return true;
    }
    return _attempts < maxAttempts!;
  }

  /// Get the next delay in milliseconds and advance to next attempt
  int next() {
    if (!canRetry) {
      throw StateError('No more retry attempts available');
    }

    final delay = _currentDelayMs;
    _attempts++;

    // Calculate next delay with exponential growth
    _currentDelayMs = (_currentDelayMs * factor).round();
    _currentDelayMs = _currentDelayMs.clamp(minDelayMs, maxDelayMs);

    // Apply jitter
    if (jitter == 0.0) {
      return delay;
    }
    final jitterAmount = (delay * jitter).round();
    final randomJitter =
        Random().nextInt(jitterAmount * 2 + 1) - jitterAmount;

    return delay + randomJitter;
  }

  /// Reset the backoff to initial state
  void reset() {
    _attempts = 0;
    _currentDelayMs = minDelayMs;
  }

  /// Create a backoff with preset values for WebSocket reconnection
  static ExponentialBackoff websocket({
    int minDelayMs = 1000,
    int maxDelayMs = 5000,
    int? maxAttempts,
  }) {
    return ExponentialBackoff(
      minDelayMs: minDelayMs,
      maxDelayMs: maxDelayMs,
      maxAttempts: maxAttempts,
    );
  }
}

// ============================================================================
// React Native-compatible backoff utilities
// ============================================================================

/// Minimum required CLI version for full compatibility
const String minimumCliVersion = '0.10.0';

/// Calculate exponential backoff delay with optional jitter.
///
/// [currentFailureCount] - Number of consecutive failures so far
/// [minDelay] - Minimum delay in milliseconds
/// [maxDelay] - Maximum delay in milliseconds
/// [maxFailureCount] - Maximum number of failures to consider
///
/// Returns the delay in milliseconds with random jitter
int exponentialBackoffDelay(
  int currentFailureCount,
  int minDelay,
  int maxDelay,
  int maxFailureCount,
) {
  final maxDelayRet = minDelay +
      ((maxDelay - minDelay) / maxFailureCount) *
          min(currentFailureCount, maxFailureCount).toDouble();
  return (Random().nextDouble() * maxDelayRet).round();
}

/// Callback type for backoff error handler
typedef BackoffErrorHandler = void Function(dynamic error, int failureCount);

/// Options for creating a backoff function
class BackoffOptions {

  const BackoffOptions({
    this.onError,
    this.minDelay = 250,
    this.maxDelay = 1000,
    this.maxFailureCount = 50,
  });
  /// Optional callback called on each error
  final BackoffErrorHandler? onError;

  /// Minimum delay in milliseconds (default: 250)
  final int minDelay;

  /// Maximum delay in milliseconds (default: 1000)
  final int maxDelay;

  /// Maximum number of failures before giving up (default: 50)
  final int maxFailureCount;
}

/// Type for a backoff-wrapped function
typedef BackoffFunc<T> = Future<T> Function(Future<T> Function() callback);

/// Creates a backoff function that retries with exponential delay.
///
/// The function will retry indefinitely until it succeeds, using exponential
/// backoff with jitter between retries.
///
/// [options] - Configuration options for the backoff behavior
///
/// Example:
/// ```dart
/// final withBackoff = createBackoff(
///   BackoffOptions(
///     minDelay: 100,
///     maxDelay: 500,
///     maxFailureCount: 10,
///     onError: (e, count) => print('Failed $count times: $e'),
///   ),
/// );
///
/// final result = await withBackoff(() => apiCall());
/// ```
BackoffFunc<T> createBackoff<T>(
  BackoffOptions options,
) {
  return (Future<T> Function() callback) async {
    var currentFailureCount = 0;
    final minDelay = options.minDelay;
    final maxDelay = options.maxDelay;
    final maxFailureCount = options.maxFailureCount;

    while (true) {
      try {
        return await callback();
      } catch (e) {
        if (currentFailureCount < maxFailureCount) {
          currentFailureCount++;
        }
        options.onError?.call(e, currentFailureCount);
        final waitForRequest = exponentialBackoffDelay(
          currentFailureCount,
          minDelay,
          maxDelay,
          maxFailureCount,
        );
        await Future<void>.delayed(Duration(milliseconds: waitForRequest));
      }
    }
  };
}

/// Attempt cap for the shared [backoff] helper.
///
/// [createBackoff] retries forever, which turns a permanently failing
/// callback (revoked token, removed endpoint) into an unbounded battery
/// drain. The shared helper is therefore built on
/// [createRetryingBackoff]: it eventually rethrows so the caller can
/// surface the failure.
const int backoffMaxRetries = 10;

/// A backoff function with default error logging that gives up after
/// [backoffMaxRetries] retries instead of looping forever.
final backoff = createRetryingBackoff<Object>(
  BackoffOptions(
    onError: (e, _) {
      logger.warning('Backoff retry: $e');
    },
  ),
  backoffMaxRetries,
);

/// A simpler exponential backoff that retries a fixed number of times.
///
/// Unlike [createBackoff], this version gives up after [maxRetries].
BackoffFunc<T> createRetryingBackoff<T>(
  BackoffOptions options,
  int maxRetries,
) {
  return (Future<T> Function() callback) async {
    var attempt = 0;
    final minDelay = options.minDelay;
    final maxDelay = options.maxDelay;

    while (true) {
      try {
        return await callback();
      } catch (e) {
        if (attempt >= maxRetries) {
          rethrow;
        }
        attempt++;
        options.onError?.call(e, attempt);
        final delay = exponentialBackoffDelay(
          attempt,
          minDelay,
          maxDelay,
          maxRetries,
        );
        await Future<void>.delayed(Duration(milliseconds: delay));
      }
    }
  };
}
