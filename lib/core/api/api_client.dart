import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/certificate_provider.dart';

/// Custom Dio client with user CA certificate support
class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  Dio? _dio;
  String? _serverUrl;
  String? _authToken;

  /// Initialize the Dio client with optional user CA certificates
  Future<void> initialize({required String serverUrl}) async {
    _serverUrl = serverUrl;

    final baseOptions = BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      contentType: 'application/json',
      responseType: ResponseType.json,
    );

    _dio = Dio(baseOptions);

    // Add user CA certificates on Android
    final certBytes = await CertificateProvider().getCertificatesBytes();
    if (certBytes != null) {
      // Configure Dio to use custom certificates
      // Note: This requires additional configuration via SecurityContext
      // For full implementation, you would need a custom HttpClientAdapter
      debugPrint('User CA certificates loaded: ${certBytes.length} bytes');
    }
  }

  /// Update authentication token
  void updateToken(String token) {
    _authToken = token;
    if (_dio != null) {
      _dio!.options.headers['Authorization'] = 'Bearer $token';
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
