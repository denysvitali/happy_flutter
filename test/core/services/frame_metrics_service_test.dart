import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/frame_metrics_service.dart';
import 'package:happy_flutter/core/services/opentelemetry_service.dart';
import 'package:happy_flutter/core/services/performance_context_service.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FrameMetricsService.instance.detach();
  });

  group('FrameMetricsService lifecycle', () {
    test('attach starts periodic reporting and detach cancels it', () {
      final service = FrameMetricsService.instance;

      expect(service.debugIsAttached, isFalse);
      expect(service.debugHasFlushTimer, isFalse);

      service.attach();

      expect(service.debugIsAttached, isTrue);
      expect(service.debugHasFlushTimer, isTrue);

      service.detach();

      expect(service.debugIsAttached, isFalse);
      expect(service.debugHasFlushTimer, isFalse);
    });

    test('attach and detach are idempotent', () {
      final service = FrameMetricsService.instance;

      service.attach();
      service.attach();

      expect(service.debugIsAttached, isTrue);
      expect(service.debugHasFlushTimer, isTrue);

      service.detach();
      service.detach();

      expect(service.debugIsAttached, isFalse);
      expect(service.debugHasFlushTimer, isFalse);
    });
  });

  group('FrameMetricsService classification', () {
    test('tracks smooth, slow, and frozen frames separately', () {
      final service = FrameMetricsService.instance;
      service.testRecordFrame(
        build: const Duration(milliseconds: 4),
        raster: const Duration(milliseconds: 4),
        total: const Duration(milliseconds: 8),
      );
      service.testRecordFrame(
        build: const Duration(milliseconds: 12),
        raster: const Duration(milliseconds: 9),
        total: const Duration(milliseconds: 21),
      );
      service.testRecordFrame(
        build: const Duration(milliseconds: 70),
        raster: const Duration(milliseconds: 40),
        total: const Duration(milliseconds: 110),
      );

      expect(service.debugFrameCount, 3);
      expect(service.debugSlowFrameCount, 2);
      expect(service.debugFrozenFrameCount, 1);
    });

    test('labels frame metrics with a bounded session-count bucket', () {
      sync.testSessions.clear();
      final attributes = <String, Map<String, Object?>>{};
      OpenTelemetryService.debugDurationSink = (name, _, values) {
        attributes[name] = values;
      };
      addTearDown(() => OpenTelemetryService.debugDurationSink = null);

      FrameMetricsService.instance
        ..testRecordFrame(
          build: const Duration(milliseconds: 4),
          raster: const Duration(milliseconds: 4),
          total: const Duration(milliseconds: 8),
        )
        ..debugFlush();

      expect(attributes['app.ui.frame_total']?['session_count_bucket'], '0');
    });
  });

  // The `ui.jank` span used to be started and ended in the same statement, so
  // its duration was always zero and
  // `traces_span_metrics_duration_seconds{span_name="ui.jank"}` carried no
  // information at all. It now spans the measured jank episode.
  group('FrameMetricsService jank window', () {
    test('spans the episode instead of an instant', () async {
      final service = FrameMetricsService.instance
        ..testRecordFrame(
          build: const Duration(milliseconds: 70),
          raster: const Duration(milliseconds: 40),
          total: const Duration(milliseconds: 110),
        );

      await Future<void>.delayed(const Duration(milliseconds: 5));
      service.debugFlush();

      expect(service.debugLastJankWindow, isNotNull);
      expect(service.debugLastJankWindow!.inMicroseconds, greaterThan(0));
    });

    // Regression: `_openJankSpan` guarded on `_jankSpan != null`, but the span
    // is null whenever OTel is not initialised (as in tests, and during app
    // start-up). Every later frozen frame then reset the window start, so the
    // histogram measured "last frozen frame → flush" instead of the episode.
    test('keeps the first frozen frame as the window start', () async {
      final service = FrameMetricsService.instance
        ..testRecordFrame(
          build: const Duration(milliseconds: 70),
          raster: const Duration(milliseconds: 40),
          total: const Duration(milliseconds: 110),
        );

      await Future<void>.delayed(const Duration(milliseconds: 60));

      service.testRecordFrame(
        build: const Duration(milliseconds: 70),
        raster: const Duration(milliseconds: 40),
        total: const Duration(milliseconds: 110),
      );
      service.debugFlush();

      expect(service.debugLastJankWindow, isNotNull);
      expect(
        service.debugLastJankWindow!.inMilliseconds,
        greaterThanOrEqualTo(50),
      );
    });

    // `app_ui_jank_window_seconds` showed p50 14.6s / p95 28.5s, which reads
    // as "14 second freezes" but is only "frozen frame landed mid-window".
    // The real freeze duration now has its own histogram.
    test('records each frozen frame duration, not the window length', () async {
      final recorded = <String, List<Duration>>{};
      OpenTelemetryService.debugDurationSink = (name, duration, _) {
        recorded.putIfAbsent(name, () => <Duration>[]).add(duration);
      };
      addTearDown(() => OpenTelemetryService.debugDurationSink = null);

      final service = FrameMetricsService.instance
        ..testRecordFrame(
          build: const Duration(milliseconds: 70),
          raster: const Duration(milliseconds: 40),
          total: const Duration(milliseconds: 110),
        )
        ..testRecordFrame(
          build: const Duration(milliseconds: 150),
          raster: const Duration(milliseconds: 90),
          total: const Duration(milliseconds: 240),
        );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      service.debugFlush();

      expect(recorded['app.ui.frozen_frame'], [
        const Duration(milliseconds: 110),
        const Duration(milliseconds: 240),
      ]);
      // The legacy window metric stays for dashboard continuity, and stays a
      // different quantity: wall time since the first frozen frame.
      expect(recorded['app.ui.jank_window'], hasLength(1));
      expect(
        recorded['app.ui.jank_window']!.single.inMilliseconds,
        greaterThanOrEqualTo(25),
      );
      expect(
        recorded['app.ui.jank_window']!.single,
        isNot(const Duration(milliseconds: 240)),
        reason: 'window length must stay distinct from freeze duration',
      );
      expect(
        service.debugLastMaxFrozenFrame,
        const Duration(milliseconds: 240),
      );
    });

    test('reports no window when no frame was frozen', () {
      final service = FrameMetricsService.instance
        ..testRecordFrame(
          build: const Duration(milliseconds: 4),
          raster: const Duration(milliseconds: 4),
          total: const Duration(milliseconds: 8),
        );

      service.debugFlush();

      expect(service.debugLastJankWindow, isNull);
    });
  });

  // Production `ui.jank` spans carried `current_route="unknown"` next to
  // `route.at_flush="chat"`: the worst jank happens during route transitions
  // and at start-up, before any route reaches the observer, so the open-time
  // stamp was empty and the episode was unattributable.
  group('FrameMetricsService jank route attribution', () {
    setUp(PerformanceContextService().resetForTesting);
    tearDown(PerformanceContextService().resetForTesting);

    void recordFrozenFrame() {
      FrameMetricsService.instance.testRecordFrame(
        build: const Duration(milliseconds: 70),
        raster: const Duration(milliseconds: 40),
        total: const Duration(milliseconds: 110),
      );
    }

    test('uses the route known when the jank started', () {
      PerformanceContextService().setCurrentRoute('chat');
      recordFrozenFrame();

      // The user navigates away before the 30s flush.
      PerformanceContextService().setCurrentRoute('sessions');
      FrameMetricsService.instance.debugFlush();

      expect(FrameMetricsService.instance.debugLastJankRoute, 'chat');
    });

    test('backfills the flush route when none was known at open', () {
      recordFrozenFrame();

      PerformanceContextService().setCurrentRoute('chat');
      FrameMetricsService.instance.debugFlush();

      expect(FrameMetricsService.instance.debugLastJankRoute, 'chat');
    });

    test('falls back to unknown when no route is ever known', () {
      recordFrozenFrame();
      FrameMetricsService.instance.debugFlush();

      expect(FrameMetricsService.instance.debugLastJankRoute, 'unknown');
    });
  });
}
