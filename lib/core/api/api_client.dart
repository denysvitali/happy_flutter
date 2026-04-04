import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/http_request_logger.dart';
import '../services/logger_service.dart' show logger;
import '../services/server_config.dart';
import 'native_adapter_helper.dart'
    if (dart.library.js_interop) 'native_adapter_helper_web.dart';

/// HTTP cache entry with response data and expiration
class _HttpCacheEntry {
  _HttpCacheEntry(this.response, this.expiresAt);

  final Response response;
  final int expiresAt;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch > expiresAt;
}

/// In-memory HTTP response cache for GET requests
class _HttpResponseCache {
  final _cache = <String, _HttpCacheEntry>{};

  static const int maxEntries = 200;
  static const int defaultMaxAge = 5 * 60 * 1000; // 5 minutes

  /// Generate cache key from request options
  String generateKey(RequestOptions options) {
    final buffer = StringBuffer(options.method)
      ..write(':')
      ..write(options.uri.path);
    if (options.queryParameters.isNotEmpty) {
      final sortedParams = Map<String, dynamic>.fromEntries(
        options.queryParameters.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      );
      buffer
        ..write('?')
        ..write(sortedParams.entries
            .map((e) => '${e.key}=${e.value}')
            .join('&'));
    }
    return buffer.toString();
  }

  /// Get cached response if available and not expired
  Response? get(RequestOptions options) {
    final key = generateKey(options);
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      logger.debug('HTTP cache hit: $key');
      return entry.response;
    }
    if (entry != null && entry.isExpired) {
      _cache.remove(key);
    }
    return null;
  }

  /// Cache a response with expiration time
  void put(RequestOptions options, Response response) {
    // Only cache successful GET requests
    if (options.method != 'GET') return;
    if (response.statusCode != 200) return;

    final maxAge = _parseMaxAge(response.headers);
    if (maxAge == 0) return; // no-store

    final key = generateKey(options);
    final expiresAt = DateTime.now().millisecondsSinceEpoch + maxAge;
    _cache[key] = _HttpCacheEntry(response, expiresAt);

    logger.debug('HTTP cache stored: $key (expires in $maxAge ms)');
    _evictOldest();
  }

  /// Invalidate cache entries matching a pattern
  void invalidate(String pathPattern) {
    final keysToRemove = _cache.keys
        .where((key) =>
            key.contains('GET:') && key.contains(pathPattern))
        .toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
      logger.debug('HTTP cache invalidated: $key');
    }
  }

  /// Clear all cached responses
  void clear() {
    _cache.clear();
    logger.info('HTTP cache cleared');
  }

  /// Get cache statistics for debugging
  Map<String, int> getStats() {
    final expiredCount = _cache.values
        .where((entry) => entry.isExpired)
        .length;
    return {
      'totalEntries': _cache.length,
      'activeEntries': _cache.length - expiredCount,
      'expiredEntries': expiredCount,
    };
  }

  /// Parse Cache-Control header to get max-age directive
  int _parseMaxAge(Headers headers) {
    final cacheControl =
        headers.value('cache-control')?.toLowerCase();
    if (cacheControl == null) return defaultMaxAge;

    // Check for no-store directive
    if (cacheControl.contains('no-store')) return 0;

    // Extract max-age value
    final maxAgeMatch =
        RegExp(r'max-age\s*=\s*(\d+)').firstMatch(cacheControl);
    if (maxAgeMatch != null) {
      final seconds = int.tryParse(maxAgeMatch.group(1) ?? '');
      if (seconds != null) return seconds * 1000;
    }

    return defaultMaxAge;
  }

  /// Evict oldest entries when cache exceeds max size
  void _evictOldest() {
    if (_cache.length <= maxEntries) return;

    final entries = _cache.entries.toList()
      ..sort((a, b) =>
          a.value.expiresAt.compareTo(b.value.expiresAt));

    final toRemove = entries.length - maxEntries;
    for (var i = 0; i < toRemove; i++) {
      _cache.remove(entries[i].key);
    }
  }
}

/// Returns true for transient connection errors that are not actionable
/// (e.g. Cronet aborting a request because the OS killed the connection
/// while the app was backgrounded).
bool _isTransientConnectionError(DioException error) {
  final inner = error.error?.toString() ?? '';
  return inner.contains('ERR_CONNECTION_ABORTED') ||
      inner.contains('ERR_CONNECTION_RESET') ||
      inner.contains('ERR_NAME_NOT_RESOLVED') ||
      inner.contains('ERR_CONNECTION_TIMED_OUT') ||
      inner.contains('ERR_NETWORK_CHANGED') ||
      inner.contains('ERR_INTERNET_DISCONNECTED') ||
      inner.contains('ERR_ADDRESS_UNREACHABLE') ||
      inner.contains('Failed host lookup') ||
      inner.contains('No address associated') ||
      inner.contains('Connection closed') ||
      inner.contains('Software caused connection abort');
}

/// Retry interceptor for Dio with exponential backoff
///
/// Retries transient failures:
/// - 5xx server errors (500-599)
/// - Network timeouts (connection, receive, send)
/// - Connection errors (SocketException, HttpException)
///
/// Does NOT retry:
/// - 4xx client errors (400-499) except 429 (rate limit)
/// - 401/403 auth errors (handled by auth layer)
/// - Cancellation errors
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor({
    required Dio Function() dioGetter,
    int maxRetries = 3,
    int baseDelayMs = 1000,
    int maxDelayMs = 10000,
  })  : _dioGetter = dioGetter,
        _maxRetries = maxRetries,
        _baseDelayMs = baseDelayMs,
        _maxDelayMs = maxDelayMs;

  final Dio Function() _dioGetter;
  final int _maxRetries;
  final int _baseDelayMs;
  final int _maxDelayMs;
  final Random _jitterRng = Random();

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Don't retry if request was cancelled
    if (err.type == DioExceptionType.cancel) {
      return handler.next(err);
    }

    // Don't retry 4xx client errors except 429 (rate limit)
    final responseStatusCode = err.response?.statusCode;
    if (responseStatusCode != null &&
        responseStatusCode >= 400 &&
        responseStatusCode < 500 &&
        responseStatusCode != 429) {
      return handler.next(err);
    }

    // Don't retry auth errors (401, 403)
    if (responseStatusCode == 401 || responseStatusCode == 403) {
      return handler.next(err);
    }

    // Check if this error is retryable
    if (!_isRetryable(err)) {
      return handler.next(err);
    }

    // Get current retry count from request options
    final currentRetry = err.requestOptions.extra['_retryCount'] as int? ?? 0;

    if (currentRetry >= _maxRetries) {
      logger.warning(
        'RetryInterceptor: max retries ($_maxRetries) exceeded for '
        '${err.requestOptions.method} ${err.requestOptions.path}',
      );
      return handler.next(err);
    }

    // Calculate delay with exponential backoff and jitter
    final delay = (_baseDelayMs * pow(2, currentRetry)).toInt();
    final jitter = _jitterRng.nextInt(251); // 0–250ms
    final clampedDelay = min(delay + jitter, _maxDelayMs);

    logger.info(
      'RetryInterceptor: retry ${currentRetry + 1}/$_maxRetries for '
      '${err.requestOptions.method} ${err.requestOptions.path} '
      'after $clampedDelay ms '
      '(error: ${err.type}, status: $responseStatusCode)',
    );

    // Wait before retry
    await Future<void>.delayed(
      Duration(milliseconds: clampedDelay),
    );

    // Increment retry count and retry request
    final retryOptions = err.requestOptions;
    retryOptions.extra['_retryCount'] = currentRetry + 1;

    try {
      final response = await _dioGetter().fetch(retryOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      // If retry fails, pass through onError again for potential retry
      return handler.next(e);
    } catch (e, s) {
      // Non-Dio errors should not be retried; log since this is unexpected
      logger.warning(
        'RetryInterceptor: unexpected non-Dio error during retry for '
        '${err.requestOptions.method} ${err.requestOptions.path}: $e',
        e,
        s,
      );
      return handler.next(
        DioException(
          requestOptions: err.requestOptions,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  bool _isRetryable(DioException err) {
    // Retry on 5xx server errors
    if (err.response?.statusCode != null &&
        err.response!.statusCode! >= 500 &&
        err.response!.statusCode! < 600) {
      return true;
    }

    // Retry on 429 (rate limit)
    if (err.response?.statusCode == 429) {
      return true;
    }

    // Retry on network timeouts
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return true;
    }

    // Retry on connection errors
    if (err.type == DioExceptionType.connectionError) {
      return true;
    }

    return false;
  }
}

/// Custom Dio client with user CA certificate support and proper error handling
class ApiClient {
  factory ApiClient() => _instance;
  ApiClient._();
  static final ApiClient _instance = ApiClient._();

  Dio? _dio;
  final _httpCache = _HttpResponseCache();

  // Request deduplication: tracks active in-flight requests
  final Map<String, Future<Response>> _activeRequests = {};

  @visibleForTesting
  Dio? get testDio => _dio;

  String? _authToken;
  String? _cachedServerUrl;

  /// Initialize the Dio client with optional user CA certificates
  Future<void> initialize({required String serverUrl}) async {
    _cachedServerUrl = serverUrl;
    await _configureDio(serverUrl);
  }

  Future<void> _configureDio(String serverUrl) async {
    final baseOptions = BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
      responseType: ResponseType.json,
    );

    _dio = Dio(baseOptions);

    await _configureHttpClient();

    // Add retry interceptor first (executes last on error)
    _dio!.interceptors.add(
      _RetryInterceptor(
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
          if (options.method == 'GET') {
            final cachedResponse = _httpCache.get(options);
            if (cachedResponse != null) {
              return handler.resolve(cachedResponse);
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Cache successful GET responses
          _httpCache.put(response.requestOptions, response);

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
          if (_isTransientConnectionError(error) ||
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
    _dio!.addSentry();

    // HTTP request tracker — records all requests to httpRequestLogger.
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['_trackId'] =
              httpRequestLogger.takeNextId();
          options.extra['_trackStart'] =
              DateTime.now().millisecondsSinceEpoch;
          options.extra['_trackReqBytes'] =
              _estimateRequestBytes(options.data);
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
    if (data is Map) {
      return data.length * 250;
    }
    if (data is List) {
      return data.length * 150;
    }
    return 0;
  }

  static int? _estimateResponseBytes(Response<dynamic> response) {
    final cl =
        response.headers.value(Headers.contentLengthHeader);
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
    if (data is List) {
      return data.length * 150;
    }
    return null;
  }

  static void _recordTrackedRequest(
    RequestOptions options,
    int? statusCode,
    int? responseBytes,
  ) {
    final id = options.extra['_trackId'] as int?;
    final startMs = options.extra['_trackStart'] as int?;
    final requestBytes =
        options.extra['_trackReqBytes'] as int?;
    final now = DateTime.now();
    final durationMs = startMs != null
        ? now.millisecondsSinceEpoch - startMs
        : null;
    final timestamp = startMs != null
        ? DateTime.fromMillisecondsSinceEpoch(startMs)
        : now;
    httpRequestLogger.record(
      HttpRequestEntry(
        id: id ?? httpRequestLogger.takeNextId(),
        timestamp: timestamp,
        method: options.method,
        path: options.path,
        statusCode: statusCode,
        requestBytes: requestBytes,
        responseBytes: responseBytes,
        durationMs: durationMs,
      ),
    );
  }

  /// Refresh the server URL without restarting the app
  /// Call this after changing the server URL in settings
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

  /// Configure HTTP client with Cronet engine
  /// Cronet respects Android's network_security_config.xml and
  /// user-installed CA certificates
  Future<void> _configureHttpClient() async {
    try {
      // Use NativeAdapter which uses Cronet on Android (cupertino_http on iOS/macOS)
      // This automatically respects Android's network_security_config.xml
      // and user-installed CA certificates in the Android trust store
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
        _dio!.options.headers['Authorization'] =
            'Bearer $token';
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
    _ensureInitialized();
    // Generate deduplication key
    final key = _generateRequestKey('GET', path, queryParameters);

    // Check if there's an active request for this key
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) {
      return activeRequest;
    }

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
    _ensureInitialized();
    // Generate deduplication key (includes data hash for mutations)
    final key = _generateRequestKey('POST', path, null, data);

    // Check if there's an active request for this key
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) {
      return activeRequest;
    }

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
    _ensureInitialized();
    // Generate deduplication key (includes data hash for mutations)
    final key = _generateRequestKey('PUT', path, null, data);

    // Check if there's an active request for this key
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) {
      return activeRequest;
    }

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
    _ensureInitialized();
    // Generate deduplication key for DELETE
    final key = _generateRequestKey('DELETE', path);

    // Check if there's an active request for this key
    final activeRequest = _activeRequests[key];
    if (activeRequest != null) {
      return activeRequest;
    }

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
    _ensureInitialized();

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
    _ensureInitialized();

    return _dio!.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
    );
  }

  /// Check if response indicates authentication error
  /// (401 or 403)
  bool isAuthError(Response<dynamic> response) {
    return response.statusCode == 401 ||
        response.statusCode == 403;
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
        ..write(sortedParams.entries
            .map((e) => '${e.key}=${e.value}')
            .join('&'));
    }
    if (data != null && (method == 'POST' || method == 'PUT')) {
      // For POST/PUT, include a hash of the data to differentiate requests
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
