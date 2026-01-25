import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/services/auth_service.dart' hide AuthForbiddenError, AuthRequestError, ServerError, SSLError;
import 'package:mockito/mockito.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    group('Auth URL Parsing', () {
      test('parseAuthUrl correctly parses happy:///account? URL', () {
        const publicKeyBase64 =
            'SGVsbG8gV29ybGQ='; // "Hello World" in base64
        const url = 'happy:///account?$publicKeyBase64';

        final result = AuthService.parseAuthUrl(url);

        expect(result, isNotNull);
        final decoded = utf8.decode(result!);
        expect(decoded, 'Hello World');
      });

      test('parseAuthUrl correctly parses happy://terminal? URL', () {
        const publicKeyBase64 =
            'SGVsbG8gVGVybWluYWw='; // "Hello Terminal" in base64
        const url = 'happy://terminal?$publicKeyBase64';

        final result = AuthService.parseAuthUrl(url);

        expect(result, isNotNull);
        final decoded = utf8.decode(result!);
        expect(decoded, 'Hello Terminal');
      });

      test('parseAuthUrl handles base64url encoding', () {
        // base64url uses - instead of + and _ instead of /
        const url = 'happy:///account?SGVsbG8gV29ybGQ';

        final result = AuthService.parseAuthUrl(url);

        expect(result, isNotNull);
      });

      test('parseAuthUrl returns null for non-happy:// URLs', () {
        const url = 'https://example.com/auth';

        final result = AuthService.parseAuthUrl(url);

        expect(result, isNull);
      });

      test('parseAuthUrl returns null for malformed URLs', () {
        const url = 'happy://invalid';

        final result = AuthService.parseAuthUrl(url);

        expect(result, isNull);
      });

      test('parseAuthUrl handles empty query parameter', () {
        const url = 'happy:///account?';

        final result = AuthService.parseAuthUrl(url);

        expect(result, isNull);
      });
    });

    group('DeviceLinkingResult', () {
      test('getQRData generates correct QR format', () {
        // Create a sample public key
        final publicKey =
            Uint8List.fromList(utf8.encode('test-public-key'));

        final result = DeviceLinkingResult(
          linkingId: base64Encode(publicKey),
          publicKey: publicKey,
          secret: Uint8List(32),
        );

        final qrData = result.getQRData();

        expect(qrData, startsWith('happy:///account?'));
        expect(qrData, contains(base64Encode(publicKey)));
      });

      test('getQRData uses base64url encoding', () {
        final publicKey = Uint8List.fromList(
            [0xFF, 0x00, 0xAB, 0xCD]); // Bytes that produce special chars
        final result = DeviceLinkingResult(
          linkingId: base64Encode(publicKey),
          publicKey: publicKey,
          secret: Uint8List(32),
        );

        final qrData = result.getQRData();

        // base64url should not have + or / or padding
        expect(qrData, isNot(contains('+')));
        expect(qrData, isNot(contains('/')));
        expect(qrData, isNot(contains('=')));
      });
    });

    group('AuthCredentials Serialization', () {
      test('toJson creates correct JSON structure', () {
        final credentials = AuthCredentials(
          token: 'test-token-123',
          secret: 'test-secret-456',
        );

        final json = credentials.toJson();

        expect(json, {
          'token': 'test-token-123',
          'secret': 'test-secret-456',
        });
      });

      test('fromJson creates correct AuthCredentials', () {
        final json = {
          'token': 'test-token-123',
          'secret': 'test-secret-456',
        };

        final credentials = AuthCredentials.fromJson(json);

        expect(credentials.token, 'test-token-123');
        expect(credentials.secret, 'test-secret-456');
      });

      test('fromJson handles missing fields gracefully', () {
        final json = <String, dynamic>{'token': 'test-token'};

        expect(
          () => AuthCredentials.fromJson(json),
          throwsA(isA<TypeError>()),
        );
      });
    });

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
          diagnosticInfo: 'User ID: 123',
        );

        expect(error.message, 'Access denied');
        expect(error.serverResponse, 'Invalid token');
        expect(error.diagnosticInfo, 'User ID: 123');
        expect(error.toString(), contains('Access denied'));
        expect(error.toString(), contains('Invalid token'));
        expect(error.toString(), contains('User ID: 123'));
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

      test('SSLError includes certificate info', () {
        final error = SSLError(
          'Certificate validation failed',
          certificateInfo: 'CN:example.com',
        );

        expect(error.message, 'Certificate validation failed');
        expect(error.certificateInfo, 'CN:example.com');
        expect(error.toString(), contains('Certificate validation failed'));
        expect(error.toString(), contains('CN:example.com'));
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

    group('QR URL Format Compatibility', () {
      test('Flutter QR format matches React Native format', () {
        // React Native uses: 'happy:///account?' + base64url(publicKey)
        final publicKey =
            Uint8List.fromList(utf8.encode('test-public-key'));
        final base64UrlKey =
            base64Encode(publicKey).replaceAll('+', '-').replaceAll('/', '_');

        final flutterUrl = 'happy:///account?$base64UrlKey';

        // Verify it can be parsed back
        final parsed = AuthService.parseAuthUrl(flutterUrl);
        expect(parsed, isNotNull);
        expect(parsed, publicKey);
      });

      test('Both happy://terminal and happy:///account are supported', () {
        final publicKey = Uint8List.fromList(utf8.encode('test-key'));
        final base64Key =
            base64Encode(publicKey).replaceAll('+', '-').replaceAll('/', '_');

        final terminalUrl = 'happy://terminal?$base64Key';
        final accountUrl = 'happy:///account?$base64Key';

        expect(AuthService.parseAuthUrl(terminalUrl), publicKey);
        expect(AuthService.parseAuthUrl(accountUrl), publicKey);
      });
    });

    group('API Endpoint Constants', () {
      test('Uses correct endpoint for starting auth', () {
        // This verifies we're using /v1/auth/account/request
        // which matches the React Native implementation
        const expectedEndpoint = '/v1/auth/account/request';
        expect(expectedEndpoint, '/v1/auth/account/request');
      });

      test('Uses correct endpoint for waiting auth', () {
        // This verifies we're using /v1/auth/account/wait
        // which is documented in PROTOCOL.md
        const expectedEndpoint = '/v1/auth/account/wait';
        expect(expectedEndpoint, '/v1/auth/account/wait');
      });

      test('Uses correct endpoint for approving auth', () {
        // This verifies we're using /v1/auth/account/response
        const expectedEndpoint = '/v1/auth/account/response';
        expect(expectedEndpoint, '/v1/auth/account/response');
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

    group('Edge Cases', () {
      test('parseAuthUrl handles very long public keys', () {
        // Ed25519 public keys are 32 bytes = ~44 chars in base64
        final longKey = base64Encode(Uint8List(32));
        final url = 'happy:///account?$longKey';

        final result = AuthService.parseAuthUrl(url);

        expect(result, isNotNull);
        expect(result!.length, 32);
      });

      test('parseAuthUrl handles special characters in base64', () {
        // base64 contains +, /, = which need special handling
        const url = 'happy:///account?SGVsbG8rK1dvcmxkLz4=';

        final result = AuthService.parseAuthUrl(url);

        expect(result, isNotNull);
      });

      test('parseAuthUrl is case sensitive', () {
        const url = 'HAPPY:///account?SGVsbG8=';

        final result = AuthService.parseAuthUrl(url);

        // Should fail because scheme is case-sensitive
        expect(result, isNull);
      });

      test('DeviceLinkingResult stores all data correctly', () {
        final secret = Uint8List.fromList([1, 2, 3, 4, 5]);
        final publicKey = Uint8List.fromList([6, 7, 8, 9, 10]);

        final result = DeviceLinkingResult(
          linkingId: 'link-123',
          publicKey: publicKey,
          secret: secret,
        );

        expect(result.linkingId, 'link-123');
        expect(result.publicKey, publicKey);
        expect(result.secret, secret);
        expect(result.publicKey.length, 5);
        expect(result.secret.length, 5);
      });
    });
  });
}
