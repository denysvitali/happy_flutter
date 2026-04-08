import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'logger_service.dart';
import 'performance_context_service.dart';

/// Reports janky Flutter frames to Sentry/GlitchTip as performance
/// transactions so that UI lag is visible in the dashboard alongside
/// sync and network transactions.
///
/// A frame is considered janky when it exceeds 16ms (60 fps budget)
/// *and* the user would notice — we use 100ms as the reporting
/// threshold to avoid flooding Sentry with marginal slow frames.
class FrameMetricsService {
  FrameMetricsService._();
  static final FrameMetricsService instance = FrameMetricsService._();

  bool _attached = false;
  Timer? _flushTimer;

  /// Ring buffer of recent janky frame durations (ms).
  final _recentJank = <int>[];
  static const int _maxJankBuffer = 50;

  /// Attach to [SchedulerBinding] frame timing callbacks.
  void attach() {
    if (_attached) return;
    _attached = true;

    SchedulerBinding.instance.addTimingsCallback(_onTimings);

    // Periodically flush accumulated jank stats as a single Sentry
    // transaction instead of one per frame.
    _flushTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _flush(),
    );

    logger.debug('[FrameMetrics] Attached');
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final totalMs = t.totalSpan.inMilliseconds;
      // Only record frames exceeding 100ms — these are the ones users
      // actually perceive as lag.
      if (totalMs >= 100) {
        _recentJank.add(totalMs);
        if (_recentJank.length > _maxJankBuffer) {
          _recentJank.removeAt(0);
        }
      }
    }
  }

  void _flush() {
    if (_recentJank.isEmpty) return;

    final snapshot = List<int>.from(_recentJank);
    _recentJank.clear();

    final avgMs =
        snapshot.reduce((a, b) => a + b) / snapshot.length;
    final maxMs =
        snapshot.reduce((a, b) => a > b ? a : b);

    final transaction = Sentry.startTransaction(
      'ui.jank',
      'ui.frame',
      bindToScope: false,
    )
      ..setData('count', snapshot.length)
      ..setData('avgMs', avgMs.round())
      ..setData('maxMs', maxMs)
      ..setData(
        'currentRoute',
        PerformanceContextService().currentRoute ?? 'unknown',
      );

    unawaited(transaction.finish());
  }

  /// Detach and clean up. Call on app dispose.
  void detach() {
    if (!_attached) return;
    _attached = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    _flush();
    logger.debug('[FrameMetrics] Detached');
  }
}
