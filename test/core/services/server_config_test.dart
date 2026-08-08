import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/server_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('validateServerUrl', () {
    test('validates HTTPS URL', () {
      final result = validateServerUrl('https://api.example.com');

      expect(result.valid, isTrue);
      expect(result.error, isNull);
    });

    test('validates HTTP URL', () {
      final result = validateServerUrl('http://localhost:3000');

      expect(result.valid, isTrue);
      expect(result.error, isNull);
    });

    test('validates URL with port', () {
      final result = validateServerUrl('https://api.example.com:8443');

      expect(result.valid, isTrue);
    });

    test('validates URL with path', () {
      final result = validateServerUrl('https://api.example.com/v1');

      expect(result.valid, isTrue);
    });

    test('rejects empty string', () {
      final result = validateServerUrl('');

      expect(result.valid, isFalse);
      expect(result.error, contains('cannot be empty'));
    });

    test('rejects whitespace-only string', () {
      final result = validateServerUrl('   ');

      expect(result.valid, isFalse);
      expect(result.error, isNotNull);
    });

    test('rejects FTP protocol', () {
      final result = validateServerUrl('ftp://files.example.com');

      expect(result.valid, isFalse);
      expect(result.error, contains('HTTP or HTTPS'));
    });

    test('rejects WebSocket protocol', () {
      final result = validateServerUrl('ws://socket.example.com');

      expect(result.valid, isFalse);
      expect(result.error, contains('HTTP or HTTPS'));
    });

    test('rejects URL without host', () {
      final result = validateServerUrl('https://');

      expect(result.valid, isFalse);
      expect(result.error, contains('hostname'));
    });

    test('rejects invalid URL format', () {
      final result = validateServerUrl('not a url at all ://');

      expect(result.valid, isFalse);
      expect(result.error, isNotNull);
    });

    test('validates URL with subdomain', () {
      final result = validateServerUrl('https://api.staging.example.com');

      expect(result.valid, isTrue);
    });

    test('validates URL with IP address', () {
      final result = validateServerUrl('http://192.168.1.100:8080');

      expect(result.valid, isTrue);
    });
  });

  group('ServerUrlValidation', () {
    test('valid result has no error', () {
      const validation = ServerUrlValidation(valid: true);

      expect(validation.valid, isTrue);
      expect(validation.error, isNull);
    });

    test('invalid result has error message', () {
      const validation = ServerUrlValidation(valid: false, error: 'Bad URL');

      expect(validation.valid, isFalse);
      expect(validation.error, equals('Bad URL'));
    });
  });

  group('ServerUrlVerificationResult', () {
    test('success factory creates valid result', () {
      const result = ServerUrlVerificationResult.success();

      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.errorType, isNull);
      expect(result.serviceStatus, 'ok');
      expect(result.degraded, isEmpty);
    });

    test('success preserves a degraded readiness report', () {
      const result = ServerUrlVerificationResult.success(
        status: 'degraded',
        degraded: <String>['redis'],
      );

      expect(result.isValid, isTrue);
      expect(result.serviceStatus, 'degraded');
      expect(result.degraded, <String>['redis']);
    });

    test('failed factory creates invalid result', () {
      final result = ServerUrlVerificationResult.failed(
        'Connection refused',
        'Network',
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, equals('Connection refused'));
      expect(result.errorType, equals('Network'));
    });

    test('failed factory defaults errorType to Unknown', () {
      final result = ServerUrlVerificationResult.failed('Some error');

      expect(result.errorType, equals('Unknown'));
    });
  });

  group('defaultServerUrl', () {
    test('has expected default value', () {
      expect(defaultServerUrl, equals('https://api.cluster-fluster.com'));
    });
  });
}
