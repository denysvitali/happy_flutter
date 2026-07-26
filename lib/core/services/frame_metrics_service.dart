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

  /// The `ui.jank` span for the current window, opened by the first frozen
  /// frame and closed at the next flush.
  ///
  /// The span used to be started and ended in the same statement, which gave
  /// it a duration of zero — `traces_span_metrics_duration_seconds{span_name=
  /// "ui.jank"}` was therefore meaningless and the entire payload lived in
  /// attributes. Spanning the real jank episode makes the duration usable.
  OTelSpan? _jankSpan;
  DateTime? _jankSpanStartedAt;
  Duration? _lastJankWindow;

  @visibleForTesting
  bool get debugIsAttached => _attached;

  /// Duration covered by the most recently emitted `ui.jank` span.
  @visibleForTesting
  Duration? get debugLastJankWindow => _lastJankWindow;

  @visibleForTesting
  void debugFlush() => _flush();

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
      _openJankSpan();
    }
  }

  /// Open the jank span on the first frozen frame of a window so it covers
  /// the episode rather than an instant. Cheap: at most one span per flush
  /// interval, and a no-op while OTel is still initialising.
  void _openJankSpan() {
    if (_jankSpan != null) return;
    _jankSpanStartedAt = DateTime.now();
    _jankSpan = OpenTelemetryService().startTrace(
      'ui.jank',
      attributes: {
        // Stamped at the moment the jank happened, not at flush time — the
        // user may well have navigated away by then.
        'current_route': PerformanceContextService().currentRoute ?? 'unknown',
      },
    );
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
    final jankSpan = _jankSpan;
    final jankStartedAt = _jankSpanStartedAt;
    _jankSpan = null;
    _jankSpanStartedAt = null;
    _lastJankWindow = null;
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

    if (snapshot.isEmpty) {
      // Defensive: the span is only opened alongside a jank sample, but never
      // leak an unended span if that ever stops holding.
      jankSpan?.end();
      return;
    }

    final avgMs = snapshot.reduce((a, b) => a + b) / snapshot.length;
    final maxMs = snapshot.reduce((a, b) => a > b ? a : b);
    final window = jankStartedAt == null
        ? null
        : DateTime.now().difference(jankStartedAt);
    _lastJankWindow = window;

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

    if (window != null) {
      otel.recordDuration(
        'app.ui.jank_window',
        window,
        attributes: attributes,
        description: 'Length of a janky-frame episode',
      );
    }

    // The span was opened by the first frozen frame of this window (see
    // [_openJankSpan]), so it carries a real duration. Correlating counts go
    // on at close, when they are known.
    jankSpan
      ?..setAttribute('frame.count', snapshot.length)
      ..setAttribute('frame.avg_ms', avgMs.round())
      ..setAttribute('frame.max_ms', maxMs)
      ..setAttribute('frame.frozen_count', frozenFrameCount)
      ..setAttribute('frame.slow_count', slowFrameCount)
      ..setAttribute('frame.window_count', frameCount)
      ..setAttribute('route.at_flush', route)
      ..end();
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
