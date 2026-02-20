import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/auth.dart';

void main() {
  group('AuthException and Subclasses', () {
    test('AuthException has correct message', () {
      const exception = AuthException('Test error message');

      expect(exception.message, 'Test error message');
      expect(exception.toString(), contains('Test error message'));
    });

    test('AuthForbiddenError includes server response', () {
      final error = AuthForbiddenError(
        'Access denied',
        serverResponse: 'Invalid token',
      );

      expect(error.message, 'Access denied');
      expect(error.serverResponse, 'Invalid token');
      expect(error.toString(), contains('Access denied'));
      expect(error.toString(), contains('Invalid token'));
    });

    test('AuthRequestError includes status code', () {
      final error = AuthRequestError(
        'Bad request',
        statusCode: 400,
        serverResponse: 'Missing field',
      );

      expect(error.message, 'Bad request');
      expect(error.statusCode, 400);
      expect(error.serverResponse, 'Missing field');
      expect(error.toString(), contains('400'));
      expect(error.toString(), contains('Bad request'));
    });

    test('ServerError includes status code', () {
      final error = ServerError('Internal error', statusCode: 500);

      expect(error.message, 'Internal error');
      expect(error.statusCode, 500);
      expect(error.toString(), contains('500'));
      expect(error.toString(), contains('Internal error'));
    });

    test('SSLError includes message', () {
      final error = SSLError(
        'Certificate validation failed',
      );

      expect(error.message, 'Certificate validation failed');
      expect(error.toString(), contains('Certificate validation failed'));
    });
  });

  group('AuthState Enum', () {
    test('AuthState has correct values', () {
      expect(AuthState.unauthenticated, isNotNull);
      expect(AuthState.authenticating, isNotNull);
      expect(AuthState.authenticated, isNotNull);
      expect(AuthState.error, isNotNull);
    });

    test('AuthState values are distinct', () {
      expect(AuthState.unauthenticated == AuthState.authenticating, isFalse);
      expect(AuthState.authenticating == AuthState.authenticated, isFalse);
      expect(AuthState.authenticated == AuthState.error, isFalse);
    });
  });

  group('AuthError Subclasses', () {
    test('NetworkError can be created', () {
      final error = NetworkError('Connection failed');
      expect(error.message, 'Connection failed');
      expect(error.messageText, 'Connection failed');
    });

    test('NetworkError without message', () {
      final error = NetworkError();
      expect(error.message, isNull);
      expect(error.messageText, 'Unknown error');
    });

    test('InvalidQRError can be created', () {
      final error = InvalidQRError('Invalid QR format');
      expect(error.message, 'Invalid QR format');
    });

    test('ExpiredError can be created', () {
      final error = ExpiredError('Session expired');
      expect(error.message, 'Session expired');
    });

    test('UnknownError can be created', () {
      final error = UnknownError('Unexpected error');
      expect(error.message, 'Unexpected error');
    });
  });

  group('Error Type Hierarchy', () {
    test('AuthForbiddenError extends AuthException', () {
      final error = AuthForbiddenError('Test');
      expect(error, isA<AuthForbiddenError>());
      expect(error, isA<Exception>());
    });

    test('AuthRequestError extends AuthException', () {
      final error = AuthRequestError('Test');
      expect(error, isA<AuthRequestError>());
      expect(error, isA<Exception>());
    });

    test('ServerError extends AuthException', () {
      final error = ServerError('Test');
      expect(error, isA<ServerError>());
      expect(error, isA<Exception>());
    });

    test('SSLError extends AuthException', () {
      final error = SSLError('Test');
      expect(error, isA<SSLError>());
      expect(error, isA<Exception>());
    });

    test('NetworkError extends AuthError', () {
      final error = NetworkError('Test');
      expect(error, isA<AuthError>());
    });

    test('ExpiredError extends AuthError', () {
      final error = ExpiredError('Test');
      expect(error, isA<AuthError>());
    });
  });

  group('AuthCredentials', () {
    test('fromJson parses token and secret correctly', () {
      final json = {
        'token': 'test-token-123',
        'secret': 'test-secret-456',
      };
      final credentials = AuthCredentials.fromJson(json);

      expect(credentials.token, 'test-token-123');
      expect(credentials.secret, 'test-secret-456');
    });

    test('toJson serializes token and secret correctly', () {
      const credentials = AuthCredentials(
        token: 'my-token',
        secret: 'my-secret',
      );
      final json = credentials.toJson();

      expect(json['token'], 'my-token');
      expect(json['secret'], 'my-secret');
    });

    test('round-trip fromJson/toJson preserves all fields', () {
      const original = AuthCredentials(
        token: 'round-trip-token',
        secret: 'round-trip-secret',
      );
      final json = original.toJson();
      final restored = AuthCredentials.fromJson(json);

      expect(restored.token, original.token);
      expect(restored.secret, original.secret);
    });

    test('AuthCredentials with empty strings', () {
      const credentials = AuthCredentials(token: '', secret: '');
      expect(credentials.token, '');
      expect(credentials.secret, '');
    });

    test('AuthCredentials with long token values', () {
      final longToken = 'x' * 1000;
      final longSecret = 'y' * 512;
      final credentials = AuthCredentials(
        token: longToken,
        secret: longSecret,
      );

      expect(credentials.token.length, 1000);
      expect(credentials.secret.length, 512);

      final json = credentials.toJson();
      final restored = AuthCredentials.fromJson(json);
      expect(restored.token, longToken);
      expect(restored.secret, longSecret);
    });
  });

  group('AuthForbiddenError diagnosticInfo', () {
    test('includes diagnosticInfo in toString', () {
      final error = AuthForbiddenError(
        'Forbidden',
        diagnosticInfo: 'Certificate mismatch',
        serverResponse: 'Unauthorized',
      );

      expect(error.toString(), contains('Forbidden'));
      expect(error.toString(), contains('Certificate mismatch'));
      expect(error.toString(), contains('Unauthorized'));
    });

    test('works without optional fields', () {
      final error = AuthForbiddenError('Forbidden');
      expect(error.serverResponse, isNull);
      expect(error.diagnosticInfo, isNull);
      expect(error.toString(), contains('Forbidden'));
    });
  });

  group('ServerError optional status code', () {
    test('ServerError without status code', () {
      final error = ServerError('Server error');
      expect(error.statusCode, isNull);
      final str = error.toString();
      expect(str, contains('Server error'));
      expect(str, isNot(contains('status:')));
    });

    test('ServerError with status code', () {
      final error = ServerError('Internal error', statusCode: 503);
      expect(error.statusCode, 503);
      expect(error.toString(), contains('503'));
    });
  });

  group('SSLError optional certificateInfo', () {
    test('SSLError with certificate info', () {
      final error = SSLError(
        'SSL handshake failed',
        certificateInfo: 'Fingerprint: AA:BB:CC',
      );

      expect(error.certificateInfo, 'Fingerprint: AA:BB:CC');
      expect(error.toString(), contains('AA:BB:CC'));
    });

    test('SSLError without certificate info', () {
      final error = SSLError('SSL error');
      expect(error.certificateInfo, isNull);
    });
  });
}
