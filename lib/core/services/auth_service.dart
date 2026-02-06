import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../api/api_client.dart';
import '../encryption/crypto_box.dart';
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
    final seed = _encryption.randomBytes(32);
    final keypair = await _generateKeypair(seed);

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
    final secret = _encryption.randomBytes(32);
    final keypair = await _generateKeypair(secret);
    final challenge = _encryption.randomBytes(32);
    final signature = await _signChallenge(challenge, keypair.privateKey);

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
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        throw AuthException('Connection failed: ${_formatDioError(e)}');
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

      await _encryption.initialize(secret);

      final credentials =
          AuthCredentials(token: token, secret: base64Encode(secret));
      await TokenStorage().setCredentials(credentials);
      _apiClient.updateToken(token);
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
    final timeout = 120000;

    while (DateTime.now().millisecondsSinceEpoch - startTime < timeout) {
      try {
        final response = await _apiClient.post(
          '/v1/auth/account/request',
          data: {
            'publicKey': base64Encode(publicKey),
          },
        );

        if (response.statusCode == 403) {
          final serverResponse = _extractErrorMessage(response.data);
          throw AuthForbiddenError(
            'Authentication rejected by server (403).',
            serverResponse: serverResponse,
            diagnosticInfo: _getDiagnosticInfo(response),
          );
        }

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

        if (response.statusCode != null && response.statusCode! >= 500) {
          throw ServerError(
            'Please try again later.',
            statusCode: response.statusCode,
          );
        }

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;

          if (data['state'] == 'authorized') {
            final token = data['token'] as String;
            final encryptedResponse = data['response'] as String;

            final secret = await _decryptAuthSecret(encryptedResponse);

            if (secret != null) {
              await _encryption.initialize(secret);

              final credentials =
                  AuthCredentials(token: token, secret: base64Encode(secret));
              await TokenStorage().setCredentials(credentials);
              _apiClient.updateToken(token);

              return credentials;
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 1000));
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          debugPrint('Connection error during auth polling: ${e.message}');
          await Future.delayed(const Duration(milliseconds: 1000));
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
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } catch (e) {
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
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    throw ExpiredError('Authentication timed out after 2 minutes');
  }

  /// Complete authentication with token
  Future<AuthCredentials> completeAuth(String token, Uint8List secret) async {
    await _encryption.initialize(secret);

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
      await _verifyToken(credentials.token);
      return AuthState.authenticated;
    } catch (e) {
      if (e is AuthForbiddenError) {
        await signOut();
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
  Future<AuthCredentials> restoreAccount(String formattedKey) async {
    final secret = BackupKeyUtils.decodeKey(formattedKey);
    final keypair = await _generateKeypair(secret);
    final challenge = _encryption.randomBytes(32);
    final signature = await _signChallenge(challenge, keypair.privateKey);

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
        throw AuthException('Connection failed: ${_formatDioError(e)}');
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

      await _encryption.initialize(secret);

      final credentials =
          AuthCredentials(token: token, secret: base64Encode(secret));
      await TokenStorage().setCredentials(credentials);
      _apiClient.updateToken(token);

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
  Future<DeviceLinkingResult> startDeviceLinking() async {
    final seed = _encryption.randomBytes(32);
    final keypair = await _generateKeypair(seed);
    final serverUrl = _apiClient.getCurrentServerUrl();
    final encodedPublicKey = base64Encode(keypair.publicKey);

    try {
      await _apiClient.post(
        '/v1/auth/account/request',
        data: {
          'publicKey': encodedPublicKey,
        },
      );

      return DeviceLinkingResult(
        linkingId: encodedPublicKey,
        publicKey: keypair.publicKey,
        secret: seed,
      );
    } on DioException catch (e) {
      final errorMessage = '''
========================================
Device Linking Error
========================================
Server URL: $serverUrl
Endpoint: /v1/auth/account/request
Public Key: ${encodedPublicKey.substring(0, 30)}...
Status Code: ${e.response?.statusCode}
Response: ${e.response?.data}
Timestamp: ${DateTime.now().toIso8601String()}
========================================
''';
      print(errorMessage);

      throw AuthException('Failed to start device linking: ${e.response?.statusCode}');
    }
  }

  /// Wait for device linking approval
  Future<AuthCredentials> waitForLinkingApproval(String publicKey) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final timeout = 120000;

    while (DateTime.now().millisecondsSinceEpoch - startTime < timeout) {
      try {
        final response = await _apiClient.post(
          '/v1/auth/account/request',
          data: {'publicKey': publicKey},
        );

        if (response.statusCode == 403) {
          final serverResponse = _extractErrorMessage(response.data);
          throw AuthForbiddenError(
            'Device linking rejected by server (403).',
            serverResponse: serverResponse,
            diagnosticInfo: _getDiagnosticInfo(response),
          );
        }

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

        if (response.statusCode != null && response.statusCode! >= 500) {
          throw ServerError(
            'Please try again later.',
            statusCode: response.statusCode,
          );
        }

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;

          if (data['state'] == 'authorized') {
            final token = data['token'] as String;
            final encryptedResponse = data['response'] as String;

            final secret = await _decryptAuthSecret(encryptedResponse);

            if (secret != null) {
              await _encryption.initialize(secret);

              final credentials =
                  AuthCredentials(token: token, secret: base64Encode(secret));
              await TokenStorage().setCredentials(credentials);
              _apiClient.updateToken(token);

              return credentials;
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 1000));
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          await Future.delayed(const Duration(milliseconds: 1000));
        } else if (e.response?.statusCode == 403) {
          throw AuthForbiddenError(
            'Device linking rejected',
            serverResponse: e.response?.data?.toString(),
          );
        } else {
          debugPrint('Device linking error: $e');
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } catch (e) {
        debugPrint('Device linking error: $e');
        await Future.delayed(const Duration(milliseconds: 1000));
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
    if (seed.length != 32) {
      throw ArgumentError('Seed must be exactly 32 bytes');
    }

    final privateKey = newKeyFromSeed(seed);
    final publicKey = public(privateKey);

    return _KeyPair(
      privateKey: Uint8List.fromList(privateKey.bytes),
      publicKey: Uint8List.fromList(publicKey.bytes),
    );
  }

  /// Decrypt authentication secret
  Future<Uint8List?> _decryptAuthSecret(String encryptedBase64) async {
    try {
      final encrypted = base64Decode(encryptedBase64);
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

    final privateKeyObj = PrivateKey(privateKey);
    final signature = sign(privateKeyObj, challenge);
    return signature;
  }

  /// Parse a happy:// URL and extract the public key
  /// Supports formats:
  /// - happy://terminal?<base64_public_key>
  /// - happy:///account?<base64_public_key>
  static Uint8List? parseAuthUrl(String url) {
    try {
      if (!url.startsWith('happy://')) {
        return null;
      }

      final terminalPrefix = 'happy://terminal?';
      final accountPrefix = 'happy:///account?';

      String base64Key;
      if (url.startsWith(terminalPrefix)) {
        base64Key = url.substring(terminalPrefix.length);
      } else if (url.startsWith(accountPrefix)) {
        base64Key = url.substring(accountPrefix.length);
      } else {
        return null;
      }

      base64Key = base64Key.replaceAll('-', '+').replaceAll('_', '/');

      final padding = base64Key.length % 4;
      if (padding != 0) {
        base64Key += '=' * (4 - padding);
      }

      return base64Decode(base64Key);
    } catch (e) {
      debugPrint('Failed to parse auth URL: $e');
      return null;
    }
  }

  /// Approve a device linking request from a happy:// URL
  Future<bool> approveLinkingRequest(String url) async {
    final publicKey = parseAuthUrl(url);
    if (publicKey == null) {
      throw AuthException('Invalid auth URL format');
    }

    return approveLinkingWithPublicKey(publicKey);
  }

  /// Approve a device linking request with a public key
  Future<bool> approveLinkingWithPublicKey(Uint8List requesterPublicKey) async {
    final credentials = await TokenStorage().getCredentials();
    if (credentials == null) {
      throw AuthException('Not authenticated');
    }

    final secret = base64Decode(credentials.secret);
    // Use NaCl keypair for box encryption (not Ed25519)
    final keypair = await CryptoBox.keypairFromSeed(secret);

    final encryptedResponse = await CryptoBox.encrypt(
      secret,
      requesterPublicKey,
      keypair.secretKey,
    );

    final response = await _apiClient.post(
      '/v1/auth/account/response',
      data: {
        'publicKey': base64Encode(requesterPublicKey),
        'response': base64Encode(encryptedResponse),
      },
    );

    return response.statusCode == 200;
  }
}

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
  /// Format: happy:///account?<base64url_public_key>
  String getQRData() {
    final base64Key = base64Encode(publicKey);
    final base64UrlKey = base64Key
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
    return 'happy:///account?$base64UrlKey';
  }
}

class _KeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;

  _KeyPair({required this.privateKey, required this.publicKey});
}
