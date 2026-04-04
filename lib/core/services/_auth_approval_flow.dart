part of 'auth_service.dart';

/// Internal Ed25519 key pair used during account creation and restore.
class _KeyPair {
  _KeyPair({required this.privateKey, required this.publicKey});

  final Uint8List privateKey;
  final Uint8List publicKey;
}

/// Per-flow configuration for [AuthService._waitForApproval].
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

extension _ApprovalFlowMethods on AuthService {
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

              final credentials = AuthCredentials(
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
            AuthService._isSslError(e.error.toString())) {
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
        if (config.handleSslErrors && AuthService._isSslError(e.toString())) {
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
}
