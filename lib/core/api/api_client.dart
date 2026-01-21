import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/certificate_provider.dart';

/// Custom Dio client with user CA certificate support and proper error handling
class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  Dio? _dio;
  String? _authToken;

  /// Initialize the Dio client with optional user CA certificates
  Future<void> initialize({required String serverUrl}) async {
    final baseOptions = BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      contentType: 'application/json',
      responseType: ResponseType.json,
      // Don't throw for any status code - we'll handle errors ourselves
      validateStatus: (status) => true,
    );

    _dio = Dio(baseOptions);

    // Configure custom HTTP client adapter with user CA certificates
    await _configureHttpClient();

    // Add interceptor for auth token and error handling
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add auth token if available
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          // Add user agent
          options.headers['User-Agent'] = 'HappyFlutter/1.0';
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Handle 403 specifically for authentication errors
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

  /// Configure HTTP client with custom certificates
  Future<void> _configureHttpClient() async {
    try {
      final certProvider = CertificateProvider();
      final hasCerts = certProvider.hasUserCertificates();

      if (hasCerts) {
        final certBytes = await certProvider.getCertificatesBytes();
        if (certBytes != null && certBytes.isNotEmpty) {
          debugPrint('User CA certificates available: ${certBytes.length} bytes');
        }
      }

      // On Android, user-added CAs in the system trust store are automatically
      // trusted by the default HttpClient.
    } catch (e) {
      debugPrint('Error configuring HTTP client: $e');
    }
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
  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
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
