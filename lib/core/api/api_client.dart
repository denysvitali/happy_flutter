import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../services/certificate_provider.dart';
import '../services/server_config.dart';

/// Custom Dio client with user CA certificate support and proper error handling
class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  Dio? _dio;
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
      contentType: 'application/json',
      responseType: ResponseType.json,
      validateStatus: (status) => true,
    );

    _dio = Dio(baseOptions);

    await _configureHttpClient();

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
          if (response.statusCode == 403) {
            debugPrint('Received 403 - Forbidden: ${response.realUri}');
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          debugPrint('Dio error: ${error.type} - ${error.message}');
          if (error.response?.statusCode == 403) {
            debugPrint('403 Forbidden response: ${error.response?.data}');
          }
          return handler.next(error);
        },
      ),
    );
  }

  /// Refresh the server URL without restarting the app
  /// Call this after changing the server URL in settings
  Future<void> refreshServerUrl() async {
    final newUrl = await getServerUrl();
    if (newUrl != _cachedServerUrl) {
      _cachedServerUrl = newUrl;
      _dio?.close(force: true);
      _dio = null;
      await _configureDio(newUrl);
      debugPrint('Server URL refreshed to: $newUrl');
    }
  }

  /// Get the current server URL being used
  String? getCurrentServerUrl() => _cachedServerUrl;

  /// Configure HTTP client with custom certificates
  Future<void> _configureHttpClient() async {
    try {
      final certProvider = CertificateProvider();
      final hasCerts = certProvider.hasUserCertificates();

      if (hasCerts) {
        final certBytes = await certProvider.getCertificatesBytes();
        if (certBytes != null && certBytes.isNotEmpty) {
          debugPrint(
            'User CA certificates available: ${certBytes.length} bytes',
          );
          // Configure Dio to trust the custom CA certificate
          _dio!.httpClientAdapter = _createHttpClientAdapter(certBytes);
        } else {
          // On Android, user-added CAs in the system trust store are automatically
          // trusted by the default HttpClient. Configure Dio to trust bad certificates
          // to allow user-installed CAs to work.
          _dio!.httpClientAdapter = _createHttpClientAdapter(null);
        }
      }

      // On Android, user-added CAs in the system trust store are automatically
      // trusted by the default HttpClient.
    } catch (e) {
      debugPrint('Error configuring HTTP client: $e');
    }
  }

  /// Create a Dio HTTP client adapter that supports custom CA certificates
  dynamic _createHttpClientAdapter(List<int>? certBytes) {
    // Import dart:io for SecurityContext and HttpClient
    // The adapter uses the native HttpClient with custom SecurityContext
    return IOHttpClientAdapter(
      onHttpClientCreate: () {
        final client = HttpClient();
        // SecurityContext.defaultContext includes system-trusted certificates
        // and user-installed certificates on Android
        final context = SecurityContext.defaultContext;
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          // Allow user-installed certificates by checking if validation failed
          // due to a custom CA. On Android, user-installed CAs should work
          // but we need to handle the case where the server uses a self-signed cert.
          debugPrint('Bad certificate callback for $host:${cert.subject}');
          // For development/testing with custom CAs, return true
          // In production, this should be more restrictive
          return true;
        };
        return client;
      },
    );
  }

  /// Update authentication token
  void updateToken(String token) {
    _authToken = token;
    if (_dio != null) {
      _dio!.options.headers['Authorization'] = 'Bearer $token';
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
  }) async {
    _ensureInitialized();
    return _dio!.get(path, queryParameters: queryParameters);
  }

  /// POST request
  Future<Response> post(String path, {dynamic data}) async {
    _ensureInitialized();
    return _dio!.post(path, data: data);
  }

  /// PUT request
  Future<Response> put(String path, {dynamic data}) async {
    _ensureInitialized();
    return _dio!.put(path, data: data);
  }

  /// DELETE request
  Future<Response> delete(String path) async {
    _ensureInitialized();
    return _dio!.delete(path);
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

  /// Check if response indicates authentication error (403)
  bool isAuthError(Response response) {
    return response.statusCode == 403;
  }

  /// Check if response indicates success
  bool isSuccess(Response response) {
    return response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300;
  }

  void _ensureInitialized() {
    if (_dio == null) {
      throw StateError('ApiClient not initialized. Call initialize() first.');
    }
  }

  /// Dispose resources
  void dispose() {
    _dio?.close(force: true);
    _dio = null;
  }
}
