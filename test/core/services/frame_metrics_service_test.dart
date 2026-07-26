import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/frame_metrics_service.dart';

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
}
