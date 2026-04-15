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
  bool _disposed = false;
  int _retryCount = 0;
  Timer? _retryTimer;
  Timer? _cooldownTimer;
  DateTime? _lastRunEnd;

  /// When the last operation completed. Used by Sync to evict stale
  /// per-session InvalidateSync entries and prevent unbounded growth.
  int? get lastRunEndMs => _lastRunEnd?.millisecondsSinceEpoch;

  // Exponential backoff configuration
  static const int baseDelayMs = 1000;
  static const int maxDelayMs = 5000;
  // Reduced from 5 to 2: the Dio retry interceptor already handles 4
  // retries at the HTTP layer, so 2 additional InvalidateSync retries
  // (total 6) is sufficient.  Excessive retries prolong delivery delays
  // and drain battery on mobile networks.
  static const int maxRetries = 2;

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

    // Revive a disposed instance so it can accept new invalidations after
    // suspend/resume.  Without this, if dispose() was called while an operation
    // was in-flight (leaving _running=true) or while a retry timer was pending,
    // the next invalidate() would skip because _running is stuck true.
    // This can happen when suspend() disposes all InvalidateSync instances
    // while background network requests are still in-flight.
    //
    // CRITICAL: Reset ALL state that could block a new operation BEFORE
    // creating a new _currentOperation completer. The old completer may have
    // an in-flight _run() that races with the revived one.
    if (_disposed) {
      _disposed = false;
      _running = false;
      _retryCount = 0;
      _lastRunEnd = null;
      // Complete any orphaned completer from the disposed run normally so
      // that awaitQueue() callers are silently unblocked.  Using
      // completeError here previously caused unhandled StateError crashes
      // in callers that don't wrap the await in try/catch.
      final oldOp = _currentOperation;
      _currentOperation = null;
      if (oldOp != null && !oldOp.isCompleted) {
        oldOp.complete();
      }
    }

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
    _retryCount = 0;
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
    // Skip if disposed — the instance was torn down while we were waiting for
    // the microtask/timer queue.  Complete any pending operation so callers
    // are not left hanging, then bail out silently.
    if (_disposed) {
      _running = false;
      _completeOperation();
      return;
    }

    // Skip if backgrounded — don't perform any network I/O while the app is
    // not visible.  This guards against the case where resume() triggers a sync
    // but the OS immediately backgrounds the app again before the action runs.
    // We complete the operation so that any callers awaiting awaitQueue() are
    // unblocked rather than hanging forever.
    if (isBackgrounded) {
      backgroundedSkipCount++;
      _running = false;
      _completeOperation();
      return;
    }

    _running = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _invalidated = false;

    // Start a transaction for this sync operation to capture it in
    // performance monitoring, not just as a breadcrumb attached to errors.
    final rawName = _name ?? 'unknown';
    final normalizedName = rawName.split(':').first;
    final transaction = Sentry.startTransaction(
      'sync.invalidate.$normalizedName',
      'sync.fetch',
      bindToScope: false,
    )
      ..setData('name', rawName)
      ..setData('normalizedName', normalizedName)
      ..setData('hasDynamicSuffix', rawName != normalizedName);

    try {
      await _action();

      await transaction.finish();

      // Add breadcrumb for successful completion
      unawaited(Sentry.addBreadcrumb(Breadcrumb(
        message: 'InvalidateSync action completed',
        category: 'sync.retry',
        level: SentryLevel.info,
        data: {
          'name': _name ?? 'unknown',
          'retryCount': _retryCount,
        },
      )));
    } catch (error) {
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
          // logger.error already forwards to Sentry via
          // _forwardToSentry — no need for a separate captureException.
          logger.error('InvalidateSync: max retries exceeded', error);
          unawaited(Sentry.addBreadcrumb(Breadcrumb(
            message: 'InvalidateSync max retries exceeded',
            category: 'sync.retry',
            level: SentryLevel.error,
            data: {
              'name': _name ?? 'unknown',
              'error': error.toString(),
            },
          )));
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
    // Don't schedule retries if disposed — the instance has been torn down
    // and any pending completer was already completed by dispose().  Creating
    // a timer here would leak a stale _run() call into the next login cycle.
    if (_disposed) return;

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

  /// Quiesce lifecycle timers without tearing down the sync instance.
  ///
  /// App backgrounding is temporary, so we must not switch the instance into
  /// the disposed state used by logout/shutdown. Doing so causes later resume
  /// invalidations to race with screens still awaiting the old instance and can
  /// surface as "InvalidateSync disposed" failures.
  void suspend() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;

    // If work was only waiting on a cooldown/retry timer, complete the current
    // awaiters normally so lifecycle suspend does not leak a stale pending
    // future into foreground recovery.
    if (!_running) {
      final op = _currentOperation;
      _currentOperation = null;
      if (op != null && !op.isCompleted) {
        op.complete();
      }
    }
  }

  /// Dispose resources.
  ///
  /// Completes any pending operation **normally** so that callers awaiting
  /// [awaitQueue] are silently unblocked.  Disposal during app suspend is an
  /// expected lifecycle event — propagating an error would surface as an
  /// unhandled StateError crash in every caller that doesn't wrap the await
  /// in a try/catch (which is most of them).
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _cooldownTimer?.cancel();
    final op = _currentOperation;
    _currentOperation = null;
    if (op != null && !op.isCompleted) {
      op.complete();
    }
  }
}
