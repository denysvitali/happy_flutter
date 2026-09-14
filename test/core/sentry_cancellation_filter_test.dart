import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/sentry_config.dart';
import 'package:http/http.dart' as http;

void main() {
  final options = RequestOptions(path: '/v3/sessions/s1/messages');

  group('isExpectedHttpCancellation', () {
    // GlitchTip 8776 (build 279900): our own 20s request budget cancelled the
    // token, the cancellation escaped an async gap to
    // PlatformDispatcher.onError, and the SDK filed it as an unhandled fatal.
    test('treats a deadline cancellation as expected', () {
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: 'HTTP request deadline exceeded',
      );
      expect(isExpectedHttpCancellation(error), isTrue);
    });

    test('treats an app-suspension cancellation as expected', () {
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: 'appSuspended',
      );
      expect(isExpectedHttpCancellation(error), isTrue);
    });

    // The native adapters surface the abort our cancellation caused as a
    // package:http ClientException rather than a DioException.
    test('treats the adapter abort echo as expected', () {
      final error = http.ClientException(
        'Request aborted by `abortTrigger`',
        Uri.parse('https://example.test/v3/sessions/s1/messages'),
      );
      expect(isExpectedHttpCancellation(error), isTrue);
    });

    test('does not treat a receive timeout as expected', () {
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
      expect(isExpectedHttpCancellation(error), isFalse);
    });

    test('does not treat a connection error as expected', () {
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'ERR_NAME_NOT_RESOLVED',
      );
      expect(isExpectedHttpCancellation(error), isFalse);
    });

    test('does not treat an unrelated ClientException as expected', () {
      final error = http.ClientException('Connection closed before full header');
      expect(isExpectedHttpCancellation(error), isFalse);
    });

    test('does not treat unrelated throwables as expected', () {
      expect(isExpectedHttpCancellation(StateError('boom')), isFalse);
      expect(isExpectedHttpCancellation(null), isFalse);
      expect(isExpectedHttpCancellation('HTTP request deadline exceeded'), isFalse);
    });
  });
}
