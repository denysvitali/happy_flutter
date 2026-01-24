import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../api/api_client.dart';
import '../models/auth.dart';
import '../models/profile.dart';
import 'encryption_service.dart';
import 'storage_service.dart';
import '../utils/backup_key_utils.dart';

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
    await _apiClient.post(
      '/v1/auth/account/request',
      data: {
        'publicKey': base64Encode(keypair.publicKey),
      },
    );

    return keypair.publicKey;
  }

  /// Create a new account
  Future<void> createAccount() async {
    // Generate a random secret
    final secret = _encryption.randomBytes(32);

    // Generate keypair from secret
    final keypair = await _generateKeypair(secret);

    // Generate a challenge
    final challenge = _encryption.randomBytes(32);

    // Sign the challenge with our private key
    final signature = await _signChallenge(challenge, keypair.privateKey);

    // Request a new token from the server
    Response response;
    try {
      response = await _apiClient.post(
        '/v1/auth',
        data: {
          'challenge': base64Encode(challenge),
          'signature': base64Encode(signature),
          'publicKey': base64Encode(keypair.publicKey),
        },
      );
    } on DioException catch (e) {
      // Handle Dio-specific errors
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw AuthException('Connection failed: ${e.message}');
      } else if (e.type == DioExceptionType.badResponse) {
        final statusCode = e.response?.statusCode;
        final errorMsg = _extractErrorMessage(e.response?.data);
        if (statusCode != null && statusCode >= 500) {
          throw ServerError(
            errorMsg,
            statusCode: statusCode,
          );
        } else if (statusCode == 403) {
          throw AuthForbiddenError(
            errorMsg,
            serverResponse: e.response?.data?.toString(),
          );
        } else if (statusCode != null && statusCode >= 400) {
          throw AuthRequestError(
            errorMsg,
            statusCode: statusCode,
            serverResponse: e.response?.data?.toString(),
          );
        }
      }
      throw AuthException('Request failed: ${e.message}');
    }

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;

      // Initialize encryption with the secret
      await _encryption.initialize(secret);

      // Store credentials
      final credentials =
          AuthCredentials(token: token, secret: base64Encode(secret));
      await TokenStorage().setCredentials(credentials);
    } else if (response.statusCode == 409) {
      throw AuthRequestError(
        'Account already exists',
        statusCode: 409,
      );
    } else if (response.statusCode != null && response.statusCode! >= 500) {
      final errorMsg = _extractErrorMessage(response.data);
      throw ServerError(
        errorMsg,
        statusCode: response.statusCode,
      );
    } else if (response.statusCode != null && response.statusCode! >= 400) {
      final errorMsg = _extractErrorMessage(response.data);
      throw AuthRequestError(
        errorMsg,
        statusCode: response.statusCode,
      );
    } else {
      throw AuthException('Failed to create account: ${response.statusCode}');
    }
  }

  /// Wait for authentication approval
  Future<AuthCredentials> waitForAuthApproval(Uint8List publicKey) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final timeout = 120000; // 2 minutes

    while (DateTime.now().millisecondsSinceEpoch - startTime < timeout) {
      try {
        // Poll for auth token
        final response = await _apiClient.post(
          '/v1/auth/account/wait',
          data: {
            'publicKey': base64Encode(publicKey),
          },
        );

        // Check for 403 Forbidden - indicates server rejected the request
        if (response.statusCode == 403) {
          final serverResponse = _extractErrorMessage(response.data);
          throw AuthForbiddenError(
            'Authentication rejected by server (403).',
            serverResponse: serverResponse,
            diagnosticInfo: _getDiagnosticInfo(response),
          );
        }

        // Check for other client errors (4xx)
        if (response.statusCode != null &&
            response.statusCode! >= 400 &&
            response.statusCode! < 500) {
          final errorMsg = _extractErrorMessage(response.data);
          throw AuthRequestError(
            errorMsg,
            statusCode: response.statusCode,
            serverResponse: response.data?.toString(),
          );
        }

        // Check for server errors (5xx)
        if (response.statusCode != null && response.statusCode! >= 500) {
          throw ServerError(
            'Please try again later.',
            statusCode: response.statusCode,
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
          // Still waiting, continue polling with reduced frequency
          await Future.delayed(const Duration(milliseconds: 2500));
        } else {
          throw Exception('Unexpected response: ${response.statusCode}');
        }
      } on DioException catch (e) {
        // Handle Dio-specific errors
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          debugPrint('Connection error during auth polling: ${e.message}');
          await Future.delayed(const Duration(milliseconds: 2500));
        } else if (e.response?.statusCode == 403) {
          final serverResponse = _extractErrorMessage(e.response?.data);
          throw AuthForbiddenError(
            'Authentication rejected by server (403).',
            serverResponse: serverResponse,
            diagnosticInfo: 'DioException: ${e.message}',
          );
        } else if (e.error != null &&
            (e.error.toString().contains('Tls') ||
                e.error.toString().contains('Handshake') ||
                e.error.toString().contains('Certificate') ||
                e.error.toString().contains('SSL'))) {
          throw SSLError(
            'SSL/TLS handshake failed.',
            certificateInfo: e.message,
          );
        } else {
          debugPrint('Dio error during auth polling: $e');
          await Future.delayed(const Duration(milliseconds: 2500));
        }
      } catch (e) {
        // Check if it's a network-related SSL error using string checks
        // (dart:io exceptions not available on web)
        final errorStr = e.toString();
        if (errorStr.contains('Handshake') ||
            errorStr.contains('Tls') ||
            errorStr.contains('Certificate') ||
            errorStr.contains('SSL')) {
          throw SSLError(
            'SSL/TLS error during authentication.',
            certificateInfo: e.toString(),
          );
        }
        debugPrint('Auth polling error: $e');
        await Future.delayed(const Duration(milliseconds: 2500));
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
    final response = await _apiClient.get(
      '/v1/auth/verify',
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

  /// Restore account from backup key
  /// Takes a formatted backup key (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)
  Future<AuthCredentials> restoreAccount(String formattedKey) async {
    // Decode the backup key
    final secret = BackupKeyUtils.decodeKey(formattedKey);

    // Generate keypair from secret
    final keypair = await _generateKeypair(secret);

    // Generate a challenge
    final challenge = _encryption.randomBytes(32);

    // Sign the challenge with our private key
    final signature = await _signChallenge(challenge, keypair.privateKey);

    // Request account restoration
    Response response;
    try {
      response = await _apiClient.post(
        '/v1/auth/restore',
        data: {
          'challenge': base64Encode(challenge),
          'signature': base64Encode(signature),
          'publicKey': base64Encode(keypair.publicKey),
        },
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw AuthException('Connection failed: ${e.message}');
      } else if (e.type == DioExceptionType.badResponse) {
        final statusCode = e.response?.statusCode;
        final errorMsg = _extractErrorMessage(e.response?.data);
        if (statusCode == 403) {
          throw AuthForbiddenError(
            errorMsg,
            serverResponse: e.response?.data?.toString(),
          );
        } else if (statusCode == 404) {
          throw AuthRequestError(
            'Account not found. Please check your backup key.',
            statusCode: 404,
          );
        } else if (statusCode != null && statusCode >= 400) {
          throw AuthRequestError(
            errorMsg,
            statusCode: statusCode,
            serverResponse: e.response?.data?.toString(),
          );
        }
      }
      throw AuthException('Request failed: ${e.message}');
    }

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;

      // Initialize encryption with the secret
      await _encryption.initialize(secret);

      // Store credentials
      final credentials =
          AuthCredentials(token: token, secret: base64Encode(secret));
      await TokenStorage().setCredentials(credentials);

      return credentials;
    } else if (response.statusCode == 404) {
      throw AuthRequestError(
        'Account not found. Please check your backup key and try again.',
        statusCode: 404,
      );
    } else {
      throw AuthException('Failed to restore account: ${response.statusCode}');
    }
  }

  /// Get current user's profile
  Future<Profile?> getProfile() async {
    try {
      final response = await _apiClient.get('/v1/profile');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return Profile.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  /// Get connected services
  Future<List<ConnectedServiceInfo>> getConnectedServices() async {
    try {
      final response = await _apiClient.get('/v1/services');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final services = data['services'] as List<dynamic>?;
        if (services != null) {
          return services
              .map((s) => ConnectedServiceInfo.fromJson(s as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching connected services: $e');
      return [];
    }
  }

  /// Start device linking process
  /// Returns a linking token to display in QR code
  Future<DeviceLinkingResult> startDeviceLinking() async {
    // Generate a random seed for the linking keypair
    final seed = _encryption.randomBytes(32);

    // Generate keypair from seed
    final keypair = await _generateKeypair(seed);

    // Request linking from server
    final response = await _apiClient.post(
      '/v1/devices/link/start',
      data: {
        'publicKey': base64Encode(keypair.publicKey),
      },
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final linkingId = data['linking_id'] as String;

      return DeviceLinkingResult(
        linkingId: linkingId,
        publicKey: keypair.publicKey,
        secret: seed,
      );
    } else {
      throw AuthException('Failed to start device linking: ${response.statusCode}');
    }
  }

  /// Wait for device linking approval
  Future<AuthCredentials> waitForLinkingApproval(String linkingId) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final timeout = 120000; // 2 minutes

    while (DateTime.now().millisecondsSinceEpoch - startTime < timeout) {
      try {
        final response = await _apiClient.post(
          '/v1/devices/link/wait',
          data: {'linking_id': linkingId},
        );

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final token = data['token'] as String;
          final encryptedSecret = data['secret'] as String;

          // Decrypt the secret
          final secret = await _decryptAuthSecret(encryptedSecret);

          if (secret != null) {
            await _encryption.initialize(secret);

            final credentials =
                AuthCredentials(token: token, secret: base64Encode(secret));
            await TokenStorage().setCredentials(credentials);

            return credentials;
          }
        } else if (response.statusCode == 202) {
          // Still waiting
          await Future.delayed(const Duration(milliseconds: 2500));
        } else {
          throw AuthException('Unexpected response: ${response.statusCode}');
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          await Future.delayed(const Duration(milliseconds: 2500));
        } else if (e.response?.statusCode == 403) {
          throw AuthForbiddenError(
            'Device linking rejected',
            serverResponse: e.response?.data?.toString(),
          );
        } else {
          debugPrint('Device linking error: $e');
          await Future.delayed(const Duration(milliseconds: 2500));
        }
      } catch (e) {
        debugPrint('Device linking error: $e');
        await Future.delayed(const Duration(milliseconds: 2500));
      }
    }

    throw ExpiredError('Device linking timed out after 2 minutes');
  }

  /// Get linked devices
  Future<List<DeviceInfo>> getLinkedDevices() async {
    try {
      final response = await _apiClient.get('/v1/devices');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final devices = data['devices'] as List<dynamic>?;
        if (devices != null) {
          return devices
              .map((d) => DeviceInfo.fromJson(d as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching devices: $e');
      return [];
    }
  }

  /// Unlink a device
  Future<bool> unlinkDevice(String deviceId) async {
    try {
      final response = await _apiClient.delete('/v1/devices/$deviceId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error unlinking device: $e');
      return false;
    }
  }

  /// Generate backup key from current credentials
  Future<String> generateBackupKey() async {
    final credentials = await TokenStorage().getCredentials();
    if (credentials == null) {
      throw AuthException('Not authenticated');
    }

    final secret = base64Decode(credentials.secret);
    return BackupKeyUtils.encodeKey(secret);
  }

  /// Get account backup info
  Future<AccountBackupInfo?> getAccountBackupInfo() async {
    try {
      final response = await _apiClient.get('/v1/backup');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return AccountBackupInfo.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching backup info: $e');
      return null;
    }
  }

  /// Generate Ed25519 keypair from seed
  Future<_KeyPair> _generateKeypair(Uint8List seed) async {
    // Ed25519 requires a 32-byte seed
    if (seed.length != 32) {
      throw ArgumentError('Seed must be exactly 32 bytes');
    }

    // Generate Ed25519 keypair from seed
    final privateKey = newKeyFromSeed(seed);
    final publicKey = public(privateKey);

    // Convert to Uint8List for storage and use
    return _KeyPair(
      privateKey: Uint8List.fromList(privateKey.bytes),
      publicKey: Uint8List.fromList(publicKey.bytes),
    );
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
    if (data is String) {
      return data;
    }
    return 'Unknown error';
  }

  /// Get diagnostic information from response
  String _getDiagnosticInfo(Response response) {
    final uri = response.realUri.toString();
    final statusCode = response.statusCode;
    return 'URL: $uri\nStatus: $statusCode';
  }

  /// Sign a challenge using Ed25519 detached signature
  Future<Uint8List> _signChallenge(
    Uint8List challenge,
    Uint8List privateKey,
  ) async {
    if (kIsWeb) {
      throw UnimplementedError(
        'Challenge signing not yet implemented on web platform. '
        'Use Web Crypto API for full web functionality.',
      );
    }

    // Wrap the private key bytes in a PrivateKey object
    final privateKeyObj = PrivateKey(privateKey);

    // Ed25519 detached signature
    final signature = sign(privateKeyObj, challenge);
    return signature;
  }
}

/// Result of starting a device linking process
class DeviceLinkingResult {
  final String linkingId;
  final Uint8List publicKey;
  final Uint8List secret;

  DeviceLinkingResult({
    required this.linkingId,
    required this.publicKey,
    required this.secret,
  });

  /// Get the QR code data for this linking
  String getQRData() {
    return 'happy://link/$linkingId';
  }
}

class _KeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;

  _KeyPair({required this.privateKey, required this.publicKey});
}

/// Custom exception for 403 Forbidden authentication errors
class AuthForbiddenError extends AuthException {
  final String? serverResponse;
  final String? diagnosticInfo;

  AuthForbiddenError(
    super.message, {
    this.serverResponse,
    this.diagnosticInfo,
  });

  @override
  String toString() {
    var result = message;
    if (diagnosticInfo != null) {
      result += '\n\nDiagnostic: $diagnosticInfo';
    }
    if (serverResponse != null) {
      result += '\nServer response: $serverResponse';
    }
    return result;
  }
}

/// Custom exception for client request errors (4xx)
class AuthRequestError extends AuthException {
  final int? statusCode;
  final String? serverResponse;

  AuthRequestError(
    super.message, {
    this.statusCode,
    this.serverResponse,
  });

  @override
  String toString() {
    var result = 'Error $statusCode: $message';
    if (serverResponse != null) {
      result += '\nServer response: $serverResponse';
    }
    return result;
  }
}

/// Custom exception for server errors (5xx)
class ServerError extends AuthException {
  final int? statusCode;

  ServerError(super.message, {this.statusCode});

  @override
  String toString() {
    return 'Server error (${statusCode ?? 500}): $message';
  }
}

/// Custom exception for SSL/TLS errors
class SSLError extends AuthException {
  final String? certificateInfo;

  SSLError(
    super.message, {
    this.certificateInfo,
  });

  @override
  String toString() {
    var result = message;
    if (certificateInfo != null) {
      result += '\nCertificate info: $certificateInfo';
    }
    return result;
  }
}
