import 'dart:convert';
import 'dart:typed_data';
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
        expect(error, isA<AuthException>());
      });

      test('AuthRequestError extends AuthException', () {
        final error = AuthRequestError('Test');
        expect(error, isA<AuthException>());
      });

      test('ServerError extends AuthException', () {
        final error = ServerError('Test');
        expect(error, isA<AuthException>());
      });

      test('SSLError extends AuthException', () {
        final error = SSLError('Test');
        expect(error, isA<AuthException>());
      });
    });
  });
}
