import 'dart:async';
import 'dart:typed_data';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart'
    show Counter, Histogram;
import 'package:flutter/widgets.dart';
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart'
    hide Logger, LogLevel;

import '../utils/package_info_cache.dart';
import 'logger_service.dart';
import 'performance_context_service.dart';

class OpenTelemetryService {
  factory OpenTelemetryService() => _instance;
  OpenTelemetryService._() : _routeObserver = _HappyOtelRouteObserver();

  static final OpenTelemetryService _instance = OpenTelemetryService._();

  static const String serviceName = 'happy-flutter';
  static const String endpoint = 'https://otel.k2.k8s.best';
  static const bool tracingEnabledByDefault = true;
  static const bool metricsEnabled = true;
  static const bool logsEnabled = true;
  static const bool autoLogEventsEnabled = false;
  static const String traceExporterProtocol = 'otlp_http_protobuf';

  /// Default duration histogram buckets (seconds) covering mobile RTT
  /// (tens of ms) through multi-second stalls.
  static const List<double> _durationBucketsSeconds = <double>[
    0.01,
    0.025,
    0.05,
    0.1,
    0.25,
    0.5,
    1,
    2.5,
    5,
    10,
    30,
  ];

  final NavigatorObserver _routeObserver;

  bool _initialized = false;
  Future<void>? _initializeFuture;
  Future<void>? _trustedCertsFuture;
  _HappyOtelLifecycleObserver? _lifecycleObserver;

  /// Lazy duration histograms keyed by metric name (e.g. app.fetch_messages).
  final Map<String, Histogram<double>> _durationHistograms =
      <String, Histogram<double>>{};
  final Map<String, Counter<int>> _counters = <String, Counter<int>>{};

  /// `signal:phase` keys already reported by [_reportPipelineError], so a
  /// recurring failure logs once per process instead of once per record.
  final Set<String> _reportedPipelineErrors = <String>{};

  /// Self-check counter: if the metrics pipeline is broken this is the one
  /// series that says so. See [_reportPipelineError].
  static const String _pipelineErrorMetric = 'app.otel.pipeline_errors';

  bool get isInitialized => _initialized;

  @visibleForTesting
  Set<String> get debugReportedPipelineErrors =>
      Set<String>.unmodifiable(_reportedPipelineErrors);

  NavigatorObserver get routeObserver => _routeObserver;

  static final Object _activeSpanZoneKey = Object();

  /// Returns the span active in the current asynchronous execution context.
  ///
  /// A Zone value is used instead of an isolate-global stack so concurrent
  /// futures cannot accidentally parent each other's HTTP or socket spans.
  OTelSpan? get currentSpan => Zone.current[_activeSpanZoneKey] as OTelSpan?;

  /// Run [body] with [span] set as the active span on this isolate.
  /// The previous active span (if any) is restored on return, even
  /// when [body] throws. The returned [Future] completes when [body]
  /// completes.
  Future<T> withActiveSpan<T>(OTelSpan span, Future<T> Function() body) async {
    return runZoned(
      body,
      zoneValues: <Object, Object>{_activeSpanZoneKey: span},
    );
  }

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
    final existing = _initializeFuture;
    if (existing != null) return existing;

    final future = _initialize();
    _initializeFuture = future;
    return future;
  }

  Future<void> _initialize() async {
    if (_initialized) return;

    try {
      await _trustedCertsFuture;
      final packageInfo = await PackageInfoCache.get();

      // Use OTLP/HTTP for all signals so native builds talk to the same
      // collector ingress as web builds.
      final metricExporter = OtlpHttpMetricExporter(
        OtlpHttpMetricExporterConfig(endpoint: endpoint),
      );
      final logRecordExporter = OtlpHttpLogRecordExporter(
        OtlpHttpLogRecordExporterConfig(endpoint: endpoint),
      );

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
        metricExporter: metricExporter,
        metricReader: PeriodicExportingMetricReader(
          metricExporter,
          interval: const Duration(seconds: 30),
        ),
        logRecordExporter: logRecordExporter,
        enableMetrics: metricsEnabled,
        enableLogs: logsEnabled,
        enableAutoLogEvents: autoLogEventsEnabled,
      );
      _applyResourceToMeterProvider();
      _replacePackageLifecycleObserver();
      _installLoggerSink();
      _initialized = true;
      logger.info('[OpenTelemetry] initialized endpoint=$endpoint');
    } catch (e, stack) {
      logger.warning('[OpenTelemetry] initialization failed: $e', e, stack);
    } finally {
      _initializeFuture = null;
    }
  }

  Future<void> waitUntilReady({
    Duration timeout = const Duration(milliseconds: 750),
  }) async {
    if (_initialized) return;
    final future = _initializeFuture;
    if (future == null) return;
    try {
      await future.timeout(timeout);
    } on Object {
      // Tracing should never block auth or sync startup. initialize() logs
      // failures, and timeouts simply mean the request proceeds untraced.
    }
  }

  /// Copy the SDK's resource onto the meter provider's **delegate**.
  ///
  /// `flutterrific_opentelemetry` 0.4.0 wraps the SDK `MeterProvider` in a
  /// `UIMeterProvider` whose `resource` setter is an unimplemented stub
  /// (`set resource(Resource? value) { // TODO: implement resource }`).
  /// `OTel.initialize` does perform `meterProvider.resource = defaultResource`
  /// — the assignment is just silently discarded. The periodic reader then
  /// builds `MetricData(resource: meterProvider.resource, ...)` off the
  /// delegate, so every exported metric shipped with an EMPTY resource: no
  /// `service.name`, no `service.version`, no `service.instance.id`. In
  /// Prometheus that meant `target_info{service_name="happy-flutter"}`
  /// matched zero series and every app counter/histogram carried only
  /// `otel_scope_name` / `otel_scope_version`, so any query filtered by
  /// service was blind to all of them.
  ///
  /// `UITracerProvider` and `UILoggerProvider` forward their setters
  /// correctly, which is why traces and logs were unaffected.
  void _applyResourceToMeterProvider() {
    try {
      final resource = OTel.defaultResource;
      if (resource == null) {
        _reportPipelineError(
          signal: 'metrics',
          phase: 'resource',
          detail: 'OTel.defaultResource is null after initialize',
        );
        return;
      }
      final delegate = FlutterOTel.meterProvider.delegate..resource = resource;
      if (delegate.resource == null) {
        _reportPipelineError(
          signal: 'metrics',
          phase: 'resource',
          detail: 'meter provider delegate rejected the resource',
        );
      }
    } catch (e, stack) {
      _reportPipelineError(
        signal: 'metrics',
        phase: 'resource',
        detail: '$e',
        stackTrace: stack,
      );
    }
  }

  /// Report a failure in the telemetry pipeline itself.
  ///
  /// Metric plumbing used to fail behind bare `catch (_) {}` blocks, so a
  /// broken exporter or a rejected instrument produced no log line anywhere —
  /// which is exactly how the empty-resource bug above survived in production.
  /// Logged once per `signal:phase` so a per-record failure cannot spam the
  /// ring buffer, and counted under `app.otel.pipeline_errors` so the class of
  /// bug is queryable even when nobody is reading logs.
  void _reportPipelineError({
    required String signal,
    required String phase,
    required String detail,
    StackTrace? stackTrace,
  }) {
    final key = '$signal:$phase';
    if (_reportedPipelineErrors.add(key)) {
      logger.warning(
        '[OpenTelemetry] $signal pipeline failure at $phase: $detail',
        null,
        stackTrace,
      );
    }
    // Best-effort self-check counter. Deliberately does not route through
    // [recordCount]'s try/catch-and-forget so a failure here cannot recurse.
    try {
      _counters
          .putIfAbsent(
            _pipelineErrorMetric,
            () => FlutterOTel.meter(name: 'happy_flutter').createCounter<int>(
              name: _pipelineErrorMetric,
              description: 'Failures inside the OTel export pipeline itself',
              unit: '{event}',
            ),
          )
          .addWithMap(1, <String, Object>{'signal': signal, 'phase': phase});
    } catch (_) {
      // The metrics pipeline is the thing that is broken; nothing to do.
    }
  }

  void _replacePackageLifecycleObserver() {
    try {
      WidgetsBinding.instance.removeObserver(FlutterOTel.lifecycleObserver);
      FlutterOTel.lifecycleObserver.dispose();
    } catch (e, stack) {
      logger.debug(
        '[OpenTelemetry] failed to remove package lifecycle observer',
        e,
        stack,
      );
    }
    _lifecycleObserver ??= _HappyOtelLifecycleObserver();
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  void _installLoggerSink() {
    logger.installOtelSink(_forwardLogToOtel);
  }

  static void _forwardLogToOtel(LogEntry entry) {
    try {
      final otelLogger = FlutterOTel.logger('happy_flutter');
      final attributes = OTel.attributesFromMap(
        _safeAttributes({
          'logger.level': entry.level.name,
          if (entry.error != null)
            'error.type': entry.error.runtimeType.toString(),
          if (entry.stackTrace != null)
            'error.stack_trace': entry.stackTrace.toString(),
        }),
      );
      final body = entry.message;

      switch (entry.level) {
        case LogLevel.debug:
          otelLogger.debug(body, attributes: attributes);
        case LogLevel.info:
          otelLogger.info(body, attributes: attributes);
        case LogLevel.warning:
          otelLogger.warn(body, attributes: attributes);
        case LogLevel.error:
          otelLogger.error(body, attributes: attributes);
      }
    } catch (_) {
      // OTel may not be initialized yet; logs must never fail because of it.
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
        context: Context.root,
        kind: kind,
        attributes: OTel.attributesFromMap(
          _safeAttributes(_withRouteContext(attributes)),
        ),
      );
      return OTelSpan._(span);
    } catch (e, stack) {
      logger.warning('[OpenTelemetry] failed to start span $name', e, stack);
      return null;
    }
  }

  /// Record a duration histogram sample under [name] (seconds unit).
  ///
  /// Names should be stable, low-cardinality identifiers such as
  /// `app.fetch_messages`, `app.chat.sync_await`, `app.cold_start`.
  /// Attributes must also be low-cardinality (e.g. `outcome`, `mode`).
  /// Best-effort: never throws.
  void recordDuration(
    String name,
    Duration duration, {
    Map<String, Object?> attributes = const {},
    String? description,
  }) {
    if (!_initialized || !metricsEnabled) return;
    if (duration.isNegative) return;
    try {
      final histogram = _durationHistograms.putIfAbsent(name, () {
        final meter = FlutterOTel.meter(name: 'happy_flutter');
        return meter.createHistogram<double>(
          name: name,
          description: description ?? 'Duration of $name',
          unit: 's',
          boundaries: _durationBucketsSeconds,
        );
      });
      final seconds = duration.inMicroseconds / 1e6;
      final safe = _safeAttributes(attributes);
      if (safe.isEmpty) {
        histogram.record(seconds);
      } else {
        histogram.recordWithMap(seconds, safe);
      }
    } catch (e, stack) {
      // Metrics must never break the host flow — but they must not fail
      // silently either.
      _reportPipelineError(
        signal: 'metrics',
        phase: 'histogram',
        detail: '$name: $e',
        stackTrace: stack,
      );
    }
  }

  /// Increment a low-cardinality counter. Best-effort and safe before OTel
  /// initialization, matching [recordDuration].
  void recordCount(
    String name, {
    int value = 1,
    Map<String, Object?> attributes = const {},
    String? description,
  }) {
    if (!_initialized || !metricsEnabled || value <= 0) return;
    try {
      final counter = _counters.putIfAbsent(name, () {
        final meter = FlutterOTel.meter(name: 'happy_flutter');
        return meter.createCounter<int>(
          name: name,
          description: description ?? 'Count of $name',
          unit: '{event}',
        );
      });
      final safe = _safeAttributes(attributes);
      if (safe.isEmpty) {
        counter.add(value);
      } else {
        counter.addWithMap(value, safe);
      }
    } catch (e, stack) {
      // Metrics must never break the host flow — but they must not fail
      // silently either.
      _reportPipelineError(
        signal: 'metrics',
        phase: 'counter',
        detail: '$name: $e',
        stackTrace: stack,
      );
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
        context: Context.root,
        parentSpan: parent?._span,
        kind: kind,
        attributes: OTel.attributesFromMap(
          _safeAttributes(_withRouteContext(attributes)),
        ),
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
        'current_route': routeName ?? previousRouteName,
      },
    );
    span?.end();
  }

  static Map<String, Object?> _withRouteContext(
    Map<String, Object?> attributes,
  ) {
    if (attributes.containsKey('current_route')) return attributes;
    final currentRoute = PerformanceContextService().currentRoute;
    if (currentRoute == null || currentRoute.isEmpty) return attributes;
    return {...attributes, 'current_route': currentRoute};
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

  /// Wrap an already-started SDK [Span]. Test-only: production always goes
  /// through [OpenTelemetryService.startTrace] / `startChildSpan`.
  @visibleForTesting
  factory OTelSpan.forTesting(Span span) = OTelSpan._;

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

  /// Set once [recordError] has been called. The Error status is sticky:
  /// [end] used to always pass an explicit status, so the common
  /// `recordError(...)` followed by `end()` sequence overwrote Error back to
  /// Ok. The exception event survived; the status did not, so every failing
  /// span looked healthy in Jaeger.
  bool _errored = false;

  /// Whether an error has been recorded on this span.
  @visibleForTesting
  bool get debugErrored => _errored;

  /// The status the span currently carries.
  @visibleForTesting
  SpanStatusCode get debugStatus => _span.status;

  void recordError(Object error, [StackTrace? stackTrace]) {
    if (_span.isEnded) return;
    _errored = true;
    _span
      ..recordException(error, stackTrace: stackTrace)
      ..setStatus(SpanStatusCode.Error, error.runtimeType.toString());
  }

  /// End the span.
  ///
  /// [ok] is nullable so callers can say "I have no opinion" (the default)
  /// rather than asserting success. A recorded error always wins: passing
  /// `ok: true` after [recordError] cannot resurrect an Ok status.
  void end({bool? ok}) {
    if (_span.isEnded) return;
    final failed = _errored || ok == false;
    _span.end(spanStatus: failed ? SpanStatusCode.Error : SpanStatusCode.Ok);
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

class _HappyOtelLifecycleObserver with WidgetsBindingObserver {
  _HappyOtelLifecycleObserver() {
    _recordLifecycleChange(null);
  }

  Uint8List? _currentLifecycleId;
  AppLifecycleStates? _currentLifecycleState;
  DateTime? _currentLifecycleStartTime;

  void _recordLifecycleChange(AppLifecycleState? state) {
    final startTime = DateTime.now();
    final newStateId = OTel.spanId().bytes;
    final previousState = _currentLifecycleState;
    final previousStartTime = _currentLifecycleStartTime;
    final duration = previousState != null && previousStartTime != null
        ? startTime.difference(previousStartTime)
        : null;
    final newState = state == null
        ? AppLifecycleStates.active
        : AppLifecycleStates.appLifecycleStateFor(state.name);

    FlutterOTel.tracer
        .startAppLifecycleSpan(
          newState: newState,
          startTime: startTime,
          newStateId: newStateId,
          previousState: previousState,
          previousStateId: _currentLifecycleId,
          previousStateDuration: duration,
        )
        .end();

    // Android reports several lifecycle states for a single app switch
    // (inactive, hidden, paused, then the reverse on return). Flushing the
    // exporter for each one repeatedly wakes the radio. The paused state is
    // the last reliable opportunity before background execution stops, so
    // flush once there and let the exporter batch all other transitions.
    if (state == AppLifecycleState.paused) {
      FlutterOTel.forceFlush();
    }
    FlutterOTel.currentAppLifecycleId = newStateId;
    _currentLifecycleId = newStateId;
    _currentLifecycleState = newState;
    _currentLifecycleStartTime = startTime;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _recordLifecycleChange(state);
  }
}
