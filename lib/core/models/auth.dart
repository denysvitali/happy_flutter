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

/// Server error (5xx)
class ServerError implements Exception {
  final String message;
  final int? statusCode;

  const ServerError(
    this.message, {
    this.statusCode,
  });

  @override
  String toString() => 'ServerError: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// Auth forbidden error (403)
class AuthForbiddenError implements Exception {
  final String message;
  final String? serverResponse;

  const AuthForbiddenError(
    this.message, {
    this.serverResponse,
  });

  @override
  String toString() => 'AuthForbiddenError: $message';
}

/// Auth request error (4xx)
class AuthRequestError implements Exception {
  final String message;
  final int? statusCode;
  final String? serverResponse;

  const AuthRequestError(
    this.message, {
    this.statusCode,
    this.serverResponse,
  });

  @override
  String toString() => 'AuthRequestError: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// SSL/TLS error
class SSLError implements Exception {
  final String message;

  const SSLError(this.message);

  @override
  String toString() => 'SSLError: $message';
}
