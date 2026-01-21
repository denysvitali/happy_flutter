import 'dart:convert';
import 'dart:typed_data';
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
            final credentials = AuthCredentials(token: token, secret: base64Encode(secret));
            await TokenStorage().setCredentials(credentials);

            return credentials;
          }
        } else if (response.statusCode == 202) {
          // Still waiting, continue polling
          await Future.delayed(const Duration(milliseconds: 1000));
        } else {
          throw Exception('Unexpected response: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Auth polling error: $e');
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    throw ExpiredError('Authentication timed out');
  }

  /// Complete authentication with token
  Future<AuthCredentials> completeAuth(String token, Uint8List secret) async {
    // Initialize encryption with the secret
    await _encryption.initialize(secret);

    // Store credentials
    final credentials = AuthCredentials(token: token, secret: base64Encode(secret));
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
      return AuthState.error;
    }
  }

  /// Verify token with server
  Future<void> _verifyToken(String token) async {
    final serverUrl = await _getServerUrl();
    await _apiClient.get(
      '$serverUrl/v1/auth/verify',
      queryParameters: {'token': token},
    );
  }

  /// Sign out
  Future<void> signOut() async {
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
