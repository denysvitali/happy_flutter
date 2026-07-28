import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/opentelemetry_service.dart';
import 'package:happy_flutter/core/services/performance_context_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OpenTelemetryService configuration', () {
    test('uses the production OTLP HTTP endpoint', () {
      expect(
        OpenTelemetryService().configuredEndpoint,
        'https://otel.k2.k8s.best',
      );
    });

    test('enables tracing, metrics, logs and auto log events by default', () {
      final service = OpenTelemetryService();

      expect(service.configuredTracingEnabledByDefault, isTrue);
      expect(service.configuredEnableMetrics, isTrue);
      expect(service.configuredEnableLogs, isTrue);
      expect(service.configuredEnableAutoLogEvents, isFalse);
      expect(service.configuredTraceExporterProtocol, 'otlp_http_protobuf');
    });

    test('route observer is stable and safe before initialization', () {
      final service = OpenTelemetryService();
      final observer = service.routeObserver;

      expect(observer, isNotNull);
      expect(service.startTrace('test.before.init'), isNull);

      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'settings'),
        builder: (_) => const SizedBox.shrink(),
      );

      expect(() => observer.didPush(route, null), returnsNormally);
    });

    test('performance route observer updates current route on pop', () {
      final service = PerformanceContextService()..resetForTesting();
      final observer = PerformanceRouteObserver();
      final settingsRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'settings'),
        builder: (_) => const SizedBox.shrink(),
      );
      final chatRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'chat'),
        builder: (_) => const SizedBox.shrink(),
      );

      observer.didPush(settingsRoute, null);
      observer.didPush(chatRoute, settingsRoute);
      observer.didPop(chatRoute, settingsRoute);

      expect(service.currentRoute, 'settings');
    });

    test('route listenable only notifies for a real route change', () {
      final service = PerformanceContextService()..resetForTesting();
      var notifications = 0;
      void listener() => notifications++;
      service.routeListenable.addListener(listener);
      addTearDown(() => service.routeListenable.removeListener(listener));

      service.setCurrentRoute('chat');
      service.setCurrentRoute('chat');
      service.setCurrentRoute('message-detail');

      expect(notifications, 2);
      expect(service.routeListenable.value, 'message-detail');
    });
  });

  // `end()` used to always pass an explicit span status, so the very common
  // `recordError(...)` -> `end()` sequence overwrote Error back to Ok. The
  // exception event survived but the status did not, so failing spans were
  // indistinguishable from healthy ones in Jaeger.
  group('OTelSpan error status is sticky', () {
    setUpAll(() async {
      await OTel.initialize(
        endpoint: 'http://localhost:4318',
        serviceName: 'happy-flutter-test',
        spanProcessor: SimpleSpanProcessor(ConsoleExporter()),
        enableMetrics: false,
        enableLogs: false,
        detectPlatformResources: false,
      );
    });

    tearDownAll(() async {
      await OTel.shutdown();
    });

    OTelSpan newSpan(String name) => OTelSpan.forTesting(
      OTel.tracerProvider().getTracer('test').startSpan(name),
    );

    test('recordError then end() yields Error', () {
      final span = newSpan('span.record_error_then_end')
        ..recordError(StateError('boom'))
        ..end();

      expect(span.debugErrored, isTrue);
      expect(span.debugStatus, SpanStatusCode.Error);
    });

    test('recordError then end(ok: true) cannot resurrect Ok', () {
      final span = newSpan('span.record_error_then_end_ok')
        ..recordError(StateError('boom'))
        ..end(ok: true);

      expect(span.debugStatus, SpanStatusCode.Error);
    });

    test('end(ok: false) marks Error without a recorded exception', () {
      final span = newSpan('span.end_not_ok')..end(ok: false);

      expect(span.debugErrored, isFalse);
      expect(span.debugStatus, SpanStatusCode.Error);
    });

    test('a clean span still ends Ok', () {
      final span = newSpan('span.clean')..end();

      expect(span.debugStatus, SpanStatusCode.Ok);
    });

    test('end is idempotent and does not downgrade a recorded error', () {
      final span = newSpan('span.double_end')
        ..recordError(StateError('boom'))
        ..end()
        ..end(ok: true);

      expect(span.debugStatus, SpanStatusCode.Error);
    });
  });

  // Log records used to ship `error.type` only, and every string attribute was
  // capped at 256 chars — which cut `error.stack_trace` off inside the Dart VM
  // crash header, before any symbolicatable frame. Production showed 82
  // indistinguishable `_TypeError` events as a result.
  group('OpenTelemetryService attribute truncation', () {
    test('ordinary string attributes stay capped at 256 chars', () {
      final safe = OpenTelemetryService.debugSafeAttributes({
        'current_route': 'r' * 400,
      });

      expect((safe['current_route']! as String).length, 256);
      expect(safe['current_route'], endsWith('...'));
    });

    test('stack traces and error messages get the long cap', () {
      final stack = 's' * 5000;
      final safe = OpenTelemetryService.debugSafeAttributes({
        'error.stack_trace': stack,
        'error.message': 'm' * 5000,
      });

      expect(safe['error.stack_trace'], stack);
      expect((safe['error.message']! as String).length, 5000);
    });

    test('a stack trace beyond the long cap is truncated, not dropped', () {
      final safe = OpenTelemetryService.debugSafeAttributes({
        'error.stack_trace': 's' * 9000,
      });

      expect((safe['error.stack_trace']! as String).length, 8192);
      expect(safe['error.stack_trace'], endsWith('...'));
    });

    test('nulls are dropped and scalars pass through untouched', () {
      final safe = OpenTelemetryService.debugSafeAttributes({
        'absent': null,
        'websocket.since_dial_ms': 1234,
        'send.degraded': false,
      });

      expect(safe.containsKey('absent'), isFalse);
      expect(safe['websocket.since_dial_ms'], 1234);
      expect(safe['send.degraded'], false);
    });
  });
}
