import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../utils/performance_buckets.dart';
import 'logger_service.dart';
import 'opentelemetry_service.dart';
import 'performance_context_service.dart';
import 'sync_service.dart';

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

  /// Ring buffer of recent frozen frames, including the build/raster split.
  final _recentFrozenFrames = <_FrozenFrameSample>[];
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

  /// Route known when the current jank span was opened, or null when none was
  /// (start-up, mid-transition). Drives the flush-time backfill in [_flush].
  String? _jankSpanRoute;
  String? _jankSessionsView;
  int? _jankSessionCount;

  /// Route the last emitted `ui.jank` span was attributed to.
  String? _lastJankRoute;

  /// Latches on the first frozen frame of a window, independently of whether
  /// a span was actually created. `startTrace` returns null while OTel is
  /// still initialising (and on failure), so guarding on `_jankSpan != null`
  /// alone would let every later frozen frame overwrite the window start and
  /// shrink `app.ui.jank_window` to "last frozen frame → flush".
  bool _jankWindowOpen = false;
  Duration? _lastJankWindow;

  /// Longest frozen frame observed in the most recent flushed window.
  Duration? _lastMaxFrozenFrame;
  Duration? _lastMaxFrozenBuild;
  Duration? _lastMaxFrozenRaster;

  @visibleForTesting
  bool get debugIsAttached => _attached;

  /// Duration covered by the most recently emitted `ui.jank` span.
  @visibleForTesting
  Duration? get debugLastJankWindow => _lastJankWindow;

  /// Route the most recently emitted `ui.jank` span was attributed to.
  @visibleForTesting
  String? get debugLastJankRoute => _lastJankRoute;

  /// Longest frozen frame in the most recently flushed window — the real
  /// "how long did the UI freeze" number, as opposed to
  /// [debugLastJankWindow], which is only the flush-window span.
  @visibleForTesting
  Duration? get debugLastMaxFrozenFrame => _lastMaxFrozenFrame;

  /// Build time of the longest frozen frame in the last flushed window.
  @visibleForTesting
  Duration? get debugLastMaxFrozenBuild => _lastMaxFrozenBuild;

  /// Raster time of the longest frozen frame in the last flushed window.
  @visibleForTesting
  Duration? get debugLastMaxFrozenRaster => _lastMaxFrozenRaster;

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
      _recentFrozenFrames.add((
        buildMicros: buildMicros,
        rasterMicros: rasterMicros,
        totalMicros: totalMicros,
      ));
      if (_recentFrozenFrames.length > _maxJankBuffer) {
        _recentFrozenFrames.removeAt(0);
      }
      _openJankSpan();
    }
  }

  /// Open the jank span on the first frozen frame of a window so it covers
  /// the episode rather than an instant. Cheap: at most one span per flush
  /// interval, and a no-op while OTel is still initialising.
  void _openJankSpan() {
    if (_jankWindowOpen) return;
    _jankWindowOpen = true;
    _jankSpanStartedAt = DateTime.now();
    // Stamped at the moment the jank happened, not at flush time — the user
    // may well have navigated away by then. It can legitimately be null: the
    // worst jank happens *during* route transitions and at startup, before any
    // route is on the observer, which is why production spans carried
    // `current_route="unknown"` alongside `route.at_flush="chat"`. Remember
    // whether it was a real route so [_flush] can backfill it.
    final route = PerformanceContextService().currentRoute;
    _jankSpanRoute = route == null || route.isEmpty ? null : route;
    _jankSessionsView = PerformanceContextService().currentSessionsView;
    _jankSessionCount = sync.sessionCount;
    _jankSpan = OpenTelemetryService().startTrace(
      'ui.jank',
      attributes: {
        'current_route': _jankSpanRoute ?? 'unknown',
        'session.count': _jankSessionCount!,
        'session.count_bucket': collectionSizeBucket(_jankSessionCount!),
        'sessions.view': _jankSessionsView ?? 'none',
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

    final snapshot = List<_FrozenFrameSample>.from(_recentFrozenFrames);
    _recentFrozenFrames.clear();
    final jankSpan = _jankSpan;
    final jankStartedAt = _jankSpanStartedAt;
    final routeAtOpen = _jankSpanRoute;
    final sessionsViewAtOpen = _jankSessionsView;
    final sessionCountAtOpen = _jankSessionCount;
    _jankSpan = null;
    _jankSpanStartedAt = null;
    _jankSpanRoute = null;
    _jankSessionsView = null;
    _jankSessionCount = null;
    _jankWindowOpen = false;
    _lastJankWindow = null;
    _lastMaxFrozenFrame = null;
    _lastMaxFrozenBuild = null;
    _lastMaxFrozenRaster = null;
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
    final currentSessionCount = sync.sessionCount;
    final currentSessionsView = PerformanceContextService().currentSessionsView;
    final attributes = <String, Object?>{
      'current_route': route,
      'session_count_bucket': collectionSizeBucket(currentSessionCount),
      'sessions_view': currentSessionsView ?? 'none',
    };
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

    final totalMillis = [
      for (final sample in snapshot) (sample.totalMicros / 1000).round(),
    ];
    final avgMs = totalMillis.reduce((a, b) => a + b) / totalMillis.length;
    final maxSample = snapshot.reduce(
      (a, b) => a.totalMicros >= b.totalMicros ? a : b,
    );
    final maxMs = (maxSample.totalMicros / 1000).round();
    final window = jankStartedAt == null
        ? null
        : DateTime.now().difference(jankStartedAt);
    _lastJankWindow = window;
    _lastMaxFrozenFrame = Duration(milliseconds: maxMs);
    _lastMaxFrozenBuild = Duration(microseconds: maxSample.buildMicros);
    _lastMaxFrozenRaster = Duration(microseconds: maxSample.rasterMicros);

    if (_enableSentryTransactions) {
      final transaction =
          Sentry.startTransaction('ui.jank', 'ui.frame', bindToScope: false)
            ..setData('count', snapshot.length)
            ..setData('avgMs', avgMs.round())
            ..setData('maxMs', maxMs)
            ..setData(
              'currentRoute',
              PerformanceContextService().currentRoute ?? 'unknown',
            )
            ..setData('sessionsView', currentSessionsView ?? 'none');

      unawaited(transaction.finish());
    }

    // The real freeze signal: one observation per frozen frame, valued at
    // that frame's own `totalSpan`. `app.ui.jank_window` below measures the
    // flush window instead ("first frozen frame → next 30 s flush"), so its
    // ~15 s median says nothing about how long the UI actually froze. The
    // window metric is kept for dashboard continuity, with a description
    // that no longer invites the wrong reading.
    final frozenAttributes = <String, Object?>{
      'current_route': routeAtOpen ?? route,
      'session_count_bucket': collectionSizeBucket(
        sessionCountAtOpen ?? currentSessionCount,
      ),
      'sessions_view': sessionsViewAtOpen ?? currentSessionsView ?? 'none',
    };
    for (final sample in snapshot) {
      otel
        ..recordDuration(
          'app.ui.frozen_frame',
          Duration(microseconds: sample.totalMicros),
          attributes: frozenAttributes,
          description: 'Duration of a single frozen (>=100ms) frame',
        )
        ..recordDuration(
          'app.ui.frozen_frame_build',
          Duration(microseconds: sample.buildMicros),
          attributes: frozenAttributes,
          description: 'Build component of a frozen (>=100ms) frame',
        )
        ..recordDuration(
          'app.ui.frozen_frame_raster',
          Duration(microseconds: sample.rasterMicros),
          attributes: frozenAttributes,
          description: 'Raster component of a frozen (>=100ms) frame',
        );
    }

    if (window != null) {
      otel.recordDuration(
        'app.ui.jank_window',
        window,
        attributes: frozenAttributes,
        description:
            'Wall time from the first frozen frame of a window to the '
            'metrics flush that closed it — NOT the freeze duration; see '
            'app.ui.frozen_frame',
      );
    }

    // The span was opened by the first frozen frame of this window (see
    // [_openJankSpan]), so it carries a real duration. Correlating counts go
    // on at close, when they are known.
    // Backfill the route when none was known at open time, so a transition- or
    // startup-time jank episode is still attributable to a screen instead of
    // landing in an `unknown` bucket that no dashboard can act on.
    final attributedRoute = routeAtOpen ?? route;
    _lastJankRoute = attributedRoute;
    if (routeAtOpen == null && route != 'unknown') {
      jankSpan?.setAttribute('current_route', route);
    }
    if (sessionsViewAtOpen == null && currentSessionsView != null) {
      jankSpan?.setAttribute('sessions.view', currentSessionsView);
    }
    jankSpan
      ?..setAttribute('frame.count', snapshot.length)
      ..setAttribute('frame.avg_ms', avgMs.round())
      ..setAttribute('frame.max_ms', maxMs)
      // The span's own duration is the flush window, which floods slow-trace
      // searches with ~15-30 s spans that are not freezes. Carry the real
      // numbers as attributes so a trace search can filter on them.
      ..setAttribute('frame.frozen_max_ms', maxMs)
      ..setAttribute(
        'frame.frozen_max_build_ms',
        (maxSample.buildMicros / 1000).round(),
      )
      ..setAttribute(
        'frame.frozen_max_raster_ms',
        (maxSample.rasterMicros / 1000).round(),
      )
      ..setAttribute(
        'frame.frozen_total_ms',
        totalMillis.fold<int>(0, (sum, ms) => sum + ms),
      )
      ..setAttribute('jank.window_ms', window?.inMilliseconds ?? 0)
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

typedef _FrozenFrameSample = ({
  int buildMicros,
  int rasterMicros,
  int totalMicros,
});
