import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart'
    hide Logger;

import '../utils/package_info_cache.dart';
import 'logger_service.dart';

class OpenTelemetryService {
  factory OpenTelemetryService() => _instance;
  OpenTelemetryService._() : _routeObserver = _HappyOtelRouteObserver();

  static final OpenTelemetryService _instance = OpenTelemetryService._();

  static const String serviceName = 'happy-flutter';
  static const String endpoint = 'https://otel.k2.k8s.best';
  static const bool tracingEnabledByDefault = true;
  static const bool metricsEnabled = false;
  static const bool logsEnabled = false;
  static const bool autoLogEventsEnabled = false;
  static const String traceExporterProtocol = 'otlp_http_protobuf';

  final NavigatorObserver _routeObserver;

  bool _initialized = false;
  Future<void>? _trustedCertsFuture;

  bool get isInitialized => _initialized;

  NavigatorObserver get routeObserver => _routeObserver;

  @visibleForTesting
  String get configuredEndpoint => endpoint;

  @visibleForTesting
  bool get configuredEnableMetrics => metricsEnabled;

  @visibleForTesting
  bool get configuredEnableLogs => logsEnabled;

  @visibleForTesting
  bool get configuredEnableAutoLogEvents => autoLogEventsEnabled;

  @visibleForTesting
  bool get configuredTracingEnabledByDefault => tracingEnabledByDefault;

  @visibleForTesting
  String get configuredTraceExporterProtocol => traceExporterProtocol;

  void setTrustedCertificatesFuture(Future<void> future) {
    _trustedCertsFuture = future;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _trustedCertsFuture;
      final packageInfo = await PackageInfoCache.get();
      await FlutterOTel.initialize(
        appName: serviceName,
        endpoint: endpoint,
        secure: true,
        serviceName: serviceName,
        serviceVersion: packageInfo.version,
        tracerName: 'happy_flutter',
        tracerVersion: packageInfo.version,
        spanProcessor: BatchSpanProcessor(
          OtlpHttpSpanExporter(OtlpHttpExporterConfig(endpoint: endpoint)),
        ),
        enableMetrics: metricsEnabled,
        enableLogs: logsEnabled,
        enableAutoLogEvents: autoLogEventsEnabled,
      );
      _initialized = true;
      logger.info('[OpenTelemetry] initialized endpoint=$endpoint');
    } catch (e, stack) {
      logger.warning('[OpenTelemetry] initialization failed: $e', e, stack);
    }
  }

  OTelSpan? startTrace(
    String name, {
    Map<String, Object?> attributes = const {},
    SpanKind kind = SpanKind.internal,
  }) {
    if (!_initialized) return null;
    try {
      final span = OTel.tracer().startSpan(
        name,
        kind: kind,
        attributes: OTel.attributesFromMap(_safeAttributes(attributes)),
      );
      return OTelSpan._(span);
    } catch (e, stack) {
      logger.warning('[OpenTelemetry] failed to start span $name', e, stack);
      return null;
    }
  }

  OTelSpan? startChildSpan(
    String name, {
    OTelSpan? parent,
    Map<String, Object?> attributes = const {},
    SpanKind kind = SpanKind.internal,
  }) {
    if (!_initialized) return null;
    try {
      final span = OTel.tracer().startSpan(
        name,
        parentSpan: parent?._span,
        kind: kind,
        attributes: OTel.attributesFromMap(_safeAttributes(attributes)),
      );
      return OTelSpan._(span);
    } catch (e, stack) {
      logger.warning('[OpenTelemetry] failed to start span $name', e, stack);
      return null;
    }
  }

  void recordRouteChange({
    required String action,
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  }) {
    final routeName = _safeRouteName(route);
    final previousRouteName = _safeRouteName(previousRoute);
    final span = startTrace(
      'navigation.$action',
      kind: SpanKind.client,
      attributes: {
        'navigation.action': action,
        'route.name': routeName,
        'route.previous': ?previousRouteName,
      },
    );
    span?.end();
  }

  static String? _safeRouteName(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return null;
    return name;
  }

  static Map<String, Object> _safeAttributes(Map<String, Object?> values) {
    final safe = <String, Object>{};
    for (final entry in values.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String) {
        safe[entry.key] = value.length > 256
            ? '${value.substring(0, 253)}...'
            : value;
      } else if (value is bool || value is int || value is double) {
        safe[entry.key] = value;
      } else if (value is List<String> ||
          value is List<bool> ||
          value is List<int> ||
          value is List<double>) {
        safe[entry.key] = value;
      }
    }
    return safe;
  }
}

class OTelSpan {
  OTelSpan._(this._span);

  final Span _span;

  SpanContext get spanContext => _span.spanContext;

  void setAttribute(String key, Object? value) {
    if (value == null || _span.isEnded) return;
    if (value is String) {
      final safeValue = value.length > 256
          ? '${value.substring(0, 253)}...'
          : value;
      _span.setStringAttribute(key, safeValue);
    } else if (value is bool) {
      _span.setBoolAttribute(key, value);
    } else if (value is int) {
      _span.setIntAttribute(key, value);
    } else if (value is double) {
      _span.setDoubleAttribute(key, value);
    }
  }

  void recordError(Object error, [StackTrace? stackTrace]) {
    if (_span.isEnded) return;
    _span
      ..recordException(error, stackTrace: stackTrace)
      ..setStatus(SpanStatusCode.Error, error.runtimeType.toString());
  }

  void end({bool ok = true}) {
    if (_span.isEnded) return;
    _span.end(spanStatus: ok ? SpanStatusCode.Ok : SpanStatusCode.Error);
  }
}

class _HappyOtelRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    OpenTelemetryService().recordRouteChange(
      action: 'push',
      route: route,
      previousRoute: previousRoute,
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    OpenTelemetryService().recordRouteChange(
      action: 'pop',
      route: route,
      previousRoute: previousRoute,
    );
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    OpenTelemetryService().recordRouteChange(
      action: 'replace',
      route: newRoute,
      previousRoute: oldRoute,
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    OpenTelemetryService().recordRouteChange(
      action: 'remove',
      route: route,
      previousRoute: previousRoute,
    );
    super.didRemove(route, previousRoute);
  }
}
