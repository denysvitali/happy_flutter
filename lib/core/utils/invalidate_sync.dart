import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/logger_service.dart';

/// A utility class for managing async operations with invalidation
class InvalidateSync {

  InvalidateSync(
    this._action, {
    Duration? minInterval,
    String? name,
  })  : _minInterval = minInterval,
        _name = name;
  final Future<void> Function() _action;
  final Duration? _minInterval;
  final String? _name;
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

  /// Whether the app is currently backgrounded. When true, all InvalidateSync
  /// instances skip running actions and cancel pending retry/cooldown timers.
  /// This is a static/shared flag so that any instance can check it without
  /// needing a reference to the Sync singleton.
  static bool isBackgrounded = false;

  /// Diagnostic counter — incremented every time an operation is skipped in
  /// _run() because isBackgrounded is true.  If this grows quickly, it means
  /// the app is cycling between foreground and background repeatedly, which is
  /// a battery drain indicator.
  @visibleForTesting
  static int backgroundedSkipCount = 0;

  /// Invalidate the current operation and schedule a retry
  void invalidate() {
    _invalidated = true;

    // Always ensure a Completer exists so that awaitQueue() callers
    // block until the invalidated work actually completes — even if
    // the run is deferred by a cooldown timer or is already in flight.
    _currentOperation ??= Completer<void>();

    if (_running || _cooldownTimer != null) {
      return;
    }

    // Enforce minimum interval between the end of one run and the
    // start of the next to avoid rapid-fire back-to-back fetches.
    if (_minInterval != null && _lastRunEnd != null) {
      final elapsed = DateTime.now().difference(_lastRunEnd!);
      if (elapsed < _minInterval) {
        final remaining = _minInterval - elapsed;
        _cooldownTimer?.cancel();
        _cooldownTimer = Timer(remaining, () {
          _cooldownTimer = null;
          // Don't re-trigger if backgrounded — let the next resume cycle
          // handle it so we don't wake the app from background.
          if (_invalidated && !isBackgrounded) {
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
    // Skip if backgrounded — don't perform any network I/O while the app is
    // not visible.  This guards against the case where resume() triggers a sync
    // but the OS immediately backgrounds the app again before the action runs.
    if (isBackgrounded) {
      backgroundedSkipCount++;
      _running = false;
      return;
    }

    _running = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _invalidated = false;

    // Start a transaction for this sync operation to capture it in
    // performance monitoring, not just as a breadcrumb attached to errors.
    final transaction = Sentry.startTransaction(
      'sync.invalidate.${_name ?? 'unknown'}',
      'sync.fetch',
      bindToScope: false,
    )..setData('name', _name ?? 'unknown');

    try {
      await _action();

      await transaction.finish();

      // Add breadcrumb for successful completion
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'InvalidateSync action completed',
        category: 'sync.retry',
        level: SentryLevel.info,
        data: {
          'name': _name ?? 'unknown',
          'retryCount': _retryCount,
        },
      ));
    } catch (error, stackTrace) {
      await transaction.finish(
        status: const SpanStatus.internalError(),
      );

      _retryCount++;
      if (_retryCount <= maxRetries) {
        _scheduleRetry();
      } else {
        final operation = _currentOperation;
        _currentOperation = null;
        _running = false;
        if (operation != null && !operation.isCompleted) {
          logger.error('InvalidateSync: max retries exceeded', error);
          // Add breadcrumb for max retries exceeded
          Sentry.addBreadcrumb(Breadcrumb(
            message: 'InvalidateSync max retries exceeded',
            category: 'sync.retry',
            level: SentryLevel.error,
            data: {
              'name': _name ?? 'unknown',
              'error': error.toString(),
            },
          ));
          // Capture the final error to Sentry
          unawaited(Sentry.captureException(
            error,
            stackTrace: stackTrace,
            hint: Hint.withMap({
              'name': _name ?? 'unknown',
              'retryCount': _retryCount,
            }),
          ));
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
    // Don't schedule retries if backgrounded — they will be re-triggered on
    // resume via invalidate() if still needed.
    if (isBackgrounded) return;

    final delay = (baseDelayMs * pow(2, _retryCount - 1)).toInt();
    final jitter = _jitterRng.nextInt(251); // 0–250ms
    final clampedDelay = min(delay + jitter, maxDelayMs);
    logger.debug(
      'InvalidateSync: retry $_retryCount in ${clampedDelay}ms',
    );

    // Add Sentry breadcrumb for retry tracking
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'InvalidateSync retry scheduled',
      category: 'sync.retry',
      level: SentryLevel.warning,
      data: {
        'name': _name ?? 'unknown',
        'retryCount': _retryCount,
        'delayMs': clampedDelay,
        'maxRetries': maxRetries,
      },
    ));

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
