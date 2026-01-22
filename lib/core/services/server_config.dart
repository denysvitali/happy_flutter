import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _serverUrlKey = 'custom_server_url';
const String _lastServerUrlErrorKey = 'last_server_url_error';
const String defaultServerUrl = 'https://api.cluster-fluster.com';
const String _defaultServerUrl = defaultServerUrl;

/// Get the server URL from storage or use default
/// Priority: custom storage > env var > default
Future<String> getServerUrl() async {
  final prefs = await SharedPreferences.getInstance();

  // Check custom storage first
  final customUrl = prefs.getString(_serverUrlKey);
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
Future<void> setServerUrl(String? url) async {
  final prefs = await SharedPreferences.getInstance();

  if (url != null && url.trim().isNotEmpty) {
    await prefs.setString(_serverUrlKey, url.trim());
  } else {
    await prefs.remove(_serverUrlKey);
  }
}

/// Check if using a custom server URL
Future<bool> isUsingCustomServer() async {
  final url = await getServerUrl();
  return url != _defaultServerUrl;
}

/// Save server URL error for display on auth screen
Future<void> saveServerUrlError(String error) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_lastServerUrlErrorKey, error);
}

/// Get and clear the last server URL error
/// Returns null if no error is stored
Future<String?> getLastServerUrlError() async {
  final prefs = await SharedPreferences.getInstance();
  final error = prefs.getString(_lastServerUrlErrorKey);
  // Clear the error after reading
  await prefs.remove(_lastServerUrlErrorKey);
  return error;
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
/// Returns true if the server responds
Future<bool> verifyServerUrl(String url) async {
  final validation = validateServerUrl(url);
  if (!validation.valid) {
    debugPrint('Server URL validation failed: ${validation.error}');
    await saveServerUrlError('Invalid server URL: ${validation.error}');
    return false;
  }

  try {
    // Try to connect to the server with a timeout
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    final uri = Uri.parse(url);
    final configUri = uri.resolve('/v1/config');
    final request = await client.getUrl(configUri);
    final response = await request.close().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        client.close();
        throw SocketException('Connection timeout');
      },
    );

    client.close();

    // Accept any 2xx, 3xx, or 401 (which means server is up but auth required)
    return response.statusCode >= 200 && response.statusCode < 500;
  } catch (e) {
    final errorMsg = 'Server unreachable: ${e.toString()}';
    debugPrint('Server verification failed: $e');
    await saveServerUrlError(errorMsg);
    return false;
  }
}
