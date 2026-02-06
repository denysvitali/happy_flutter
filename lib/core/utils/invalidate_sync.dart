import 'dart:async';
import 'dart:math';

/// A utility class for managing async operations with invalidation and exponential backoff
class InvalidateSync {
  final Future<void> Function() _action;
  Completer<void>? _currentOperation;
  bool _invalidated = false;
  bool _running = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  // Exponential backoff configuration
  static const int baseDelayMs = 1000;
  static const int maxDelayMs = 5000;
  static const int maxRetries = 5;

  InvalidateSync(this._action);

  /// Invalidate the current operation and schedule a retry
  void invalidate() {
    _invalidated = true;

    if (_running) {
      return;
    }

    _currentOperation ??= Completer<void>();
    unawaited(_run());
  }

  void _completeOperation() {
    _running = false;
    _retryCount = 0;
    final operation = _currentOperation;
    _currentOperation = null;
    if (operation != null && !operation.isCompleted) {
      operation.complete();
    }
  }

  /// Invalidate and await the operation
  Future<void> invalidateAndAwait() async {
    invalidate();
    await awaitQueue();
  }

  /// Await the current operation
  Future<void> awaitQueue() async {
    final operation = _currentOperation;
    if (operation == null) {
      return;
    }
    await operation.future;
  }

  Future<void> _run() async {
    _running = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _invalidated = false;

    try {
      await _action();
    } catch (error) {
      _retryCount++;
      if (_retryCount <= maxRetries) {
        _scheduleRetry();
      } else {
        final operation = _currentOperation;
        _currentOperation = null;
        _running = false;
        if (operation != null && !operation.isCompleted) {
          operation.completeError(error);
        }
      }
      return;
    }

    if (_invalidated) {
      unawaited(_run());
    } else {
      _completeOperation();
    }
  }

  void _scheduleRetry() {
    final delay = baseDelayMs * pow(2, _retryCount - 1).toInt();
    final clampedDelay = min(delay, maxDelayMs);

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: clampedDelay), () {
      unawaited(_run());
    });
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
  }
}
