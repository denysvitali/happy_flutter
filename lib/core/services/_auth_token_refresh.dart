part of 'auth_service.dart';

const _renewalWindow = Duration(days: 7);
const _renewalRetry = Duration(hours: 1);

bool _isRenewalUnavailableStatus(int? status) =>
    status == 404 ||
    status == 408 ||
    status == 429 ||
    (status != null && status >= 500 && status <= 599);

/// Bearer renewal never submits account secrets or creates an account.
extension AuthTokenRefresh on AuthService {
  /// Install a bearer without redialling a socket while the OS has us paused.
  void updateSocketToken(String token) {
    if (_credentials is _TokenCredentialStore && sync.isLifecycleSuspended) {
      socket_io.socketIoClient.disconnect(
        preserveConnectionHistory: true,
        reason: socket_io.DisconnectReason.lifecycleSuspend,
      );
    }
    _updateSocketToken(token);
  }

  /// Renew only an unexpired bearer and retain the exact account identity.
  Future<String> refreshToken() {
    final pending = _refreshFlight;
    if (pending != null) return pending;
    final flight = _renewToken();
    _refreshFlight = flight;
    unawaited(
      flight.then<void>(
        (_) {
          if (identical(_refreshFlight, flight)) _refreshFlight = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_refreshFlight, flight)) _refreshFlight = null;
        },
      ),
    );
    return flight;
  }

  /// Renew within the final week. Unsupported servers and temporary failures
  /// keep the existing bearer usable only until its original expiry.
  Future<AuthCredentials?> refreshCredentialsIfNeeded() async {
    final generation = _credentialGeneration;
    final credentials = await _credentials.getCredentials();
    _requireRenewalGeneration(generation);
    if (credentials == null) return null;
    final claims = _RenewalClaims.parse(credentials.token);
    if (claims == null && credentials.token.split('.').length == 3) {
      throw AuthException('Cannot validate stored token for renewal');
    }
    if (claims?.expiresAt == null) return credentials;
    _requireUnexpired(claims!);
    if (claims.expiresAt!.difference(_now()) > _renewalWindow) {
      return credentials;
    }
    try {
      await refreshToken();
    } on _RenewalUnavailable {
      _requireRenewalGeneration(generation);
      _requireUnexpired(claims);
    } on DioException {
      _requireRenewalGeneration(generation);
      _requireUnexpired(claims);
      logger.warning('AuthService: token renewal unavailable; retrying later');
    }
    _requireRenewalGeneration(generation);
    return _credentials.getCredentials();
  }

  /// Delay until renewal, bounded by expiry after an unsuccessful attempt.
  Duration? nextTokenRefreshDelay(AuthCredentials credentials) {
    final expiry = _RenewalClaims.parse(credentials.token)?.expiresAt;
    if (expiry == null) return null;
    final remaining = expiry.difference(_now());
    if (remaining <= Duration.zero) return Duration.zero;
    final untilRenewal = remaining - _renewalWindow;
    if (untilRenewal > Duration.zero) return untilRenewal;
    return remaining < _renewalRetry ? remaining : _renewalRetry;
  }

  Future<String> _renewToken() async {
    final generation = _credentialGeneration;
    final credentials = await _credentials.getCredentials();
    _requireRenewalGeneration(generation);
    if (credentials == null) throw AuthException('No credentials to renew');
    final claims = _RenewalClaims.parse(credentials.token);
    if (claims == null || claims.account == null) {
      throw AuthException('Cannot establish token account identity');
    }
    _requireUnexpired(claims);
    Response<dynamic> response;
    try {
      response = await _apiClient.post(
        '/v1/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer ${credentials.token}'},
        ),
      );
    } on DioException catch (error) {
      _requireRenewalGeneration(generation);
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) _rejectRenewal();
      if (_isRenewalUnavailableStatus(status)) {
        throw const _RenewalUnavailable();
      }
      if (status != null) {
        throw AuthException('Token renewal request rejected ($status)');
      }
      rethrow;
    }
    _requireRenewalGeneration(generation);
    if (response.statusCode == 401 || response.statusCode == 403) {
      _rejectRenewal();
    }
    if (_isRenewalUnavailableStatus(response.statusCode)) {
      throw const _RenewalUnavailable();
    }
    final data = response.data;
    final token = data is Map<String, dynamic> ? data['token'] : null;
    final renewed = token is String ? _RenewalClaims.parse(token) : null;
    if (response.statusCode != 200 ||
        renewed == null ||
        renewed.account != claims.account ||
        renewed.issuer != claims.issuer ||
        renewed.expiresAt == null ||
        !renewed.expiresAt!.isAfter(_now()) ||
        (claims.expiresAt != null &&
            !renewed.expiresAt!.isAfter(claims.expiresAt!))) {
      throw AuthException(
        'Invalid token renewal response; credentials retained',
      );
    }
    final replacement = AuthCredentials(
      token: token as String,
      secret: credentials.secret,
    );
    return _mutateCredentials(() async {
      _requireRenewalGeneration(generation);
      final current = await _credentials.getCredentials();
      _requireRenewalGeneration(generation);
      if (current != credentials) {
        throw AuthException('Credentials changed during token renewal');
      }
      _requireUnexpired(renewed);
      if (!await _credentials.setCredentials(replacement)) {
        throw AuthException('Unable to store renewed credentials');
      }
      _requireRenewalGeneration(generation);
      _requireUnexpired(renewed);
      _apiClient.updateToken(replacement.token);
      updateSocketToken(replacement.token);
      // A bearer rotation for the same account must preserve the runtime,
      // encryption keys, pending settings, and unsent outbox entries.
      if (_credentials is _TokenCredentialStore &&
          sync.isInitialized &&
          sync.credentials == credentials) {
        sync.credentials = replacement;
      }
      _lastAuthFailure = null;
      return replacement.token;
    });
  }

  void _requireRenewalGeneration(int generation) {
    if (generation != _credentialGeneration || cleanupPending) {
      throw AuthException('Account changed during token renewal');
    }
  }

  void _requireUnexpired(_RenewalClaims claims) {
    if (claims.expiresAt != null && !claims.expiresAt!.isAfter(_now())) {
      _rejectRenewal();
    }
  }

  Never _rejectRenewal() {
    _lastAuthFailure = AuthFailureKind.rejected;
    throw AuthForbiddenError('Please sign in again; account keys are retained');
  }
}

class _RenewalUnavailable extends AuthException {
  const _RenewalUnavailable() : super('Token renewal temporarily unavailable');
}

class _RenewalClaims {
  const _RenewalClaims(this.account, this.issuer, this.expiresAt);
  final String? account;
  final String? issuer;
  final DateTime? expiresAt;

  static _RenewalClaims? parse(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final data = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (data is! Map<String, dynamic>) return null;
      final user = data['user'];
      final subject = data['sub'];
      if (user != null && subject != null && user != subject) return null;
      final account = user ?? subject;
      final issuer = data['iss'];
      final expiry = data['exp'];
      if (account is! String ||
          account.isEmpty ||
          issuer is! String ||
          issuer.isEmpty ||
          (expiry != null && expiry is! int)) {
        return null;
      }
      return _RenewalClaims(
        account,
        issuer,
        expiry is int
            ? DateTime.fromMillisecondsSinceEpoch(expiry * 1000, isUtc: true)
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}

void _noopUpdateSocketToken(String _) {}
