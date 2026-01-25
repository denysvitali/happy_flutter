/// Authentication credentials stored securely
class AuthCredentials {
  final String token;
  final String secret;

  const AuthCredentials({required this.token, required this.secret});

  factory AuthCredentials.fromJson(Map<String, dynamic> json) {
    return AuthCredentials(
      token: json['token'] as String,
      secret: json['secret'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'token': token, 'secret': secret};
  }
}

/// Authentication state
enum AuthState {
  unauthenticated,
  authenticating,
  authenticated,
  error,
}

/// Base class for authentication exceptions
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

/// Authentication error types
sealed class AuthError {
  final String? message;
  AuthError(this.message);

  String get messageText => message ?? 'Unknown error';
}

class NetworkError extends AuthError {
  NetworkError([super.message]);
}

class InvalidQRError extends AuthError {
  InvalidQRError([super.message]);
}

class ExpiredError extends AuthError {
  ExpiredError([super.message]);
}

class UnknownError extends AuthError {
  UnknownError([super.message]);
}

/// Forbidden error (403) with diagnostic information
class AuthForbiddenError extends AuthException {
  final String? serverResponse;
  final String? diagnosticInfo;

  const AuthForbiddenError(
    super.message, {
    this.serverResponse,
    this.diagnosticInfo,
  });

  @override
  String toString() {
    final sb = StringBuffer('AuthForbiddenError: $message');
    if (serverResponse != null) {
      sb.write(' | Server: $serverResponse');
    }
    if (diagnosticInfo != null) {
      sb.write(' | Info: $diagnosticInfo');
    }
    return sb.toString();
  }
}

/// Request error (4xx) with status code
class AuthRequestError extends AuthException {
  final int? statusCode;
  final String? serverResponse;

  const AuthRequestError(
    super.message, {
    this.statusCode,
    this.serverResponse,
  });

  @override
  String toString() {
    final sb = StringBuffer();
    if (statusCode != null) {
      sb.write('AuthRequestError($statusCode): $message');
    } else {
      sb.write('AuthRequestError: $message');
    }
    if (serverResponse != null) {
      sb.write(' | Server: $serverResponse');
    }
    return sb.toString();
  }
}

/// Server error (5xx)
class ServerError extends AuthException {
  final int? statusCode;

  const ServerError(super.message, {this.statusCode});

  @override
  String toString() {
    if (statusCode != null) {
      return 'ServerError($statusCode): $message';
    }
    return 'ServerError: $message';
  }
}

/// SSL/TLS certificate error
class SSLError extends AuthException {
  final String? certificateInfo;

  const SSLError(super.message, {this.certificateInfo});

  @override
  String toString() {
    if (certificateInfo != null) {
      return 'SSLError: $message | Cert: $certificateInfo';
    }
    return 'SSLError: $message';
  }
}
