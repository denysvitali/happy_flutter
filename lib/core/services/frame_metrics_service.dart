import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'logger_service.dart';
import 'opentelemetry_service.dart';
import 'performance_context_service.dart';

/// Reports janky Flutter frames to Sentry/GlitchTip as performance
/// transactions so that UI lag is visible in the dashboard alongside
/// sync and network transactions.
///
/// Every frame contributes to aggregate build/raster histograms. Frames over
/// the 60 Hz budget are counted as slow; only 100ms+ frozen frames create a
/// Sentry transaction so ordinary marginal jank does not flood issue tracking.
class FrameMetricsService {
  FrameMetricsService._();
  static final FrameMetricsService instance = FrameMetricsService._();

  bool _attached = false;
  bool _enableSentryTransactions = false;
  Timer? _flushTimer;

  /// Ring buffer of recent janky frame durations (ms).
  final _recentJank = <int>[];
  static const int _maxJankBuffer = 50;
  static const int _slowFrameMicros = 16667;
  static const int _frozenFrameMicros = 100000;

  int _frameCount = 0;
  int _slowFrameCount = 0;
  int _frozenFrameCount = 0;
  int _buildMicros = 0;
  int _rasterMicros = 0;
  int _totalMicros = 0;

  @visibleForTesting
  bool get debugIsAttached => _attached;

  @visibleForTesting
  bool get debugHasFlushTimer => _flushTimer?.isActive ?? false;

  @visibleForTesting
  int get debugFrameCount => _frameCount;

  @visibleForTesting
  int get debugSlowFrameCount => _slowFrameCount;

  @visibleForTesting
  int get debugFrozenFrameCount => _frozenFrameCount;

  /// Attach to [SchedulerBinding] frame timing callbacks.
  void attach({bool enableSentryTransactions = false}) {
    _enableSentryTransactions = enableSentryTransactions;
    if (_attached) return;
    _attached = true;

    SchedulerBinding.instance.addTimingsCallback(_onTimings);

    // Periodically flush accumulated jank stats as a single Sentry
    // transaction instead of one per frame.
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => _flush());

    if (kDebugMode) {
      logger.debug('[FrameMetrics] Attached');
    }
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _recordFrame(
        buildMicros: t.buildDuration.inMicroseconds,
        rasterMicros: t.rasterDuration.inMicroseconds,
        totalMicros: t.totalSpan.inMicroseconds,
      );
    }
  }

  void _recordFrame({
    required int buildMicros,
    required int rasterMicros,
    required int totalMicros,
  }) {
    _frameCount++;
    _buildMicros += buildMicros;
    _rasterMicros += rasterMicros;
    _totalMicros += totalMicros;
    if (totalMicros >= _slowFrameMicros) _slowFrameCount++;
    if (totalMicros >= _frozenFrameMicros) {
      _frozenFrameCount++;
      _recentJank.add((totalMicros / 1000).round());
      if (_recentJank.length > _maxJankBuffer) {
        _recentJank.removeAt(0);
      }
    }
  }

  @visibleForTesting
  void testRecordFrame({
    required Duration build,
    required Duration raster,
    required Duration total,
  }) {
    _recordFrame(
      buildMicros: build.inMicroseconds,
      rasterMicros: raster.inMicroseconds,
      totalMicros: total.inMicroseconds,
    );
  }

  void _flush() {
    if (_frameCount == 0) return;

    final snapshot = List<int>.from(_recentJank);
    _recentJank.clear();
    final frameCount = _frameCount;
    final slowFrameCount = _slowFrameCount;
    final frozenFrameCount = _frozenFrameCount;
    final avgBuild = Duration(microseconds: _buildMicros ~/ frameCount);
    final avgRaster = Duration(microseconds: _rasterMicros ~/ frameCount);
    final avgTotal = Duration(microseconds: _totalMicros ~/ frameCount);
    _frameCount = 0;
    _slowFrameCount = 0;
    _frozenFrameCount = 0;
    _buildMicros = 0;
    _rasterMicros = 0;
    _totalMicros = 0;

    final route = PerformanceContextService().currentRoute ?? 'unknown';
    final otel = OpenTelemetryService();
    final attributes = <String, Object?>{'current_route': route};
    otel
      ..recordDuration('app.ui.frame_build', avgBuild, attributes: attributes)
      ..recordDuration('app.ui.frame_raster', avgRaster, attributes: attributes)
      ..recordDuration('app.ui.frame_total', avgTotal, attributes: attributes)
      ..recordCount(
        'app.ui.frames',
        value: frameCount,
        attributes: {...attributes, 'classification': 'total'},
      )
      ..recordCount(
        'app.ui.frames',
        value: slowFrameCount,
        attributes: {...attributes, 'classification': 'slow'},
      )
      ..recordCount(
        'app.ui.frames',
        value: frozenFrameCount,
        attributes: {...attributes, 'classification': 'frozen'},
      );

    if (snapshot.isEmpty) return;

    final avgMs = snapshot.reduce((a, b) => a + b) / snapshot.length;
    final maxMs = snapshot.reduce((a, b) => a > b ? a : b);

    if (_enableSentryTransactions) {
      final transaction =
          Sentry.startTransaction('ui.jank', 'ui.frame', bindToScope: false)
            ..setData('count', snapshot.length)
            ..setData('avgMs', avgMs.round())
            ..setData('maxMs', maxMs)
            ..setData(
              'currentRoute',
              PerformanceContextService().currentRoute ?? 'unknown',
            );

      unawaited(transaction.finish());
    }

    OpenTelemetryService()
        .startTrace(
          'ui.jank',
          attributes: {
            'frame.count': snapshot.length,
            'frame.avg_ms': avgMs.round(),
            'frame.max_ms': maxMs,
            'current_route': route,
          },
        )
        ?.end();
  }

  /// Detach and clean up. Call on app dispose.
  void detach() {
    if (!_attached) return;
    _attached = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _flushTimer?.cancel();
    _flushTimer = null;
    _flush();
    if (kDebugMode) {
      logger.debug('[FrameMetrics] Detached');
    }
  }
}
