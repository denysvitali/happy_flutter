import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../sentry_config.dart';
import '../services/http_request_logger.dart';
import '../services/logger_service.dart' show logger;
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

  /// Completer for the deferred [NativeAdapter] setup.  Set on
  /// the first HTTP request; resolves once Cronet / cupertino_http
  /// is wired into [Dio.httpClientAdapter].  We deliberately keep
  /// the heavy JNI / FFI adapter creation off the cold-start
  /// critical path — `app.startup` only awaits the cheap base
  /// config, and the first HTTP call (during the auth check) pays
  /// the adapter-init cost in exchange for a faster first frame.
  Completer<void>? _nativeAdapterCompleter;

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
    _configureDio(serverUrl);
  }

  /// Wire the native HTTP adapter into the underlying [Dio]
  /// instance.  Idempotent and safe to call from concurrent
  /// request paths — only the first caller performs the
  /// [createNativeAdapter] work; subsequent callers wait on the
  /// same in-flight future.
  Future<void> _ensureNativeAdapter() {
    final existing = _nativeAdapterCompleter;
    if (existing != null) {
      return existing.future;
    }
    final completer = Completer<void>();
    _nativeAdapterCompleter = completer;
    // Run on a microtask so the first request doesn't block
    // synchronously while we set up Cronet.  All callers await
    // the same completer, so concurrent first-requests serialize
    // on this single setup pass instead of each spawning their
    // own.
    scheduleMicrotask(() async {
      try {
        await _configureHttpClient();
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
    final baseOptions = BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    );

    _dio = Dio(baseOptions);

    // Native HTTP adapter (Cronet / cupertino_http) is wired
    // lazily on the first request via [_ensureNativeAdapter];
    // see [initialize] for the rationale.

    // Add retry interceptor first (executes last on error)
    _dio!.interceptors.add(
      RetryInterceptor(
        dioGetter: () => _dio!,
        maxRetries: 4,
        baseDelayMs: 1000,
        maxDelayMs: 10000,
      ),
    );

    // Add cache interceptor
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Check cache for GET requests
          if (options.method == 'GET' &&
              options.extra['bypassCache'] != true) {
            final cachedResponse = _httpCache.get(options);
            if (cachedResponse != null) {
              return handler.resolve(cachedResponse);
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Cache successful GET responses
          if (response.requestOptions.extra['bypassCache'] != true) {
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

    _dio!.interceptors.add(
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
      _dio!.addSentry();
    }

    // HTTP request tracker — records all requests to httpRequestLogger.
    _dio!.interceptors.add(
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
      _dio?.close(force: true);
      _dio = null;
      await _configureDio(newUrl);
      logger.info('Server URL refreshed to: $newUrl');
    }
  }

  /// Get the current server URL being used
  String? getCurrentServerUrl() => _cachedServerUrl;

  /// Configure HTTP client with Cronet engine.
  /// Cronet respects Android's network_security_config.xml and
  /// user-installed CA certificates.
  Future<void> _configureHttpClient() async {
    try {
      // Use NativeAdapter which uses Cronet on Android
      // (cupertino_http on iOS/macOS). This automatically respects
      // Android's network_security_config.xml and user-installed CA
      // certificates in the Android trust store.
      final nativeAdapter = createNativeAdapter();
      _dio!.httpClientAdapter = nativeAdapter;
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
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await _ensureAdapterForRequest();
    // Generate deduplication key
    final key = _generateRequestKey('GET', path, queryParameters);

    // Check if there's an active request for this key
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) return activeRequest;

    // Start the request and store it
    final requestFuture = _dio!.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
    _activeRequests[key] = requestFuture;

    try {
      final response = await requestFuture;
      return response;
    } finally {
      // Clean up after request completes (whether successful or not)
      unawaited(_activeRequests.remove(key));
    }
  }

  /// POST request
  Future<Response> post(String path, {dynamic data, Options? options}) async {
    await _ensureAdapterForRequest();
    // Generate deduplication key (includes data hash for mutations)
    final key = _generateRequestKey('POST', path, null, data);

    // Check if there's an active request for this key
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) return activeRequest;

    // Start the request and store it
    final requestFuture = _dio!.post(path, data: data, options: options);
    _activeRequests[key] = requestFuture;

    try {
      final response = await requestFuture;
      // Invalidate cache entries matching this path
      _httpCache.invalidate(path);
      return response;
    } finally {
      unawaited(_activeRequests.remove(key));
    }
  }

  /// PUT request
  Future<Response> put(String path, {dynamic data, Options? options}) async {
    await _ensureAdapterForRequest();
    // Generate deduplication key (includes data hash for mutations)
    final key = _generateRequestKey('PUT', path, null, data);

    // Check if there's an active request for this key
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) return activeRequest;

    // Start the request and store it
    final requestFuture = _dio!.put(path, data: data, options: options);
    _activeRequests[key] = requestFuture;

    try {
      final response = await requestFuture;
      // Invalidate cache entries matching this path
      _httpCache.invalidate(path);
      return response;
    } finally {
      unawaited(_activeRequests.remove(key));
    }
  }

  /// DELETE request
  Future<Response> delete(String path, {Options? options}) async {
    await _ensureAdapterForRequest();
    // Generate deduplication key for DELETE
    final key = _generateRequestKey('DELETE', path);

    // Check if there's an active request for this key
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) return activeRequest;

    // Start the request and store it
    final requestFuture = _dio!.delete(path, options: options);
    _activeRequests[key] = requestFuture;

    try {
      final response = await requestFuture;
      // Invalidate cache entries matching this path
      _httpCache.invalidate(path);
      return response;
    } finally {
      unawaited(_activeRequests.remove(key));
    }
  }

  /// Upload file with progress
  Future<Response> uploadFile(
    String path,
    String filePath, {
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    await _ensureAdapterForRequest();

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    return _dio!.post(
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
    await _ensureAdapterForRequest();

    return _dio!.download(
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
  Future<void> _ensureAdapterForRequest() async {
    _ensureInitialized();
    await _ensureNativeAdapter();
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
    _httpCache.clear();
    _dio?.close(force: true);
    _dio = null;
  }
}
