import 'dart:async';

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
      connectTimeout: const Duration(seconds: 30),
      // 15s default receive — the 60s fallback was excessive for chat
      // fetches and allowed Cronet stalls to hang for too long.
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    );

    final dio = Dio(baseOptions);
    _dio = dio;

    // Native HTTP adapter (Cronet / cupertino_http) is wired
    // lazily on the first request via [_ensureNativeAdapter];
    // see [initialize] for the rationale.

    // Add retry interceptor first (executes last on error)
    dio.interceptors.add(
      RetryInterceptor(
        dioGetter: () => dio,
        maxRetries: 4,
        baseDelayMs: 1000,
        maxDelayMs: 10000,
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
          options.extra['_otelStart'] = DateTime.now().millisecondsSinceEpoch;
          options.extra['_otelReqBytes'] = _estimateRequestBytes(options.data);
          // Parent the HTTP span under the active OTel span when one is
          // set on this isolate (e.g. chat.send_message wrapping the
          // outbound POST). This makes the request span a child of the
          // logical operation that triggered it, so the server-side
          // happy.daemon.spawn_session span (which extracts traceparent
          // from these headers) becomes a grandchild of chat.send_message
          // in the same trace.
          final activeSpan = OpenTelemetryService().currentSpan;
          if (activeSpan != null) {
            options.extra['_otelSpan'] = OpenTelemetryService().startChildSpan(
              _otelHttpSpanName(options),
              parent: activeSpan,
              kind: SpanKind.client,
              attributes: _otelHttpAttributes(options),
            );
          } else {
            options.extra['_otelSpan'] = OpenTelemetryService().startTrace(
              _otelHttpSpanName(options),
              kind: SpanKind.client,
              attributes: _otelHttpAttributes(options),
            );
          }
          final span = options.extra['_otelSpan'] as OTelSpan?;
          if (span != null) {
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
      if (options.extra['_retryCount'] is int)
        'http.retry_count': options.extra['_retryCount'] as int,
    };
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
    if (span == null) return;

    final startMs = options.extra['_otelStart'] as int?;
    if (startMs != null) {
      span.setAttribute(
        'http.duration_ms',
        DateTime.now().millisecondsSinceEpoch - startMs,
      );
    }
    span
      ..setAttribute('http.response.status_code', statusCode)
      ..setAttribute('http.response.body.size', responseBytes)
      ..setAttribute('http.cache_hit', options.extra['fromCache'] == true);
    if (options.extra['_retryCount'] is int) {
      span.setAttribute(
        'http.retry_count',
        options.extra['_retryCount'] as int,
      );
    }
    if (error != null) {
      span
        ..setAttribute('error.type', error.type.name)
        ..recordError(error, stackTrace);
    }
    span.end(ok: error == null && (statusCode == null || statusCode < 500));
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

    final requestFuture = _issueGet(path, queryParameters, options);
    _activeRequests[key] = requestFuture;
    _scheduleDedupCleanup(key, requestFuture);
    return requestFuture;
  }

  /// Removes [key] from [_activeRequests] once [requestFuture] settles,
  /// regardless of success or failure.
  ///
  /// MUST swallow the error itself rather than chaining `.whenComplete()`
  /// directly off `requestFuture` and passing that to `unawaited()`:
  /// `.whenComplete()` returns a brand-new Future that re-throws on
  /// rejection, and `unawaited()` is a no-op type marker — it does not
  /// attach an error handler. The real caller already awaits and handles
  /// `requestFuture` itself, but the second, derived Future from
  /// `.whenComplete()` would be left with no listener, surfacing as an
  /// unhandled async error (and failing whatever test happens to be
  /// running when it settles) on every failed request.
  void _scheduleDedupCleanup(String key, Future<Response> requestFuture) {
    unawaited(
      requestFuture
          .then((_) {}, onError: (_) {})
          .whenComplete(() => _activeRequests.remove(key)),
    );
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

    final requestFuture = _issuePost(path, data, options);
    _activeRequests[key] = requestFuture;
    _scheduleDedupCleanup(key, requestFuture);
    return requestFuture;
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

    final requestFuture = _issuePut(path, data, options);
    _activeRequests[key] = requestFuture;
    _scheduleDedupCleanup(key, requestFuture);
    return requestFuture;
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

    final requestFuture = _issueDelete(path, options);
    _activeRequests[key] = requestFuture;
    _scheduleDedupCleanup(key, requestFuture);
    return requestFuture;
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
      // For POST/PUT, include a hash of the data to differentiate
      // requests
      buffer
        ..write(':')
        ..write(data.hashCode);
    }
    return buffer.toString();
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
