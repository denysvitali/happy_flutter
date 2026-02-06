import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';
import 'mmkv_storage.dart';

const String defaultServerUrl = 'https://api.cluster-fluster.com';
const String _defaultServerUrl = defaultServerUrl;

/// Get the server URL from storage or use default
/// Priority: custom storage > env var > default
String getServerUrl() {
  final storage = ServerConfigStorage();
  final customUrl = storage.getServerUrl();

  if (customUrl != null && customUrl.isNotEmpty) {
    return customUrl;
  }

  // Check environment variable (development)
  const envUrl = String.fromEnvironment('HAPPY_SERVER_URL');
  if (envUrl.isNotEmpty) {
    return envUrl;
  }

  return _defaultServerUrl;
}

/// Set a custom server URL
void setServerUrl(String? url) {
  ServerConfigStorage().setServerUrl(url);
}

/// Check if using a custom server URL
bool isUsingCustomServer() {
  return ServerConfigStorage().isUsingCustomServer();
}

/// Save server URL error for display on auth screen
void saveServerUrlError(String error) {
  ServerConfigStorage().saveServerUrlError(error);
}

/// Get and clear the last server URL error
/// Returns null if no error is stored
String? getLastServerUrlError() {
  final storage = ServerConfigStorage();
  final error = storage.getLastServerUrlError();
  // Clear the error after reading
  storage.clearLastServerUrlError();
  return error;
}

/// Server URL verification result with diagnostic details
class ServerUrlVerificationResult {
  final bool isValid;
  final String? errorMessage;
  final String? errorType;

  const ServerUrlVerificationResult({
    required this.isValid,
    this.errorMessage,
    this.errorType,
  });

  /// Create a successful result
  const ServerUrlVerificationResult.success()
      : this(isValid: true, errorMessage: null, errorType: null);

  /// Create a failed result with details
  factory ServerUrlVerificationResult.failed(String message, [String? type]) {
    return ServerUrlVerificationResult(
      isValid: false,
      errorMessage: message,
      errorType: type ?? 'Unknown',
    );
  }
}

/// Server URL validation result
class ServerUrlValidation {
  final bool valid;
  final String? error;

  const ServerUrlValidation({required this.valid, this.error});
}

/// Validate a server URL
/// Checks: non-empty, valid URL format, http/https protocol
ServerUrlValidation validateServerUrl(String url) {
  if (!url.trim().isNotEmpty) {
    return const ServerUrlValidation(
      valid: false,
      error: 'Server URL cannot be empty',
    );
  }

  try {
    final uri = Uri.parse(url);
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return const ServerUrlValidation(
        valid: false,
        error: 'Server URL must use HTTP or HTTPS protocol',
      );
    }
    return const ServerUrlValidation(valid: true);
  } catch (e) {
    return ServerUrlValidation(
      valid: false,
      error: 'Invalid URL format: $e',
    );
  }
}

/// Verify server URL is reachable by making a simple request
/// Returns a ServerUrlVerificationResult with success status and diagnostic
/// details
Future<ServerUrlVerificationResult> verifyServerUrl(String url) async {
  final validation = validateServerUrl(url);
  if (!validation.valid) {
    debugPrint('Server URL validation failed: ${validation.error}');
    final errorMsg = 'Invalid server URL: ${validation.error}';
    saveServerUrlError(errorMsg);
    return ServerUrlVerificationResult.failed(errorMsg, 'Validation');
  }

  try {
    // Use NativeAdapter on supported native platforms so certificate trust
    // behavior matches the main API client.
    final dio = Dio();
    if (!kIsWeb) {
      dio.httpClientAdapter = NativeAdapter();
    }
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);

    final uri = Uri.parse(url);
    final configUri = uri.resolve('/v1/config');

    final response = await dio.get(configUri.toString());

    // Accept any 2xx, 3xx, or 401 (server up, auth required)
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 500) {
      return const ServerUrlVerificationResult.success();
    } else {
      final errorMsg = 'Server returned error: HTTP ${response.statusCode}';
      debugPrint('Server verification failed: $errorMsg');
      saveServerUrlError(errorMsg);
      return ServerUrlVerificationResult.failed(
        errorMsg,
        'HTTP ${response.statusCode}',
      );
    }
  } on DioException catch (e) {
    final errorMsg = 'Connection failed: ${_formatDioError(e)}';
    debugPrint('Server verification failed: $e');
    saveServerUrlError(errorMsg);

    // Categorize common Dio errors
    String errorType;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      errorType = 'Timeout';
    } else if (e.type == DioExceptionType.connectionError) {
      final errorStr = e.error.toString().toLowerCase();
      if (errorStr.contains('tls') || errorStr.contains('ssl') ||
          errorStr.contains('handshake') || errorStr.contains('certificate')) {
        errorType = 'SSL/TLS';
      } else if (errorStr.contains('connection refused')) {
        errorType = 'Connection Refused';
      } else {
        errorType = 'Network';
      }
    } else if (e.type == DioExceptionType.badResponse) {
      errorType = 'HTTP ${e.response?.statusCode}';
    } else {
      errorType = 'Unknown';
    }

    return ServerUrlVerificationResult.failed(errorMsg, errorType);
  } catch (e) {
    final errorMsg = 'Connection failed: ${e.toString()}';
    debugPrint('Server verification failed: $e');
    saveServerUrlError(errorMsg);
    return ServerUrlVerificationResult.failed(errorMsg, 'Unknown');
  }
}

String _formatDioError(DioException e) {
  final message = e.message?.trim();
  if (message != null && message.isNotEmpty && message != 'null') {
    return message;
  }

  final error = e.error?.toString().trim();
  if (error != null && error.isNotEmpty && error != 'null') {
    return error;
  }

  final status = e.response?.statusCode;
  if (status != null) {
    return 'HTTP $status';
  }

  return e.type.name;
}
