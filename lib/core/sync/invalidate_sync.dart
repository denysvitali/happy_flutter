import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/failure_telemetry.dart';
import '../services/logger_service.dart';
import '../services/power_diagnostics_service.dart';

/// A utility class for managing async operations with invalidation
class InvalidateSync {
  InvalidateSync(
    this._action, {
    Duration? minInterval,
    String? name,
    void Function(String? name, bool isRunning)? onRunningChanged,
    int? maxRetries,
  }) : _minInterval = minInterval,
       _name = name,
       _onRunningChanged = onRunningChanged,
       _maxRetries = maxRetries ?? defaultMaxRetries;
  final Future<void> Function() _action;
  final Duration? _minInterval;
  final String? _name;
  final void Function(String? name, bool isRunning)? _onRunningChanged;
  final int _maxRetries;
  Completer<void>? _currentOperation;
  bool _invalidated = false;
  bool _running = false;
  bool _disposed = false;
  int _retryCount = 0;
  int _runGeneration = 0;
  Timer? _retryTimer;
  Timer? _cooldownTimer;
  DateTime? _lastRunEnd;
  DateTime? _lastSuccessAt;
  DateTime? _lastFailureAt;
  String? _lastFailureKind;

  /// When the last operation completed. Used by Sync to evict stale
  /// per-session InvalidateSync entries and prevent unbounded growth.
  int? get lastRunEndMs => _lastRunEnd?.millisecondsSinceEpoch;

  /// Redacted health metadata. Failure detail is reduced to the bounded
  /// [classifySyncFailureReason] vocabulary; raw exception text never escapes.
  int? get lastSuccessAtMs => _lastSuccessAt?.millisecondsSinceEpoch;
  int? get lastFailureAtMs => _lastFailureAt?.millisecondsSinceEpoch;
  String? get lastFailureKind => _lastFailureKind;

  // Exponential backoff configuration
  static const int baseDelayMs = 1000;
  static const int maxDelayMs = 5000;
  // Reduced from 5 to 2: for routes that go through the Dio retry
  // interceptor (4 retries at the HTTP layer), 2 additional InvalidateSync
  // retries (total 6) is sufficient.  Excessive retries prolong delivery
  // delays and drain battery on mobile networks.
  //
  // CAUTION: routes that opt out with `extra: {'disableRetry': true}` — the
  // message-page fetches in `_sync_messaging.dart` do — get NO HTTP-layer
  // retry at all, so this class is their only recovery layer.  Never pass
  // `maxRetries: 0` for those; see `Sync._messagesSyncMaxRetries`.
  static const int defaultMaxRetries = 2;

  /// Whether the app is currently backgrounded. When true, all InvalidateSync
  /// instances skip running actions and cancel pending retry/cooldown timers.
  /// This is a static/shared flag so that any instance can check it without
  /// needing a reference to the Sync singleton.
  static bool isBackgrounded = false;

  /// How many times a failed action is retried before giving up.
  int get maxRetries => _maxRetries;

  /// Whether a sync action is currently executing.
  bool get isRunning => _running;

  /// Whether a sync is pending (either in-flight or awaiting cooldown).
  bool get isPending =>
      _currentOperation != null ||
      _invalidated ||
      _retryTimer != null ||
      _cooldownTimer != null;

  /// Diagnostic counter — incremented every time an operation is skipped in
  /// _run() because isBackgrounded is true.  If this grows quickly, it means
  /// the app is cycling between foreground and background repeatedly, which is
  /// a battery drain indicator.
  @visibleForTesting
  static int backgroundedSkipCount = 0;

  /// Invalidate the current operation and schedule a retry
  void invalidate() {
    // dispose() is teardown-only and terminal. Temporary lifecycle pauses use
    // suspend(), while a new account constructs fresh managers. Reviving a
    // disposed instance lets an old account's in-flight work race the new
    // runtime and resurrect cleared state.
    if (_disposed) return;
    _invalidated = true;

    // Always ensure a Completer exists so that awaitQueue() callers
    // block until the invalidated work actually completes — even if
    // the run is deferred by a cooldown timer or is already in flight.
    if (_currentOperation == null) {
      final operation = Completer<void>();
      _currentOperation = operation;
      // `invalidate()` is intentionally fire-and-forget in many call sites.
      // Keep errors observable via awaitQueue(), but attach a listener so a
      // caller that does not await does not surface a handled sync failure as
      // an uncaught async error.
      unawaited(operation.future.catchError((Object _) {}));
    }

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
    unawaited(_run(_runGeneration));
  }

  void _setRunning(bool value) {
    if (_running != value) {
      _running = value;
      _onRunningChanged?.call(_name, value);
    }
  }

  void _completeOperation() {
    _setRunning(false);
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

  Future<void> _run(int generation) async {
    if (generation != _runGeneration) return;

    // Skip if disposed — the instance was torn down while we were waiting for
    // the microtask/timer queue.  Complete any pending operation so callers
    // are not left hanging, then bail out silently.
    if (_disposed) {
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
      powerDiagnostics.recordSyncBackgroundSkip(_name ?? 'unknown');
      _completeOperation();
      return;
    }

    _setRunning(true);
    _retryTimer?.cancel();
    _retryTimer = null;
    _invalidated = false;

    // Start a transaction for this sync operation to capture it in
    // performance monitoring, not just as a breadcrumb attached to errors.
    final rawName = _name ?? 'unknown';
    final normalizedName = rawName.split(':').first;
    final transaction =
        Sentry.startTransaction(
            'sync.invalidate.$normalizedName',
            'sync.fetch',
            bindToScope: false,
          )
          ..setData('name', rawName)
          ..setData('normalizedName', normalizedName)
          ..setData('hasDynamicSuffix', rawName != normalizedName);

    try {
      await _action();

      _lastSuccessAt = DateTime.now();

      await transaction.finish();

      if (generation != _runGeneration) return;

      // Add breadcrumb for successful completion
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'InvalidateSync action completed',
            category: 'sync.retry',
            level: SentryLevel.info,
            data: {'name': _name ?? 'unknown', 'retryCount': _retryCount},
          ),
        ),
      );
    } catch (error) {
      _lastFailureAt = DateTime.now();
      _lastFailureKind = classifySyncFailureReason(error);
      await transaction.finish(status: const SpanStatus.internalError());

      if (generation != _runGeneration) return;

      _retryCount++;
      if (_retryCount <= _maxRetries) {
        _scheduleRetry();
      } else {
        final operation = _currentOperation;
        _currentOperation = null;
        _setRunning(false);
        // Stamp the run end on the failure path too.  Without this,
        // [_minInterval] only throttles *successful* cycles: a run that
        // exhausts its retries left _lastRunEnd at its previous value (often
        // null), so the very next invalidate() started a fresh action
        // immediately.  A failing endpoint therefore got hammered at the
        // caller's invalidation rate instead of the configured minimum.
        _lastRunEnd = DateTime.now();
        // IMPORTANT: Check _invalidated AFTER completing the error path.
        // If a new invalidation arrived during the retry storm, we must
        // start a fresh cycle rather than dropping it silently.
        // Previously this was the root cause of 2+ minute dead zones
        // where settings/profile syncs went dormant after timeout cascades.
        final needsReinvalidate = _invalidated;
        if (operation != null && !operation.isCompleted) {
          // logger.error already forwards to Sentry via
          // _forwardToSentry — no need for a separate captureException.
          logger.error('InvalidateSync: max retries exceeded', error);
          // `normalizedName` is the name with any dynamic suffix
          // (`messages:<sessionId>`) stripped — the same bounded value
          // already used as the Sentry transaction name. Never the raw
          // name, which carries a session id.
          recordSyncFailure(
            domain: normalizedName,
            reason: _disposed
                ? kReasonDisposed
                : classifySyncFailureReason(error),
          );
          unawaited(
            Sentry.addBreadcrumb(
              Breadcrumb(
                message: 'InvalidateSync max retries exceeded',
                category: 'sync.retry',
                level: SentryLevel.error,
                data: {'name': _name ?? 'unknown', 'error': error.toString()},
              ),
            ),
          );
          operation.completeError(error);
        }
        // Start a fresh cycle if a new invalidation arrived during retry.
        // Re-enter through invalidate() (rather than calling _run directly)
        // so the [_minInterval] cooldown stamped above is honoured — a
        // failing endpoint must not be re-hit back-to-back.
        if (needsReinvalidate) {
          _retryCount = 0;
          _invalidated = false;
          invalidate();
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
    // resume via invalidate() if still needed.  Complete the pending operation
    // first: without this, every awaitQueue() caller blocks until the next
    // foreground invalidate() creates and finishes a new cycle, which can be
    // minutes away (or never, if the screen was popped).  This mirrors the
    // backgrounded skip in [_run].
    if (isBackgrounded) {
      backgroundedSkipCount++;
      powerDiagnostics.recordSyncBackgroundSkip(_name ?? 'unknown');
      _completeOperation();
      return;
    }

    final delay = (baseDelayMs * pow(2, _retryCount - 1)).toInt();
    final jitter = _jitterRng.nextInt(251); // 0–250ms
    final clampedDelay = min(delay + jitter, maxDelayMs);
    logger.debug('InvalidateSync: retry $_retryCount in ${clampedDelay}ms');

    // Add Sentry breadcrumb for retry tracking
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'InvalidateSync retry scheduled',
        category: 'sync.retry',
        level: SentryLevel.warning,
        data: {
          'name': _name ?? 'unknown',
          'retryCount': _retryCount,
          'delayMs': clampedDelay,
          'maxRetries': _maxRetries,
        },
      ),
    );

    _retryTimer?.cancel();
    final generation = _runGeneration;
    _retryTimer = Timer(Duration(milliseconds: clampedDelay), () {
      unawaited(_run(generation));
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
    _runGeneration++;

    // Complete awaiters and mark the manager idle even if the underlying
    // action is still awaiting a platform/network timeout. Android Cronet can
    // leave those requests alive for tens of seconds after backgrounding; if
    // _running stays true, the next foreground invalidate() is ignored and the
    // app appears stuck syncing until the old request finally unwinds.
    _invalidated = false;
    _setRunning(false);
    final op = _currentOperation;
    _currentOperation = null;
    if (op != null && !op.isCompleted) {
      op.complete();
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
    _runGeneration++;
    _retryTimer?.cancel();
    _cooldownTimer?.cancel();
    _setRunning(false);
    final op = _currentOperation;
    _currentOperation = null;
    if (op != null && !op.isCompleted) {
      op.complete();
    }
  }
}
