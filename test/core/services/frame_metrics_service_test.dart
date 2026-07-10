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
}
