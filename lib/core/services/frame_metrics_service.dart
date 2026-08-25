import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter/scheduler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../platform_io.dart'
    if (dart.library.js_interop) '../../platform_stub.dart';
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

  /// Length of one metrics window. Frames-per-window is only interpretable
  /// against this, so the timer and the fps buckets must share it.
  static const int _flushIntervalSeconds = 30;

  /// Frames in a single idle window above which the window is worth a log
  /// line — 300 frames over 30 s is 10 fps sustained with nothing on screen
  /// asking to be redrawn.
  static const int _idleRenderWarnFrames = 300;

  static const Duration _idleRenderWarnCooldown = Duration(minutes: 5);

  /// Boundaries for the `app.memory.rss_mb` histogram. RSS of a Flutter
  /// app spans ~150 MB (fresh launch) to 1 GB+ (pathological); the top
  /// buckets exist to make runaway growth visible, not to be healthy.
  static const List<double> _rssMbBuckets = [
    128,
    192,
    256,
    320,
    384,
    448,
    512,
    640,
    768,
    1024,
    1536,
    2048,
  ];

  /// Boundaries for `app.memory.image_cache_mb`. The decoded-image cache is
  /// the classic silent hoarder: inline base64 chat images decode at full
  /// resolution and stay pinned until eviction pressure. Production RSS
  /// p95 sits near 2 GB at large session counts — if this gauge does not
  /// move with it, images are ruled out as the driver.
  static const List<double> _imageCacheMbBuckets = [
    8,
    16,
    32,
    64,
    96,
    128,
    192,
    256,
    384,
    512,
  ];

  /// Boundaries for `app.memory.encryption_cache_mb`. The cache's own byte
  /// budgets sum to ~19 MB (agent state 4 + metadata 2 + messages 8 +
  /// machine metadata 1 + daemon state 4); buckets resolve below that cap
  /// and expose a breach past it.
  static const List<double> _encryptionCacheMbBuckets = [
    1,
    2,
    4,
    8,
    12,
    16,
    20,
    32,
    64,
  ];

  /// Boundaries for `app.memory.resident_rows`: decrypted transcript rows
  /// held in memory. Full residency is capped at 8 sessions x 200 rows plus
  /// 25-row previews for the rest of the catalog, so the healthy ceiling
  /// scales with catalog size; the top buckets name runaway retention.
  static const List<double> _residentRowsBuckets = [
    100,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  int _frameCount = 0;
  int _slowFrameCount = 0;
  int _frozenFrameCount = 0;
  int _buildMicros = 0;
  int _rasterMicros = 0;
  int _totalMicros = 0;
  final Map<String, int> _frameBuckets = <String, int>{
    'under_16ms': 0,
    '16_32ms': 0,
    '32_50ms': 0,
    '50_100ms': 0,
    '100ms_plus': 0,
  };

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

  /// Pointer events routed anywhere in the app since the last flush. Counted
  /// globally rather than per-widget: the question is only "did the user
  /// touch the screen at all in this window?".
  int _pointerEvents = 0;

  /// `dataChangeCounter + messagesChangeCounter` as of the last flush, so a
  /// window can tell whether Sync published anything while it was rendering.
  int _lastActivityCounter = 0;

  /// Activity counts observed in the current window. The aggregate counter
  /// above answers "was anything active?", while these split the answer into
  /// input-driven repaints versus Sync-driven repaints.
  int _windowDataChanges = 0;
  int _windowMessageChanges = 0;

  DateTime? _lastIdleRenderWarnAt;

  int _lastWindowFrames = 0;
  bool _lastWindowIdle = false;

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

  /// Frames counted by the most recently flushed window.
  @visibleForTesting
  int get debugLastWindowFrames => _lastWindowFrames;

  /// Whether the most recently flushed window saw neither pointer input nor
  /// a Sync change — i.e. it had no reason to render at all.
  @visibleForTesting
  bool get debugLastWindowIdle => _lastWindowIdle;

  @visibleForTesting
  void debugRecordPointerEvent() => _pointerEvents++;

  @visibleForTesting
  void debugRecordDataChange() => _windowDataChanges++;

  @visibleForTesting
  void debugRecordMessageChange() => _windowMessageChanges++;

  /// Re-seed the window accounting so a test starts from a clean window
  /// regardless of what earlier tests left on the shared singleton.
  @visibleForTesting
  void debugResetWindow() {
    _pointerEvents = 0;
    _lastActivityCounter = _activityCounter();
    _windowDataChanges = 0;
    _windowMessageChanges = 0;
    _lastWindowFrames = 0;
    _lastWindowIdle = false;
    _lastIdleRenderWarnAt = null;
  }

  @visibleForTesting
  int get debugSlowFrameCount => _slowFrameCount;

  @visibleForTesting
  int get debugFrozenFrameCount => _frozenFrameCount;

  @visibleForTesting
  Map<String, int> get debugFrameBuckets => Map.unmodifiable(_frameBuckets);

  /// Attach to [SchedulerBinding] frame timing callbacks.
  void attach({bool enableSentryTransactions = false}) {
    _enableSentryTransactions = enableSentryTransactions;
    if (_attached) return;
    _attached = true;

    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
    _lastActivityCounter = _activityCounter();

    // Periodically flush accumulated jank stats as a single Sentry
    // transaction instead of one per frame.
    _flushTimer = Timer.periodic(
      const Duration(seconds: _flushIntervalSeconds),
      (_) => _flush(),
    );

    if (kDebugMode) {
      logger.debug('[FrameMetrics] Attached');
    }
  }

  void _onPointerEvent(PointerEvent _) => _pointerEvents++;

  /// Collection-wide "something changed" clock. Both counters are monotonic
  /// while the app runs, but `dataChangeCounter` is reset by `shutdown()`, so
  /// callers must treat a negative delta as activity rather than as silence.
  int _activityCounter() => sync.dataChangeCounter + sync.messagesChangeCounter;

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
    final bucket = switch (totalMicros) {
      < 16000 => 'under_16ms',
      < 32000 => '16_32ms',
      < 50000 => '32_50ms',
      < 100000 => '50_100ms',
      _ => '100ms_plus',
    };
    _frameBuckets[bucket] = _frameBuckets[bucket]! + 1;
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

  /// Test-only override for the EncryptionCache byte total. Production code
  /// must never set this; null falls through to
  /// [_encryptionCacheRetainedBytes].
  @visibleForTesting
  int? Function()? debugEncryptionRetainedBytes;

  /// Best-effort read of the EncryptionCache byte budgets. [Sync] only
  /// holds an encryption instance after a successful login, so pre-auth
  /// windows have nothing to report — that reads as 0 (sample skipped), it
  /// is not an error. Sampling telemetry must never throw out of a flush.
  int _encryptionCacheRetainedBytes() {
    final override = debugEncryptionRetainedBytes;
    if (override != null) return override() ?? 0;
    if (!sync.isEncryptionInitialized) return 0;
    return sync.encryption.cache.getStats()['retainedBytes'] ?? 0;
  }

  void _flush() {
    // Reset the window's activity accounting before the zero-frame early
    // return. A window that rendered nothing is the healthy case, but its
    // taps and data changes still belong to it — carrying them forward would
    // make the *next* window look active and mask a real idle-render burst.
    final activityCounter = _activityCounter();
    final activityTicks = activityCounter - _lastActivityCounter;
    final dataChanges = _windowDataChanges;
    final messageChanges = _windowMessageChanges;
    final pointerEvents = _pointerEvents;
    _lastActivityCounter = activityCounter;
    _windowDataChanges = 0;
    _windowMessageChanges = 0;
    _pointerEvents = 0;

    // Memory samples before the zero-frame early return: a healthy idle
    // window renders nothing but its heap trend is exactly what the
    // progressive-lag hypothesis needs. RSS is gated on > 0 because 0 means
    // unsupported (web); every attribution gauge rides the same gate so a
    // high-RSS launch can be decomposed on the same window.
    final rssBytes = currentRssBytes;
    if (rssBytes > 0) {
      final attributes = <String, Object>{
        'current_route': PerformanceContextService().currentRoute ?? 'unknown',
        'session_count_bucket': collectionSizeBucket(sync.sessionCount),
      };
      OpenTelemetryService().recordValue(
        'app.memory.rss_mb',
        rssBytes / (1024 * 1024),
        unit: 'MB',
        boundaries: _rssMbBuckets,
        attributes: attributes,
        description:
            'Process resident set size sampled once per metrics window — '
            'quantile this per build to see progressive heap growth',
      );
      // RSS says how much; these say where.
      final imageCacheBytes =
          PaintingBinding.instance.imageCache.currentSizeBytes;
      OpenTelemetryService().recordValue(
        'app.memory.image_cache_mb',
        imageCacheBytes / (1024 * 1024),
        unit: 'MB',
        boundaries: _imageCacheMbBuckets,
        attributes: attributes,
        description:
            'Decoded-image cache bytes sampled once per metrics window — '
            'attributes the RSS signal to inline chat images or rules '
            'images out',
      );
      final encryptionRetainedBytes = _encryptionCacheRetainedBytes();
      if (encryptionRetainedBytes > 0) {
        OpenTelemetryService().recordValue(
          'app.memory.encryption_cache_mb',
          encryptionRetainedBytes / (1024 * 1024),
          unit: 'MB',
          boundaries: _encryptionCacheMbBuckets,
          attributes: attributes,
          description:
              'EncryptionCache retained bytes sampled once per metrics '
              'window — exposes a breach of its ~19 MB byte budgets',
        );
      }
      OpenTelemetryService().recordValue(
        'app.memory.resident_rows',
        sync.residentMessageRowCount.toDouble(),
        unit: '{rows}',
        boundaries: _residentRowsBuckets,
        attributes: attributes,
        description:
            'Decrypted transcript rows resident across all sessions — '
            'the residency budget should keep this flat as the catalog '
            'grows',
      );
    }

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
    final frameBuckets = Map<String, int>.from(_frameBuckets);
    final avgBuild = Duration(microseconds: _buildMicros ~/ frameCount);
    final avgRaster = Duration(microseconds: _rasterMicros ~/ frameCount);
    final avgTotal = Duration(microseconds: _totalMicros ~/ frameCount);
    _frameCount = 0;
    _slowFrameCount = 0;
    _frozenFrameCount = 0;
    _buildMicros = 0;
    _rasterMicros = 0;
    _totalMicros = 0;
    for (final bucket in _frameBuckets.keys) {
      _frameBuckets[bucket] = 0;
    }

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
    for (final entry in frameBuckets.entries) {
      otel.recordCount(
        'app.ui.frame_latency_bucket',
        value: entry.value,
        attributes: {...attributes, 'bucket': entry.key},
      );
    }

    // Idle-render detection. A window that rendered frames while the user
    // never touched the screen and Sync never published a change had nothing
    // to draw — those frames are pure battery burn. A healthy screen at rest
    // produces zero frames and never reaches this code at all.
    //
    // A negative delta means `shutdown()` reset `dataChangeCounter` mid
    // window, which is itself activity; do not read it as silence.
    final idleWindow = pointerEvents == 0 && activityTicks == 0;
    final windowAttributes = <String, Object?>{
      ...attributes,
      'activity': idleWindow ? 'idle' : 'active',
      'pointer_events': pointerEvents,
      'data_changes': dataChanges,
      'message_changes': messageChanges,
    };
    _lastWindowFrames = frameCount;
    _lastWindowIdle = idleWindow;
    otel
      ..recordCount(
        'app.ui.window_frames',
        value: frameCount,
        attributes: windowAttributes,
        description:
            'Frames rendered in one metrics window, split by whether that '
            'window saw any pointer input or Sync data change',
      )
      ..recordCount(
        'app.ui.render_windows',
        attributes: {
          ...windowAttributes,
          'window_fps_bucket': _windowFpsBucket(frameCount),
        },
        description:
            'Metrics windows that rendered at least one frame, bucketed by '
            'sustained frame rate — the denominator for app.ui.window_frames',
      );
    if (idleWindow && frameCount >= _idleRenderWarnFrames) {
      _warnIdleRender(route, frameCount);
    }

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

  /// Sustained frame rate of a window, bucketed. Kept coarse: this label
  /// exists to separate "a couple of frames on a socket update" from "the
  /// screen never stopped drawing", not to profile.
  static String _windowFpsBucket(int frames) => switch (frames) {
    < _flushIntervalSeconds => 'under_1fps',
    < _flushIntervalSeconds * 5 => '1_5fps',
    < _flushIntervalSeconds * 15 => '5_15fps',
    < _flushIntervalSeconds * 30 => '15_30fps',
    _ => '30fps_plus',
  };

  /// One greppable line per idle-render burst, rate limited so a screen that
  /// spins forever cannot flood Loki. The metrics above carry the counts;
  /// this exists so the route can be found without a dashboard.
  void _warnIdleRender(String route, int frames) {
    final now = DateTime.now();
    final last = _lastIdleRenderWarnAt;
    if (last != null && now.difference(last) < _idleRenderWarnCooldown) {
      return;
    }
    _lastIdleRenderWarnAt = now;
    final fps = (frames / _flushIntervalSeconds).toStringAsFixed(1);
    logger.warning(
      '[FrameMetrics] idle render: route=$route frames=$frames '
      'window=${_flushIntervalSeconds}s fps=$fps '
      '(no pointer input, no sync change)',
    );
  }

  /// Detach and clean up. Call on app dispose.
  void detach() {
    if (!_attached) return;
    _attached = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
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
