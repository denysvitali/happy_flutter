import 'dart:async';
import 'dart:math';

import '../services/logger_service.dart';

/// A utility class for managing async operations with invalidation
class InvalidateSync {

  InvalidateSync(this._action, {Duration? minInterval})
      : _minInterval = minInterval;
  final Future<void> Function() _action;
  final Duration? _minInterval;
  Completer<void>? _currentOperation;
  bool _invalidated = false;
  bool _running = false;
  int _retryCount = 0;
  Timer? _retryTimer;
  Timer? _cooldownTimer;
  DateTime? _lastRunEnd;

  // Exponential backoff configuration
  static const int baseDelayMs = 1000;
  static const int maxDelayMs = 5000;
  static const int maxRetries = 5;

  /// Invalidate the current operation and schedule a retry
  void invalidate() {
    _invalidated = true;

    if (_running || _cooldownTimer != null) {
      return;
    }

    // Enforce minimum interval between the end of one run and the
    // start of the next to avoid rapid-fire back-to-back fetches.
    if (_minInterval != null && _lastRunEnd != null) {
      final elapsed = DateTime.now().difference(_lastRunEnd!);
      if (elapsed < _minInterval) {
        final remaining = _minInterval - elapsed;
        _cooldownTimer = Timer(remaining, () {
          _cooldownTimer = null;
          if (_invalidated) {
            _invalidated = false;
            invalidate();
          }
        });
        return;
      }
    }

    // Reset retry count when starting a fresh operation so that
    // a previously-exhausted InvalidateSync can recover on the
    // next call (e.g. after a socket reconnect).
    if (_currentOperation == null) {
      _retryCount = 0;
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
          logger.error('InvalidateSync: max retries exceeded', error);
          operation.completeError(error);
        }
      }
      return;
    }

    // Always complete the current Completer so that any pending
    // `invalidateAndAwait()` callers are unblocked — their "run at least
    // once" contract is now satisfied.  If a new invalidation arrived
    // while the action was running, start a fresh cycle for it with a
    // brand-new Completer so new callers can await that cycle separately.
    _lastRunEnd = DateTime.now();
    _completeOperation();
    if (_invalidated) {
      // Re-enter through invalidate() so the cooldown logic is applied.
      invalidate();
    }
  }

  static final Random _jitterRng = Random();

  void _scheduleRetry() {
    final delay = (baseDelayMs * pow(2, _retryCount - 1)).toInt();
    final jitter = _jitterRng.nextInt(251); // 0–250ms
    final clampedDelay = min(delay + jitter, maxDelayMs);
    logger.debug(
      'InvalidateSync: retry $_retryCount in ${clampedDelay}ms',
    );

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(milliseconds: clampedDelay), () {
      unawaited(_run());
    });
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _cooldownTimer?.cancel();
  }
}
