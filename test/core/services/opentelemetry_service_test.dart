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
  });
}
