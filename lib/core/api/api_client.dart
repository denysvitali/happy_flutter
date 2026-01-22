import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  /// Configure HTTP client with Cronet engine
  /// Cronet respects Android's network_security_config.xml and user-installed CA certificates
  Future<void> _configureHttpClient() async {
    try {
      // Use NativeAdapter which uses Cronet on Android (cupertino_http on iOS/macOS)
      // This automatically respects Android's network_security_config.xml
      // and user-installed CA certificates in the Android trust store
      final nativeAdapter = NativeAdapter();
      _dio!.httpClientAdapter = nativeAdapter;
      debugPrint('Native HTTP adapter configured for platform-specific CA support');
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
