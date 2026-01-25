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
