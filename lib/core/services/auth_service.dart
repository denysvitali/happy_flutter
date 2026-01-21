import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models/auth.dart';
import 'encryption_service.dart';
import 'storage_service.dart';

/// Authentication service handling QR-based authentication flow
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final _apiClient = ApiClient();
  final _encryption = EncryptionService();

  /// Start QR authentication
  /// Returns the public key to display in QR code
  Future<Uint8List> startQRAuth() async {
    // Generate random seed for keypair
    final seed = _encryption.randomBytes(32);

    // Generate keypair from seed
    final keypair = await _generateKeypair(seed);

    // Send auth request to server
    final serverUrl = await _getServerUrl();
    await _apiClient.post(
      '$serverUrl/v1/auth/account/request',
      data: {
        'publicKey': base64Encode(keypair.publicKey),
      },
    );

    return keypair.publicKey;
  }

  /// Wait for authentication approval
  Future<AuthCredentials> waitForAuthApproval(Uint8List publicKey) async {
    final serverUrl = await _getServerUrl();
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final timeout = 120000; // 2 minutes

    while (DateTime.now().millisecondsSinceEpoch - startTime < timeout) {
      try {
        // Poll for auth token
        final response = await _apiClient.post(
          '$serverUrl/v1/auth/account/wait',
          data: {
            'publicKey': base64Encode(publicKey),
          },
        );

        // Check for 403 Forbidden - indicates server rejected the request
        if (response.statusCode == 403) {
          throw AuthForbiddenError(
            'Authentication rejected by server (403). '
            'Possible causes: Invalid public key, expired request, or server policy.',
          );
        }

        // Check for other client errors (4xx)
        if (response.statusCode != null &&
            response.statusCode! >= 400 &&
            response.statusCode! < 500) {
          final errorMsg = _extractErrorMessage(response.data);
          throw AuthRequestError(
            'Client error (${response.statusCode}): $errorMsg',
          );
        }

        // Check for server errors (5xx)
        if (response.statusCode != null && response.statusCode! >= 500) {
          throw ServerError(
            'Server error (${response.statusCode}). Please try again later.',
          );
        }

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final token = data['token'] as String;
          final encryptedSecret = data['secret'] as String;

          // Decrypt the secret using our keypair
          final secret = await _decryptAuthSecret(encryptedSecret);

          if (secret != null) {
            // Initialize encryption with the secret
            await _encryption.initialize(secret);

            // Store credentials
            final credentials =
                AuthCredentials(token: token, secret: base64Encode(secret));
            await TokenStorage().setCredentials(credentials);

            return credentials;
          }
        } else if (response.statusCode == 202) {
          // Still waiting, continue polling
          await Future.delayed(const Duration(milliseconds: 1000));
        } else {
          throw Exception('Unexpected response: ${response.statusCode}');
        }
      } on DioException catch (e) {
        // Handle Dio-specific errors
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          debugPrint('Connection error during auth polling: ${e.message}');
          await Future.delayed(const Duration(milliseconds: 2000));
        } else if (e.response?.statusCode == 403) {
          throw AuthForbiddenError(
            'Authentication rejected by server (403). '
            'The server refused this authentication request.',
          );
        } else {
          debugPrint('Dio error during auth polling: $e');
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } catch (e) {
        // Check if it's a network-related SSL error
        if (e is HandshakeException || e is TlsException) {
          throw SSLError(
            'SSL/TLS error during authentication. '
            'This may indicate a certificate trust issue. '
            'Ensure the server certificate is trusted by your device.',
          );
        }
        debugPrint('Auth polling error: $e');
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    throw ExpiredError('Authentication timed out after 2 minutes');
  }

  /// Complete authentication with token
  Future<AuthCredentials> completeAuth(String token, Uint8List secret) async {
    // Initialize encryption with the secret
    await _encryption.initialize(secret);

    // Store credentials
    final credentials =
        AuthCredentials(token: token, secret: base64Encode(secret));
    await TokenStorage().setCredentials(credentials);

    return credentials;
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return TokenStorage().isAuthenticated();
  }

  /// Get current authentication state
  Future<AuthState> getAuthState() async {
    final credentials = await TokenStorage().getCredentials();
    if (credentials == null) {
      return AuthState.unauthenticated;
    }

    try {
      // Verify token is still valid
      await _verifyToken(credentials.token);
      return AuthState.authenticated;
    } catch (e) {
      // Check if it's a 403 - token is invalid/revoked
      if (e is AuthForbiddenError) {
        await signOut(); // Clean up invalid credentials
        return AuthState.unauthenticated;
      }
      return AuthState.error;
    }
  }

  /// Verify token with server
  Future<void> _verifyToken(String token) async {
    final serverUrl = await _getServerUrl();
    final response = await _apiClient.get(
      '$serverUrl/v1/auth/verify',
      queryParameters: {'token': token},
    );

    if (response.statusCode == 403) {
      throw AuthForbiddenError('Token is invalid or has been revoked');
    }

    if (!_apiClient.isSuccess(response)) {
      throw Exception('Token verification failed: ${response.statusCode}');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _apiClient.clearToken();
    await TokenStorage().removeCredentials();
  }

  /// Generate keypair for QR auth
  Future<_KeyPair> _generateKeypair(Uint8List seed) async {
    // Simplified Ed25519 keypair generation
    // In production, use a proper cryptographic library
    final privateKey = seed;
    final publicKey = Uint8List(32);

    // For demo, just use the seed hash as public key
    for (int i = 0; i < 32; i++) {
      publicKey[i] = privateKey[i] ^ 0x12;
    }

    return _KeyPair(privateKey: privateKey, publicKey: publicKey);
  }

  /// Decrypt authentication secret
  Future<Uint8List?> _decryptAuthSecret(String encryptedBase64) async {
    try {
      final encrypted = base64Decode(encryptedBase64);
      // Simplified - in production use proper Box decryption
      return _encryption.decryptSecretBox(encrypted);
    } catch (e) {
      debugPrint('Failed to decrypt auth secret: $e');
      return null;
    }
  }

  /// Extract error message from response data
  String _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('error')) {
        return data['error'].toString();
      }
      if (data.containsKey('message')) {
        return data['message'].toString();
      }
    }
    return 'Unknown error';
  }

  /// Get server URL from config
  Future<String> _getServerUrl() async {
    // In production, load from environment/config
    return 'https://api.happy.dev';
  }
}

class _KeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;

  _KeyPair({required this.privateKey, required this.publicKey});
}

/// Custom exception for 403 Forbidden authentication errors
class AuthForbiddenError extends AuthException {
  AuthForbiddenError(super.message);
}

/// Custom exception for client request errors (4xx)
class AuthRequestError extends AuthException {
  AuthRequestError(super.message);
}

/// Custom exception for server errors (5xx)
class ServerError extends AuthException {
  ServerError(super.message);
}

/// Custom exception for SSL/TLS errors
class SSLError extends AuthException {
  SSLError(super.message);
}
