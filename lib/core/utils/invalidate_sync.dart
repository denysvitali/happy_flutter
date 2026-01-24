import 'dart:async';
import 'dart:math';

/// A utility class for managing async operations with invalidation and exponential backoff
class InvalidateSync {
  final Future<void> Function() _action;
  final Completer<void> _currentOperation = Completer<void>();
  bool _invalidated = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  // Exponential backoff configuration
  static const int baseDelayMs = 1000;
  static const int maxDelayMs = 5000;
  static const int maxRetries = 5;

  InvalidateSync(this._action);

  /// Invalidate the current operation and schedule a retry
  void invalidate() {
    if (_currentOperation.isCompleted) {
      _run();
    } else {
      _invalidated = true;
    }
  }

  /// Invalidate and await the operation
  Future<void> invalidateAndAwait() async {
    invalidate();
    await _currentOperation.future;
  }

  /// Await the current operation
  Future<void> awaitQueue() async {
    if (_currentOperation.isCompleted) {
      return;
    }
    await _currentOperation.future;
  }

  Future<void> _run() async {
    _invalidated = false;
    try {
      await _action();
    } catch (error) {
      _retryCount++;
      if (_retryCount <= maxRetries) {
        _scheduleRetry();
      } else {
        _currentOperation.completeError(error);
      }
      return;
    }

    if (_invalidated) {
      _run();
    } else {
      _currentOperation.complete();
    }
  }

  void _scheduleRetry() {
    final delay = baseDelayMs * pow(2, _retryCount - 1).toInt();
    final clampedDelay = min(delay, maxDelayMs);

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: clampedDelay), () {
      _run();
    });
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
  }
}
