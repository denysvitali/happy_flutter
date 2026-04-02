import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sodium/sodium.dart' show SecureKey, Sodium;

import '../api/api_client.dart';
import '../encryption/crypto_box.dart';
import '../encryption/sodium_loader.dart';
import '../models/auth.dart';
import '../models/profile.dart';
import '../utils/backup_key_utils.dart';
import 'encryption_service.dart';
import 'logger_service.dart' show logger;
import 'storage_service.dart';
import 'sync_service.dart';

/// Per-flow configuration for [_waitForApproval].
class _ApprovalFlowConfig {
  const _ApprovalFlowConfig({
    required this.label,
    required this.requestData,
    required this.getSecretKey,
    required this.clearSecretKey,
    required this.disposeCachedKeypairOnError,
    required this.handleSslErrors,
    required this.timeoutMessage,
    required this.dioForbiddenMessage,
    required this.dioForbiddenUsesExtractErrorMessage,
  });
  final String label;
  final Map<String, dynamic> requestData;
  final SecureKey? Function() getSecretKey;
  final void Function() clearSecretKey;
  final bool disposeCachedKeypairOnError;
  final bool handleSslErrors;
  final String timeoutMessage;
  /// Message and serverResponse style for DioException 403.
  final String dioForbiddenMessage;
  final bool dioForbiddenUsesExtractErrorMessage;
}

/// Authentication service handling QR-based authentication flow
class AuthService {
  factory AuthService() => _instance;
  AuthService._();
  static final AuthService _instance = AuthService._();

  final _apiClient = ApiClient();
  final _encryption = EncryptionService();

  // Pending secret keys for in-progress auth flows (NaCl box, X25519)
  SecureKey? _pendingQRSecretKey;
  SecureKey? _pendingLinkingSecretKey;

  // Sodium instance for Ed25519 signing
  static Sodium? _sodium;
  static Future<Sodium> get _sodiumInstance async {
    _sodium ??= await loadSodium();
    return _sodium!;
  }

  /// Start QR authentication
  /// Returns the public key to display in QR code
  Future<Uint8List> startQRAuth() async {
    _pendingQRSecretKey?.dispose();
    final keypair = await CryptoBox.generateKeypair();
    _pendingQRSecretKey = keypair.secretKey;

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
      await _persistCredentials(credentials);
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
    return _waitForApproval(
      _ApprovalFlowConfig(
        label: 'Authentication',
        requestData: {'publicKey': base64Encode(publicKey)},
        getSecretKey: () => _pendingQRSecretKey,
        clearSecretKey: () => _pendingQRSecretKey = null,
        disposeCachedKeypairOnError: true,
        handleSslErrors: true,
        timeoutMessage: 'Authentication timed out after 2 minutes',
        dioForbiddenMessage: 'Authentication rejected by server (403).',
        dioForbiddenUsesExtractErrorMessage: true,
      ),
    );
  }

  /// Complete authentication with token
  Future<AuthCredentials> completeAuth(String token, Uint8List secret) async {
    await _encryption.initialize(secret);

    final credentials =
        AuthCredentials(token: token, secret: base64Encode(secret));
    await _persistCredentials(credentials);

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
    try {
      final response = await _apiClient.get(
        '/v1/auth/verify',
        queryParameters: {'token': token},
      );
      if (!_apiClient.isSuccess(response)) {
        throw Exception(
          'Token verification failed: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw AuthForbiddenError('Token is invalid or has been revoked');
      }
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _cachedKeypairSecret?.dispose();
    _cachedKeypairSecret = null;
    _pendingQRSecretKey?.dispose();
    _pendingQRSecretKey = null;
    _pendingLinkingSecretKey?.dispose();
    _pendingLinkingSecretKey = null;
    _apiClient.clearToken();
    await TokenStorage().removeCredentials();
  }

  /// Restore account from backup key
  /// Uses the same /v1/auth endpoint as createAccount
  Future<AuthCredentials> restoreAccount(String formattedKey) async {
    final secret = BackupKeyUtils.decodeKey(formattedKey);
    final keypair = await _generateKeypair(secret);
    final challenge = _encryption.randomBytes(32);
    final signature = await _signChallenge(challenge, keypair.privateKey);

    Response response;
    try {
      // Use /v1/auth endpoint (same as createAccount)
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
        if (statusCode == 403) {
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
      await _persistCredentials(credentials);
      _apiClient.updateToken(token);

      return credentials;
    } else if (response.statusCode != null && response.statusCode! >= 400) {
      final errorMsg = _extractErrorMessage(response.data);
      throw AuthRequestError(
        errorMsg,
        statusCode: response.statusCode,
      );
    } else {
      throw AuthException(
        'Failed to restore account: ${response.statusCode}',
      );
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
      logger.warning('Error fetching profile: $e');
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
              .map(
                (s) => ConnectedServiceInfo.fromJson(s as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      logger.warning('Error fetching connected services: $e');
      return [];
    }
  }

  /// Start device linking process
  Future<DeviceLinkingResult> startDeviceLinking() async {
    _pendingLinkingSecretKey?.dispose();
    final seed = _encryption.randomBytes(32);
    final keypair = await CryptoBox.keypairFromSeed(seed);
    _pendingLinkingSecretKey = keypair.secretKey;
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
Response: [omitted]
Timestamp: ${DateTime.now().toIso8601String()}
========================================
''';
      logger.warning(errorMessage);

      throw AuthException(
        'Failed to start device linking: ${e.response?.statusCode}',
      );
    }
  }

  /// Wait for device linking approval
  Future<AuthCredentials> waitForLinkingApproval(String publicKey) async {
    return _waitForApproval(
      _ApprovalFlowConfig(
        label: 'Device linking',
        requestData: {'publicKey': publicKey},
        getSecretKey: () => _pendingLinkingSecretKey,
        clearSecretKey: () => _pendingLinkingSecretKey = null,
        disposeCachedKeypairOnError: false,
        handleSslErrors: false,
        timeoutMessage: 'Device linking timed out after 2 minutes',
        dioForbiddenMessage: 'Device linking rejected',
        dioForbiddenUsesExtractErrorMessage: false,
      ),
    );
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
      logger.warning('Error fetching devices: $e');
      return [];
    }
  }

  /// Unlink a device
  Future<bool> unlinkDevice(String deviceId) async {
    try {
      final response = await _apiClient.delete('/v1/devices/$deviceId');
      return response.statusCode == 200;
    } catch (e) {
      logger.warning('Error unlinking device: $e');
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
      logger.warning('Error fetching backup info: $e');
      return null;
    }
  }

  /// Generate Ed25519 keypair from seed
  Future<_KeyPair> _generateKeypair(Uint8List seed) async {
    if (seed.length != 32) {
      throw ArgumentError('Seed must be exactly 32 bytes');
    }

    final sodium = await _sodiumInstance;

    // Use seedKeyPair to derive the keypair from the seed
    // This gives us the proper Ed25519 keypair
    final seedKey = SecureKey.fromList(sodium, seed);
    final keypair = sodium.crypto.sign.seedKeyPair(seedKey);
    seedKey.dispose();

    // Get the public key bytes
    final publicKeyBytes = Uint8List.fromList(keypair.publicKey);

    // For _KeyPair storage, we store the seed (for compatibility with the
    // original format). The actual signing will be done using the keypair's
    // secretKey. We need to cache this for later use.

    // Store the seed (32 bytes) as the private key - this is what gets
    // serialized. The _cachedKeypairSecret will be used for actual signing.
    _cachedKeypairSecret = keypair.secretKey;

    return _KeyPair(
      privateKey: Uint8List.fromList(seed),
      publicKey: publicKeyBytes,
    );
  }

  // Cached secret key for signing (the 64-byte extended Ed25519 secret key)
  SecureKey? _cachedKeypairSecret;

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

  /// Dispose [_cachedKeypairSecret] if [condition] is true.
  void _disposeCachedKeypairIf(bool condition) {
    if (condition) {
      _cachedKeypairSecret?.dispose();
      _cachedKeypairSecret = null;
    }
  }

  Future<void> _persistCredentials(AuthCredentials credentials) async {
    final tokenStorage = TokenStorage();
    final previous = await tokenStorage.getCredentials();
    final changedAccountContext =
        previous != null &&
        (previous.token != credentials.token ||
            previous.secret != credentials.secret);

    if (changedAccountContext && sync.isInitialized) {
      logger.info(
        'Auth credentials changed; shutting down sync and clearing cached '
        'encrypted state before reinitialization.',
      );
      await syncShutdown();
    }

    await tokenStorage.setCredentials(credentials);
  }

  /// Sign a challenge using Ed25519 detached signature
  Future<Uint8List> _signChallenge(
    Uint8List challenge,
    Uint8List privateKey,
  ) async {
    final sodium = await _sodiumInstance;

    // Use the cached secret key if available (from _generateKeypair)
    // This is the proper 64-byte extended Ed25519 secret key
    final secretKey = _cachedKeypairSecret ??
        SecureKey.fromList(sodium, privateKey);

    final signature = sodium.crypto.sign.detached(
      message: challenge,
      secretKey: secretKey,
    );

    // Only dispose if we created it from the privateKey (not cached)
    if (_cachedKeypairSecret == null) {
      secretKey.dispose();
    }

    return signature;
  }

  /// Shared polling loop for both QR auth and device linking approval.
  Future<AuthCredentials> _waitForApproval(
    _ApprovalFlowConfig config,
  ) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    const timeout = 120000;

    while (DateTime.now().millisecondsSinceEpoch - startTime < timeout) {
      try {
        final response = await _apiClient.post(
          '/v1/auth/account/request',
          data: config.requestData,
          options: Options(validateStatus: (_) => true),
        );

        if (response.statusCode == 403) {
          _disposeCachedKeypairIf(config.disposeCachedKeypairOnError);
          throw AuthForbiddenError(
            '${config.label} rejected by server (403).',
            serverResponse: _extractErrorMessage(response.data),
            diagnosticInfo: _getDiagnosticInfo(response),
          );
        }

        if (response.statusCode != null &&
            response.statusCode! >= 400 &&
            response.statusCode! < 500) {
          final errorMsg = _extractErrorMessage(response.data);
          _disposeCachedKeypairIf(config.disposeCachedKeypairOnError);
          throw AuthRequestError(
            errorMsg,
            statusCode: response.statusCode,
            serverResponse: response.data?.toString(),
          );
        }

        if (response.statusCode != null && response.statusCode! >= 500) {
          _disposeCachedKeypairIf(config.disposeCachedKeypairOnError);
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

            final secretKey = config.getSecretKey();
            final secret = secretKey == null
                ? null
                : await CryptoBox.decrypt(
                    base64Decode(encryptedResponse),
                    secretKey,
                  );

            if (secret != null) {
              await _encryption.initialize(secret);

              final credentials =
                  AuthCredentials(
                    token: token,
                    secret: base64Encode(secret),
                  );
              await _persistCredentials(credentials);
              _apiClient.updateToken(token);
              config.clearSecretKey();

              return credentials;
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 1000));
      } on DioException catch (e) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          logger.warning(
            'Connection error during ${config.label.toLowerCase()} '
            'polling: ${e.message}',
          );
          await Future.delayed(const Duration(milliseconds: 1000));
        } else if (e.response?.statusCode == 403) {
          _disposeCachedKeypairIf(config.disposeCachedKeypairOnError);
          final serverResponse =
              config.dioForbiddenUsesExtractErrorMessage
                  ? _extractErrorMessage(e.response?.data)
                  : e.response?.data?.toString();
          throw AuthForbiddenError(
            config.dioForbiddenMessage,
            serverResponse: serverResponse,
            diagnosticInfo: config.disposeCachedKeypairOnError
                ? 'DioException: ${e.message}'
                : null,
          );
        } else if (config.handleSslErrors &&
            e.error != null &&
            _isSslError(e.error.toString())) {
          _disposeCachedKeypairIf(true);
          throw SSLError(
            'SSL/TLS handshake failed.',
            certificateInfo: e.message,
          );
        } else {
          logger.warning(
            '${config.label} polling error: $e',
          );
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } catch (e) {
        if (config.handleSslErrors && _isSslError(e.toString())) {
          throw SSLError(
            'SSL/TLS error during ${config.label.toLowerCase()}.',
            certificateInfo: e.toString(),
          );
        }
        logger.warning('${config.label} polling error: $e');
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    _disposeCachedKeypairIf(config.disposeCachedKeypairOnError);
    throw ExpiredError(config.timeoutMessage);
  }

  /// Check if an error string indicates an SSL/TLS failure.
  static bool _isSslError(String error) {
    return error.contains('Tls') ||
        error.contains('Handshake') ||
        error.contains('Certificate') ||
        error.contains('SSL');
  }

  /// Parse a happy:// URL and extract the public key
  /// Supports formats:
  /// - `happy://terminal?<base64_public_key>`
  /// - `happy:///account?<base64_public_key>`
  static Uint8List? parseAuthUrl(String url) {
    try {
      if (!url.startsWith('happy://')) {
        return null;
      }

      const terminalPrefix = 'happy://terminal?';
      const accountPrefix = 'happy:///account?';

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
      logger.warning('Failed to parse auth URL: $e');
      return null;
    }
  }

  /// Approve a device linking request from a happy:// URL
  Future<bool> approveLinkingRequest(String url) async {
    final publicKey = parseAuthUrl(url);
    if (publicKey == null) {
      throw AuthException('Invalid auth URL format');
    }

    final isTerminalLink = url.startsWith('happy://terminal?');
    return approveLinkingWithPublicKey(
      publicKey,
      isTerminalLink: isTerminalLink,
    );
  }

  /// Approve a device linking request with a public key.
  ///
  /// [isTerminalLink] distinguishes terminal links (`happy://terminal?...`)
  /// from account links (`happy:///account?...`). Terminal links POST to
  /// `/v1/auth/response` and may send a V2 bundle; account links POST to
  /// `/v1/auth/account/response` and always send only the encrypted secret.
  Future<bool> approveLinkingWithPublicKey(
    Uint8List requesterPublicKey, {
    bool isTerminalLink = false,
  }) async {
    final credentials = await TokenStorage().getCredentials();
    if (credentials == null) {
      throw AuthException('Not authenticated');
    }

    final secret = base64Decode(credentials.secret);

    if (isTerminalLink) {
      // Terminal link: check V2 support, then POST to /v1/auth/response
      final publicKeyB64 = base64Encode(requesterPublicKey);

      // Check whether the requester supports the V2 bundle format.
      var supportsV2 = false;
      try {
        final statusResponse = await _apiClient.get(
          '/v1/auth/request/status',
          queryParameters: {'publicKey': publicKeyB64},
        );
        if (statusResponse.statusCode == 200 &&
            statusResponse.data is Map<String, dynamic>) {
          final statusData =
              statusResponse.data as Map<String, dynamic>;
          supportsV2 = statusData['supportsV2'] == true;

          // If already authorized, nothing more to do.
          // If not_found, the request doesn't exist — fall through and
          // attempt the approval POST anyway (the server will return an
          // error if the request truly doesn't exist).
          final status = statusData['status'] as String?;
          if (status == 'authorized') {
            return true;
          }
        }
      } catch (e) {
        logger.warning('Failed to check auth request status: $e');
        // Fall through and attempt V1 approval.
      }

      final Uint8List responsePayload;
      if (supportsV2 && sync.isInitialized) {
        // V2: encrypt [0x00, ...contentDataKey]
        final contentDataKey = sync.encryption.contentDataKey;
        final v2Bundle = Uint8List(1 + contentDataKey.length);
        v2Bundle[0] = 0x00;
        v2Bundle.setAll(1, contentDataKey);
        responsePayload = await CryptoBox.encrypt(v2Bundle, requesterPublicKey);
      } else {
        // V1: encrypt the raw secret
        responsePayload = await CryptoBox.encrypt(secret, requesterPublicKey);
      }

      final response = await _apiClient.post(
        '/v1/auth/response',
        data: {
          'publicKey': publicKeyB64,
          'response': base64Encode(responsePayload),
        },
      );
      return response.statusCode == 200;
    } else {
      // Account link: always POST to /v1/auth/account/response with secret
      final encryptedResponse = await CryptoBox.encrypt(
        secret,
        requesterPublicKey,
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
}

class DeviceLinkingResult {

  DeviceLinkingResult({
    required this.linkingId,
    required this.publicKey,
    required this.secret,
  });
  final String linkingId;
  final Uint8List publicKey;
  final Uint8List secret;

  /// Get the QR code data for this linking
  /// Format: `happy:///account?<base64url_public_key>`
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

  _KeyPair({required this.privateKey, required this.publicKey});
  final Uint8List privateKey;
  final Uint8List publicKey;
}
