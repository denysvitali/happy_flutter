import 'dart:async';
import 'dart:convert';
import 'dart:math' show max;

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart'
    show W3CTraceContextPropagator;
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show TextMapSetter;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart'
    show OTel, SpanContext, SpanKind;
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../sentry_config.dart';
import '../services/http_request_logger.dart';
import '../services/logger_service.dart' show logger;
import '../services/opentelemetry_service.dart';
import '../services/power_diagnostics_service.dart';
import '../services/server_config.dart';
import 'http_cache.dart';
import 'native_adapter_helper.dart'
    if (dart.library.js_interop) 'native_adapter_helper_web.dart';
import 'retry_interceptor.dart';

/// Custom Dio client with user CA certificate support and proper
/// error handling
class ApiClient {
  factory ApiClient() => _instance;
  ApiClient._();
  static final ApiClient _instance = ApiClient._();

  Dio? _dio;
  final _httpCache = HttpResponseCache();

  // Request deduplication: tracks active in-flight requests
  final Map<String, Future<Response>> _activeRequests = {};

  @visibleForTesting
  Dio? get testDio => _dio;

  String? _authToken;
  String? _cachedServerUrl;
  int _dioGeneration = 0;

  /// Completer for the deferred [NativeAdapter] setup.  Set on
  /// the first HTTP request; resolves once Cronet / cupertino_http
  /// is wired into [Dio.httpClientAdapter].  We deliberately keep
  /// the heavy JNI / FFI adapter creation off the cold-start
  /// critical path — `app.startup` only awaits the cheap base
  /// config, and the first HTTP call (during the auth check) pays
  /// the adapter-init cost in exchange for a faster first frame.
  Completer<void>? _nativeAdapterCompleter;
  int? _nativeAdapterGeneration;

  /// Initialize the Dio client with optional user CA certificates.
  ///
  /// The native HTTP adapter (Cronet on Android, cupertino_http
  /// on iOS) is **not** awaited here — it is created lazily on
  /// the first request via [_ensureNativeAdapter].  Cronet init
  /// hits the JNI bridge (50-200ms on cold start) and previously
  /// blocked the entire `app.startup` future.  When no requests
  /// fire (e.g. user is offline or logout flow), the adapter is
  /// never created and we save the init cost entirely.
  Future<void> initialize({required String serverUrl}) async {
    _cachedServerUrl = serverUrl;
    _disposeCurrentDio();
    await _configureDio(serverUrl);
  }

  /// Wire the native HTTP adapter into the underlying [Dio]
  /// instance.  Idempotent and safe to call from concurrent
  /// request paths — only the first caller performs the
  /// [createNativeAdapter] work; subsequent callers wait on the
  /// same in-flight future.
  Future<void> _ensureNativeAdapter(Dio dio, int generation) {
    final existing = _nativeAdapterCompleter;
    if (existing != null && _nativeAdapterGeneration == generation) {
      return existing.future;
    }
    final completer = Completer<void>();
    _nativeAdapterCompleter = completer;
    _nativeAdapterGeneration = generation;
    // Run on a microtask so the first request doesn't block
    // synchronously while we set up Cronet.  All callers await
    // the same completer, so concurrent first-requests serialize
    // on this single setup pass instead of each spawning their
    // own.
    scheduleMicrotask(() async {
      try {
        await _configureHttpClient(dio, generation);
        completer.complete();
      } catch (e, s) {
        // Surface the error to the waiting requests but don't
        // crash the app — the underlying Dio request will fail
        // and the existing error-handling chain (retry
        // interceptor, sentry capture) takes over.
        logger.warning('Error configuring native HTTP adapter: $e');
        unawaited(Sentry.captureException(e, stackTrace: s));
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<void> _configureDio(String serverUrl) async {
    final generation = ++_dioGeneration;
    final baseOptions = BaseOptions(
      baseUrl: serverUrl,
      // NOTE: on mobile these two are ONE budget, not two phases. The app
      // runs on NativeAdapter (Cronet / cupertino_http) via
      // ConversionLayerAdapter, which has no separate connect phase: it
      // computes `connectTimeout + receiveTimeout` and applies the sum as a
      // single `client.send(request).timeout(...)`, surfacing expiry as
      // DioExceptionType.receiveTimeout. So connectTimeout is NOT an
      // independent handshake bound and does NOT fail fast on a black-holed
      // route (stale cellular dial after wake) — the effective ceiling for
      // response headers is 8s + 15s = 23s here, and 8s + the per-request
      // receiveTimeout on calls that override it (e.g. message fetches).
      // Lower the *sum* to make requests fail faster; lowering only
      // connectTimeout does nothing on device.
      connectTimeout: const Duration(seconds: 8),
      // 15s default receive — the 60s fallback was excessive for chat
      // fetches and allowed Cronet stalls to hang for too long.
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
      responseType: ResponseType.json,
      // Every status is "valid": call sites inspect `response.statusCode`
      // instead of catching DioException. Consequence: Dio never raises for
      // a 4xx/5xx, so status-based classification (retry, re-auth) must
      // live in an onResponse interceptor — see [RetryInterceptor].
      validateStatus: (_) => true,
    );

    final dio = Dio(baseOptions);
    _dio = dio;

    // Native HTTP adapter (Cronet / cupertino_http) is wired
    // lazily on the first request via [_ensureNativeAdapter];
    // see [initialize] for the rationale.

    // Add retry interceptor first: it runs first on the response chain (so
    // it can classify status failures, which `validateStatus` keeps out of
    // the error chain) and last on the error chain.
    dio.interceptors.add(
      RetryInterceptor(
        dioGetter: () => dio,
        maxRetries: 3,
        baseDelayMs: 1000,
        maxDelayMs: 10000,
        maxTotalElapsedMs: 20000,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          options.headers['User-Agent'] = 'HappyFlutter/1.0';
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          return handler.next(error);
        },
      ),
    );
    if (sentryEnabled && sentryEnableDioInterceptor) {
      dio.addSentry();
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // A retried request re-enters onRequest with the *same*
          // RequestOptions instance, so close the previous attempt's span
          // before overwriting it — otherwise every failed attempt's span
          // is created and never ended (never exported), and the surviving
          // span reports only the last attempt's duration.
          _endRetriedAttemptSpan(options);
          final startedAtMs = DateTime.now().millisecondsSinceEpoch;
          options.extra['_otelStart'] = startedAtMs;
          options.extra['_otelFirstStart'] ??= startedAtMs;
          options.extra['_otelReqBytes'] = _estimateRequestBytes(options.data);
          // Parent the HTTP span under the active OTel span when one is
          // set on this isolate (e.g. chat.send_message wrapping the
          // outbound POST). This makes the request span a child of the
          // logical operation that triggered it, so the server-side
          // happy.daemon.spawn_session span (which extracts traceparent
          // from these headers) becomes a grandchild of chat.send_message
          // in the same trace.
          final activeSpan = OpenTelemetryService().currentSpan;
          final span = activeSpan != null
              ? OpenTelemetryService().startChildSpan(
                  _otelHttpSpanName(options),
                  parent: activeSpan,
                  kind: SpanKind.client,
                  attributes: _otelHttpAttributes(options),
                )
              : OpenTelemetryService().startTrace(
                  _otelHttpSpanName(options),
                  kind: SpanKind.client,
                  attributes: _otelHttpAttributes(options),
                );
          if (span != null) {
            // Only store live spans: the presence of this key means "a span
            // is open for the current attempt".
            options.extra['_otelSpan'] = span;
            injectTraceContext(span.spanContext, options);
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _finishOtelHttpSpan(
            response.requestOptions,
            statusCode: response.statusCode,
            responseBytes: _estimateResponseBytes(response),
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          _finishOtelHttpSpan(
            error.requestOptions,
            statusCode: error.response?.statusCode,
            responseBytes: error.response == null
                ? null
                : _estimateResponseBytes(error.response!),
            error: error,
            stackTrace: error.stackTrace,
          );
          return handler.next(error);
        },
      ),
    );

    // HTTP request tracker — records all requests to httpRequestLogger.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['_trackId'] = httpRequestLogger.takeNextId();
          options.extra['_trackStart'] = DateTime.now().millisecondsSinceEpoch;
          options.extra['_trackReqBytes'] = _estimateRequestBytes(options.data);
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _recordTrackedRequest(
            response.requestOptions,
            response.statusCode,
            _estimateResponseBytes(response),
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          _recordTrackedRequest(
            error.requestOptions,
            error.response?.statusCode,
            null,
          );
          return handler.next(error);
        },
      ),
    );

    // Cache last so cache hits still pass through auth, tracing, and
    // request-tracker interceptors before the response is resolved.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'GET' && options.extra['bypassCache'] != true) {
            final cachedResponse = _httpCache.get(options);
            if (cachedResponse != null) {
              options.extra['fromCache'] = true;
              return handler.resolve(
                Response<dynamic>(
                  data: cachedResponse.data,
                  requestOptions: options,
                  statusCode: cachedResponse.statusCode,
                  statusMessage: cachedResponse.statusMessage,
                  isRedirect: cachedResponse.isRedirect,
                  redirects: cachedResponse.redirects,
                  extra: cachedResponse.extra,
                  headers: cachedResponse.headers,
                ),
                // Run the response chain for cache hits too, otherwise the
                // span opened in onRequest is never ended (never exported)
                // and the request tracker never sees the hit. The cache's
                // own onResponse is a no-op here because `fromCache` is set.
                true,
              );
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (response.requestOptions.extra['bypassCache'] != true &&
              response.requestOptions.extra['fromCache'] != true) {
            _httpCache.put(response.requestOptions, response);
          }

          if (response.statusCode == 401) {
            logger.warning(
              'Received 401 - Unauthorized: '
              '${response.realUri}',
            );
          }
          if (response.statusCode == 403) {
            logger.info(
              'Received 403 - Forbidden: '
              '${response.realUri}',
            );
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          // Invalidate cache on POST/PUT/DELETE errors
          if (error.requestOptions.method == 'POST' ||
              error.requestOptions.method == 'PUT' ||
              error.requestOptions.method == 'DELETE') {
            _httpCache.invalidate(error.requestOptions.path);
          }

          // Build error message with fallback to error.error for
          // better debugging
          final errorMessage =
              error.message ?? error.error?.toString() ?? 'no message';
          // Downgrade transient connection errors (e.g. Cronet
          // aborting connections when the app is backgrounded)
          // to info so they don't create Sentry noise.
          if (isTransientConnectionError(error) ||
              error.response?.statusCode == 404) {
            logger.info(
              'Dio ${error.response?.statusCode == 404 ? '404' : 'transient'} '
              'error: $errorMessage\n'
              '  Request: ${error.requestOptions.method} '
              '${error.requestOptions.uri}',
            );
          } else {
            logger.warning(
              'Dio error: ${error.type} - $errorMessage\n'
              '  Request: ${error.requestOptions.method} '
              '${error.requestOptions.uri}',
              error,
              error.stackTrace,
            );
          }
          if (error.response?.statusCode == 401) {
            logger.warning(
              '401 Unauthorized response: '
              '${error.response?.data}',
            );
          }
          if (error.response?.statusCode == 403) {
            logger.warning(
              '403 Forbidden response: '
              '${error.response?.data}',
            );
          }
          return handler.next(error);
        },
      ),
    );
    assert(_dioGeneration == generation);
  }

  static Map<String, Object?> _otelHttpAttributes(RequestOptions options) {
    final uri = options.uri;
    final route = normalizePathForTracing(options.path);
    return {
      'http.request.method': options.method,
      'url.scheme': uri.scheme,
      'server.address': uri.host,
      'http.route': route,
      'http.request.body.size':
          options.extra['_otelReqBytes'] ?? _estimateRequestBytes(options.data),
      'http.cache_hit': options.extra['fromCache'] == true,
      if (options.extra[RetryInterceptor.retryCountKey] is int) ...{
        'http.retry_count':
            options.extra[RetryInterceptor.retryCountKey] as int,
        // 1-based index of the attempt this span covers.
        'http.attempt':
            (options.extra[RetryInterceptor.retryCountKey] as int) + 1,
      },
    };
  }

  static Map<String, Object?> _httpMetricAttributes(
    RequestOptions options, {
    required String phase,
    int? statusCode,
    DioException? error,
    String? outcomeOverride,
    String? errorTypeOverride,
  }) {
    final errorType = error?.type.name ?? errorTypeOverride;
    final outcome =
        outcomeOverride ??
        (error != null
            ? 'transport_error'
            : (statusCode != null && statusCode >= 400
                  ? 'http_error'
                  : 'success'));
    final retryCount = options.extra[RetryInterceptor.retryCountKey] as int?;
    return <String, Object?>{
      'http.request.method': options.method,
      'http.route': normalizePathForTracing(options.path),
      'phase': phase,
      'outcome': outcome,
      'http.cache_hit': options.extra['fromCache'] == true,
      if (statusCode != null) ...<String, Object?>{
        'http.response.status_code': statusCode,
        'http.response.status_class': _httpStatusClass(statusCode),
      },
      if (errorType != null) ...<String, Object?>{
        'error.type': errorType,
        'failure.phase': _httpFailurePhase(errorType),
      },
      if (retryCount != null) 'http.retry_count': retryCount,
    };
  }

  static String _httpStatusClass(int statusCode) {
    if (statusCode < 100 || statusCode > 599) return 'other';
    return '${statusCode ~/ 100}xx';
  }

  static String _httpFailurePhase(String errorType) => switch (errorType) {
    'connectionTimeout' || 'connectionError' => 'connect',
    'sendTimeout' => 'send',
    'receiveTimeout' => 'receive',
    'badCertificate' => 'tls',
    'badResponse' => 'response',
    'cancel' => 'cancel',
    _ => 'unknown',
  };

  static void _recordHttpDuration(
    RequestOptions options,
    Duration duration, {
    required String phase,
    int? statusCode,
    DioException? error,
    String? outcomeOverride,
    String? errorTypeOverride,
  }) {
    OpenTelemetryService().recordDuration(
      'app.http.client.duration',
      duration,
      attributes: _httpMetricAttributes(
        options,
        phase: phase,
        statusCode: statusCode,
        error: error,
        outcomeOverride: outcomeOverride,
        errorTypeOverride: errorTypeOverride,
      ),
      description: 'Client HTTP request duration by attempt and total phase',
    );
  }

  /// Ends the span of the attempt that just failed, if this request is
  /// being retried.
  ///
  /// [RetryInterceptor] re-issues the failed [RequestOptions] as-is, so the
  /// tracing interceptor sees the same `extra` map again. Without this the
  /// previous span is simply overwritten: it never ends, so the span
  /// processor never exports it and the retry sequence is invisible in
  /// Jaeger except for a `http.retry_count` attribute on the last attempt.
  static void _endRetriedAttemptSpan(RequestOptions options) {
    final span = options.extra['_otelSpan'] as OTelSpan?;
    if (span != null) options.extra.remove('_otelSpan');

    final startMs = options.extra['_otelStart'] as int?;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastStatus = options.extra[RetryInterceptor.lastStatusKey] as int?;
    final lastErrorType =
        options.extra[RetryInterceptor.lastErrorTypeKey] as String?;
    if (startMs != null) {
      final durationMs = max(0, nowMs - startMs);
      _recordHttpDuration(
        options,
        Duration(milliseconds: durationMs),
        phase: 'attempt',
        statusCode: lastStatus,
        outcomeOverride: 'retried',
        errorTypeOverride: lastErrorType,
      );
      span?.setAttribute('http.duration_ms', durationMs);
    }
    final retryCount = options.extra[RetryInterceptor.retryCountKey] as int?;
    if (retryCount != null) {
      span?.setAttribute('http.attempt', retryCount);
    }
    span
      ?..setAttribute('http.response.status_code', lastStatus)
      ..setAttribute('error.type', lastErrorType)
      ..setAttribute('http.attempt.retried', true)
      ..end(ok: false);
  }

  static String _otelHttpSpanName(RequestOptions options) {
    return '${options.method} ${normalizePathForTracing(options.path)}';
  }

  static void _finishOtelHttpSpan(
    RequestOptions options, {
    required int? statusCode,
    required int? responseBytes,
    DioException? error,
    StackTrace? stackTrace,
  }) {
    final span = options.extra['_otelSpan'] as OTelSpan?;
    // Drop the reference so a later interceptor pass (or a retry that
    // reuses these options) cannot end the same span twice.
    if (span != null) options.extra.remove('_otelSpan');

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final startMs = options.extra['_otelStart'] as int?;
    if (startMs != null) {
      final durationMs = max(0, nowMs - startMs);
      span?.setAttribute('http.duration_ms', durationMs);
      _recordHttpDuration(
        options,
        Duration(milliseconds: durationMs),
        phase: 'attempt',
        statusCode: statusCode,
        error: error,
      );
    }
    // Elapsed time across every attempt plus the backoff waits between
    // them — the number the user actually experienced.
    final firstStartMs = options.extra['_otelFirstStart'] as int?;
    if (firstStartMs != null) {
      final totalDurationMs = max(0, nowMs - firstStartMs);
      span?.setAttribute('http.total_duration_ms', totalDurationMs);
      _recordHttpDuration(
        options,
        Duration(milliseconds: totalDurationMs),
        phase: 'total',
        statusCode: statusCode,
        error: error,
      );
    }
    span
      ?..setAttribute('http.response.status_code', statusCode)
      ..setAttribute('http.response.body.size', responseBytes)
      ..setAttribute('http.cache_hit', options.extra['fromCache'] == true);
    final retryCount = options.extra[RetryInterceptor.retryCountKey] as int?;
    if (retryCount != null) {
      span
        ?..setAttribute('http.retry_count', retryCount)
        ..setAttribute('http.attempt', retryCount + 1);
    }
    if (error != null) {
      span
        ?..setAttribute('error.type', error.type.name)
        ..recordError(error, stackTrace);
    }
    span?.end(ok: error == null && (statusCode == null || statusCode < 500));
  }

  @visibleForTesting
  static Map<String, Object?> debugBuildHttpMetricAttributes(
    RequestOptions options, {
    required String phase,
    int? statusCode,
    DioException? error,
  }) {
    return _httpMetricAttributes(
      options,
      phase: phase,
      statusCode: statusCode,
      error: error,
    );
  }

  /// Injects the W3C trace context from [spanContext] into [options.headers].
  ///
  /// This makes the backend continue the same trace, so server-side spans
  /// show up as children of the mobile HTTP client span in Jaeger.
  @visibleForTesting
  static void injectTraceContext(
    SpanContext spanContext,
    RequestOptions options,
  ) {
    final context = OTel.context(spanContext: spanContext);
    final carrier = <String, String>{};
    W3CTraceContextPropagator().inject(
      context,
      carrier,
      _MapHeaderSetter(carrier),
    );
    options.headers.addAll(carrier);
  }

  @visibleForTesting
  static String normalizePathForTracing(String path) {
    final parsed = Uri.tryParse(path);
    final parsedPath = parsed?.path;
    final rawPath = parsedPath?.isNotEmpty ?? false ? parsedPath! : path;
    if (rawPath.isEmpty) return '/';

    final segments = rawPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(_normalizePathSegment)
        .toList();
    return '/${segments.join('/')}';
  }

  @visibleForTesting
  static Map<String, Object?> debugBuildOtelHttpAttributes(
    RequestOptions options,
  ) {
    return _otelHttpAttributes(options);
  }

  @visibleForTesting
  static String debugBuildOtelHttpSpanName(RequestOptions options) {
    return _otelHttpSpanName(options);
  }

  static String _normalizePathSegment(String segment) {
    if (RegExp(r'^\d+$').hasMatch(segment)) return ':id';
    if (RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(segment)) {
      return ':id';
    }
    if (segment.length >= 24 && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(segment)) {
      return ':id';
    }
    return segment;
  }

  static int _estimateRequestBytes(dynamic data) {
    if (data == null) return 0;
    if (data is String) return data.length;
    if (data is List<int>) return data.length;
    if (data is Map) return data.length * 250;
    if (data is List) return data.length * 150;
    return 0;
  }

  static int? _estimateResponseBytes(Response<dynamic> response) {
    final cl = response.headers.value(Headers.contentLengthHeader);
    if (cl != null) {
      final parsed = int.tryParse(cl);
      if (parsed != null && parsed > 0) return parsed;
    }
    final data = response.data;
    if (data == null) return 0;
    if (data is String) return data.length;
    if (data is List<int>) return data.length;
    // For Map/List, skip expensive jsonEncode — use rough approximation.
    if (data is Map) {
      // ~250 bytes per entry on average (keys + values overhead).
      return data.length * 250;
    }
    if (data is List) return data.length * 150;
    return null;
  }

  static void _recordTrackedRequest(
    RequestOptions options,
    int? statusCode,
    int? responseBytes,
  ) {
    final id = options.extra['_trackId'] as int?;
    final startMs = options.extra['_trackStart'] as int?;
    final requestBytes = options.extra['_trackReqBytes'] as int?;
    final now = DateTime.now();
    final durationMs = startMs != null
        ? now.millisecondsSinceEpoch - startMs
        : null;
    final timestamp = startMs != null
        ? DateTime.fromMillisecondsSinceEpoch(startMs)
        : now;
    final entry = HttpRequestEntry(
      id: id ?? httpRequestLogger.takeNextId(),
      timestamp: timestamp,
      method: options.method,
      path: options.path,
      statusCode: statusCode,
      requestBytes: requestBytes,
      responseBytes: responseBytes,
      durationMs: durationMs,
    );
    httpRequestLogger.record(entry);
    powerDiagnostics.recordHttpRequest(entry);

    final isSlow = (durationMs ?? 0) >= 1000;
    final isFailure = statusCode != null && statusCode >= 400;
    if (isSlow || isFailure) {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'HTTP request completed',
            category: 'http.performance',
            level: isFailure ? SentryLevel.warning : SentryLevel.info,
            data: {
              'method': options.method,
              'path': options.path,
              'statusCode': statusCode,
              'durationMs': durationMs,
              'requestBytes': requestBytes,
              'responseBytes': responseBytes,
              'cached': options.extra['fromCache'] == true,
            },
          ),
        ),
      );
    }
  }

  /// Refresh the server URL without restarting the app.
  /// Call this after changing the server URL in settings.
  Future<void> refreshServerUrl() async {
    final newUrl = getServerUrl();
    if (newUrl != _cachedServerUrl) {
      _cachedServerUrl = newUrl;
      _disposeCurrentDio();
      await _configureDio(newUrl);
      logger.info('Server URL refreshed to: $newUrl');
    }
  }

  /// Get the current server URL being used
  String? getCurrentServerUrl() => _cachedServerUrl;

  /// Configure HTTP client with Cronet engine.
  /// Cronet respects Android's network_security_config.xml and
  /// user-installed CA certificates.
  Future<void> _configureHttpClient(Dio dio, int generation) async {
    if (!identical(_dio, dio) || _dioGeneration != generation) {
      return;
    }
    try {
      // Use NativeAdapter which uses Cronet on Android
      // (cupertino_http on iOS/macOS). This automatically respects
      // Android's network_security_config.xml and user-installed CA
      // certificates in the Android trust store.
      final nativeAdapter = createNativeAdapter();
      if (!identical(_dio, dio) || _dioGeneration != generation) {
        nativeAdapter.close(force: true);
        return;
      }
      dio.httpClientAdapter = nativeAdapter;
      logger.info(
        'Native HTTP adapter configured for platform-specific CA support',
      );
    } catch (e, s) {
      logger.warning('Error configuring HTTP client: $e');
      unawaited(Sentry.captureException(e, stackTrace: s));
    }
  }

  /// Update authentication token
  void updateToken(String? token) {
    if (token != null && token.isEmpty) {
      logger.warning('Attempted to set empty auth token');
      return;
    }
    _authToken = token;
    if (_dio != null) {
      if (token != null) {
        _dio!.options.headers['Authorization'] = 'Bearer $token';
      } else {
        _dio!.options.headers.remove('Authorization');
      }
    }
  }

  /// Clear authentication token
  void clearToken() {
    _authToken = null;
    if (_dio != null) {
      _dio!.options.headers.remove('Authorization');
    }
  }

  /// GET request
  ///
  /// The dedup-key check/registration MUST stay synchronous (no `await`
  /// between reading and writing [_activeRequests]) — `get` previously
  /// awaited [_ensureAdapterForRequest] before checking the key, which let
  /// several callers issued in close succession (e.g. a resume/reconnect
  /// invalidation cascade firing the same sync from multiple call sites)
  /// all observe an empty dedup map and each fire an independent HTTP
  /// request to the same endpoint instead of sharing one.
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    final key = _generateRequestKey('GET', path, queryParameters);
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) return activeRequest;

    final tracked = _trackRequest(
      key,
      _issueGet(path, queryParameters, options),
    );
    _activeRequests[key] = tracked;
    return tracked;
  }

  /// Wraps [requestFuture] so [key] is removed from [_activeRequests] once
  /// it settles, regardless of success or failure, and returns the *same*
  /// future every caller (the original requester and any deduped callers)
  /// awaits.
  ///
  /// This MUST stay a single `async` function with `try`/`finally` rather
  /// than a second, independently-chained `.then()`/`.whenComplete()`
  /// listener attached to `requestFuture` (the previous approach, even
  /// after swallowing the error with `.then((_) {}, onError: (_) {})`
  /// before `.whenComplete()`). Verified with a standalone repro
  /// (`runZonedGuarded` + a throwing async call, with and without a
  /// second listener chain): attaching *any* second multicast listener
  /// to a future the real caller already awaits can still report the
  /// error to the current `Zone` as unhandled — surfacing as "ApiClient
  /// not initialized" failures in unrelated tests/screens (e.g.
  /// `ConnectedServicesLoader` in `account_screen_test.dart`) — even
  /// though the real caller's own `try`/`catch` handles it correctly.
  /// A `try`/`finally` inside one `async` function has no second
  /// listener: cleanup runs as part of resolving the one future everyone
  /// is already awaiting, so there is nothing left unobserved to report.
  Future<Response> _trackRequest(
    String key,
    Future<Response> requestFuture,
  ) async {
    try {
      return await requestFuture;
    } finally {
      // `Map.remove` returns the removed value, which here happens to be
      // a `Future<Response>` — the one we're already returning above —
      // so there's nothing meaningful to await; this is just a map
      // mutation for dedup bookkeeping.
      // ignore: unawaited_futures
      _activeRequests.remove(key);
    }
  }

  Future<Response> _issueGet(
    String path,
    Map<String, dynamic>? queryParameters,
    Options? options,
  ) async {
    final dio = await _ensureAdapterForRequest();
    return dio.get(path, queryParameters: queryParameters, options: options);
  }

  /// POST request
  ///
  /// See [get] for why the dedup-key check/registration must be synchronous.
  Future<Response> post(String path, {dynamic data, Options? options}) {
    final key = _generateRequestKey('POST', path, null, data);
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) return activeRequest;

    final tracked = _trackRequest(key, _issuePost(path, data, options));
    _activeRequests[key] = tracked;
    return tracked;
  }

  Future<Response> _issuePost(
    String path,
    dynamic data,
    Options? options,
  ) async {
    final dio = await _ensureAdapterForRequest();
    final response = await dio.post(path, data: data, options: options);
    // Invalidate cache entries matching this path
    _httpCache.invalidate(path);
    return response;
  }

  /// PUT request
  ///
  /// See [get] for why the dedup-key check/registration must be synchronous.
  Future<Response> put(String path, {dynamic data, Options? options}) {
    final key = _generateRequestKey('PUT', path, null, data);
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) return activeRequest;

    final tracked = _trackRequest(key, _issuePut(path, data, options));
    _activeRequests[key] = tracked;
    return tracked;
  }

  Future<Response> _issuePut(
    String path,
    dynamic data,
    Options? options,
  ) async {
    final dio = await _ensureAdapterForRequest();
    final response = await dio.put(path, data: data, options: options);
    // Invalidate cache entries matching this path
    _httpCache.invalidate(path);
    return response;
  }

  /// DELETE request
  ///
  /// See [get] for why the dedup-key check/registration must be synchronous.
  Future<Response> delete(String path, {Options? options}) {
    final key = _generateRequestKey('DELETE', path);
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) return activeRequest;

    final tracked = _trackRequest(key, _issueDelete(path, options));
    _activeRequests[key] = tracked;
    return tracked;
  }

  Future<Response> _issueDelete(String path, Options? options) async {
    final dio = await _ensureAdapterForRequest();
    final response = await dio.delete(path, options: options);
    // Invalidate cache entries matching this path
    _httpCache.invalidate(path);
    return response;
  }

  /// Upload file with progress
  Future<Response> uploadFile(
    String path,
    String filePath, {
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final dio = await _ensureAdapterForRequest();

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    return dio.post(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }

  /// Download file with progress
  Future<Response> downloadFile(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final dio = await _ensureAdapterForRequest();

    return dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }

  /// Check if response indicates authentication error (401 or 403)
  bool isAuthError(Response<dynamic> response) {
    return response.statusCode == 401 || response.statusCode == 403;
  }

  /// Check if response indicates success
  bool isSuccess(Response response) {
    return response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300;
  }

  /// Clear HTTP cache for a specific path pattern
  void clearCache(String pathPattern) {
    _httpCache.invalidate(pathPattern);
  }

  /// Clear all HTTP cache
  void clearAllCache() {
    _httpCache.clear();
  }

  /// Get HTTP cache statistics for debugging
  Map<String, int> getCacheStats() {
    return _httpCache.getStats();
  }

  @visibleForTesting
  void debugSeedCache(Response<dynamic> response) {
    _httpCache.put(response.requestOptions, response);
  }

  void _ensureInitialized() {
    if (_dio == null) {
      throw StateError('ApiClient not initialized. Call initialize() first.');
    }
  }

  /// Called by every request method before issuing a network
  /// call.  The first call kicks off the native adapter init and
  /// awaits it; subsequent calls are no-ops once the adapter is
  /// wired.  Request methods should call this instead of (or in
  /// addition to) [_ensureInitialized] so the underlying Dio
  /// always uses the Cronet / cupertino_http adapter.
  ///
  /// Returns the [Dio] instance that was validated at call time so
  /// callers can issue the request against a stable reference.  This
  /// avoids a race where [_dio] is nulled (e.g. by [dispose] or
  /// [refreshServerUrl]) between the adapter check and the actual
  /// request, which previously produced a "Null check operator used
  /// on a null value" TypeError from `_dio!.get()` etc.
  Future<Dio> _ensureAdapterForRequest() async {
    _ensureInitialized();
    final dio = _dio;
    if (dio == null) {
      throw StateError('ApiClient not initialized. Call initialize() first.');
    }
    final generation = _dioGeneration;
    await _ensureNativeAdapter(dio, generation);
    if (!identical(_dio, dio) || _dioGeneration != generation) {
      throw StateError('ApiClient was reconfigured during request startup.');
    }
    return dio;
  }

  /// Generate a unique key for request deduplication
  String _generateRequestKey(
    String method,
    String path, [
    Map<String, dynamic>? queryParameters,
    dynamic data,
  ]) {
    final buffer = StringBuffer('$method:$path');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final sortedParams = Map<String, dynamic>.fromEntries(
        queryParameters.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      );
      buffer
        ..write('?')
        ..write(
          sortedParams.entries.map((e) => '${e.key}=${e.value}').join('&'),
        );
    }
    if (data != null && (method == 'POST' || method == 'PUT')) {
      // For POST/PUT, include a content-based fingerprint of the data so
      // two calls with equal-but-distinct body objects (e.g. two separate
      // `{'a': 1}` map literals — the normal call shape in production
      // code) dedup onto the same key. `data.hashCode` previously used
      // here is identity-based for plain Maps/Lists (two literals with
      // identical content get different hash codes), which silently
      // defeated POST/PUT deduplication entirely — every call appeared
      // "unique" even when issued back-to-back with the same body.
      buffer
        ..write(':')
        ..write(_stableDataFingerprint(data));
    }
    return buffer.toString();
  }

  /// Best-effort content-based fingerprint for request bodies used in
  /// [_generateRequestKey]. JSON-encodes [data] when possible (covers the
  /// common `Map`/`List`/primitive bodies); falls back to [Object.toString]
  /// for anything that isn't JSON-encodable so dedup key generation never
  /// throws.
  static String _stableDataFingerprint(Object data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  /// Dispose resources
  void dispose() {
    _disposeCurrentDio();
  }

  void _disposeCurrentDio() {
    _dioGeneration++;
    _httpCache.clear();
    _activeRequests.clear();
    _nativeAdapterCompleter = null;
    _nativeAdapterGeneration = null;
    final dio = _dio;
    _dio = null;
    dio?.close(force: true);
  }
}

/// [TextMapSetter] that writes W3C propagation headers into a
/// [Map<String, String>] carrier.
class _MapHeaderSetter implements TextMapSetter<String> {
  const _MapHeaderSetter(this._carrier);

  final Map<String, String> _carrier;

  @override
  void set(String key, String value) {
    _carrier[key] = value;
  }
}
