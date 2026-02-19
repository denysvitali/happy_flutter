/// Authentication credentials stored securely
class AuthCredentials {
  const AuthCredentials({required this.token, required this.secret});

  factory AuthCredentials.fromJson(Map<String, dynamic> json) {
    return AuthCredentials(
      token: json['token'] as String,
      secret: json['secret'] as String,
    );
  }

  final String token;
  final String secret;

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
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Authentication error types
sealed class AuthError implements Exception {
  AuthError(this.message);

  final String? message;

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
  const ServerError(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() {
    final status =
        statusCode != null ? ' (status: $statusCode)' : '';
    return 'ServerError: $message$status';
  }
}

/// Auth forbidden error (403)
class AuthForbiddenError implements Exception {
  const AuthForbiddenError(
    this.message, {
    this.serverResponse,
    this.diagnosticInfo,
  });

  final String message;
  final String? serverResponse;
  final String? diagnosticInfo;

  @override
  String toString() {
    var result = 'AuthForbiddenError: $message';
    if (diagnosticInfo != null) {
      result += '\n\nDiagnostic: $diagnosticInfo';
    }
    if (serverResponse != null) {
      result += '\nServer response: $serverResponse';
    }
    return result;
  }
}

/// Auth request error (4xx)
class AuthRequestError implements Exception {
  const AuthRequestError(
    this.message, {
    this.statusCode,
    this.serverResponse,
  });

  final String message;
  final int? statusCode;
  final String? serverResponse;

  @override
  String toString() {
    final status =
        statusCode != null ? ' (status: $statusCode)' : '';
    return 'AuthRequestError: $message$status';
  }
}

/// SSL/TLS error
class SSLError implements Exception {
  const SSLError(
    this.message, {
    this.certificateInfo,
  });

  final String message;
  final String? certificateInfo;

  @override
  String toString() {
    var result = 'SSLError: $message';
    if (certificateInfo != null) {
      result += '\nCertificate info: $certificateInfo';
    }
    return result;
  }
}
