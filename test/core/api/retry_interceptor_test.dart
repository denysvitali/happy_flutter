import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/retry_interceptor.dart';
import 'package:happy_flutter/core/services/token_refresh_manager.dart';

/// Adapter that replays a scripted list of status codes, repeating the last
/// entry once the script runs out, and counts how many attempts it served.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.statusCodes);

  final List<int> statusCodes;
  final List<String> paths = [];

  int get calls => paths.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = paths.length;
    paths.add(options.path);
    final status = index < statusCodes.length
        ? statusCodes[index]
        : statusCodes.last;
    return ResponseBody.fromString(
      jsonEncode({'attempt': index + 1}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _buildDio(
  _ScriptedAdapter adapter, {
  int maxRetries = 3,
  int baseDelayMs = 1,
  int maxDelayMs = 2,
  int maxTotalElapsedMs = 20000,
}) {
  late final Dio dio;
  dio = Dio(
    BaseOptions(
      baseUrl: 'https://test.example.com',
      // Mirrors ApiClient: every status is "valid", so Dio never raises a
      // DioException for a status code and onError only ever sees transport
      // failures.
      validateStatus: (_) => true,
    ),
  );
  dio.interceptors.add(
    RetryInterceptor(
      dioGetter: () => dio,
      maxRetries: maxRetries,
      baseDelayMs: baseDelayMs,
      maxDelayMs: maxDelayMs,
      maxTotalElapsedMs: maxTotalElapsedMs,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RetryInterceptor status classification', () {
    test('retries a 503 response even though validateStatus keeps status '
        'failures out of onError (regression: the 5xx branch only ever ran '
        'from onError, so no server error ever produced a client retry)',
        () async {
      final adapter = _ScriptedAdapter([503, 200]);
      final dio = _buildDio(adapter);

      final response = await dio.post<dynamic>(
        '/v1/push/send-all',
        data: {'title': 'hi'},
      );

      expect(adapter.calls, 2, reason: 'the 503 must be retried once');
      expect(response.statusCode, 200);
      expect(response.requestOptions.extra[RetryInterceptor.retryCountKey], 1);
    });

    test('gives up after maxRetries and returns the last failing response',
        () async {
      final adapter = _ScriptedAdapter([503]);
      final dio = _buildDio(adapter, maxRetries: 2);

      final response = await dio.get<dynamic>('/v1/machines');

      expect(adapter.calls, 3, reason: '1 initial attempt + 2 retries');
      expect(response.statusCode, 503);
    });

    test('retries 429 rate limits', () async {
      final adapter = _ScriptedAdapter([429, 200]);
      final dio = _buildDio(adapter);

      final response = await dio.get<dynamic>('/v1/machines');

      expect(adapter.calls, 2);
      expect(response.statusCode, 200);
    });

    test('does not retry 4xx client errors', () async {
      final adapter = _ScriptedAdapter([404]);
      final dio = _buildDio(adapter);

      final response = await dio.get<dynamic>('/v1/missing');

      expect(adapter.calls, 1);
      expect(response.statusCode, 404);
    });

    test('honours extra[disableRetry] on status failures', () async {
      final adapter = _ScriptedAdapter([503]);
      final dio = _buildDio(adapter);

      final response = await dio.get<dynamic>(
        '/v3/sessions/abc/messages',
        options: Options(extra: const {'disableRetry': true}),
      );

      expect(adapter.calls, 1);
      expect(response.statusCode, 503);
    });

    test('stops retrying once the total elapsed budget is spent', () async {
      final adapter = _ScriptedAdapter([503]);
      final dio = _buildDio(
        adapter,
        maxRetries: 5,
        baseDelayMs: 30,
        maxDelayMs: 30,
        maxTotalElapsedMs: 40,
      );

      final response = await dio.get<dynamic>('/v1/machines');

      expect(
        adapter.calls,
        2,
        reason:
            'one 30ms backoff fits in the 40ms budget, the second does not, '
            'so the sequence stops well before maxRetries',
      );
      expect(response.statusCode, 503);
    });
  });

  group('RetryInterceptor 401 handling', () {
    late List<int> notifications;
    late OnTokenRefreshFailed listener;

    setUp(() {
      tokenRefreshManager.reset();
      notifications = [];
      listener = () => notifications.add(1);
      tokenRefreshManager.onRefreshFailed(listener);
    });

    tearDown(() {
      tokenRefreshManager
        ..removeOnRefreshFailed(listener)
        ..reset();
    });

    test('surfaces a 401 as re-authentication required without retrying '
        '(the server has no refresh endpoint and its tokens never expire)',
        () async {
      final adapter = _ScriptedAdapter([401]);
      final dio = _buildDio(adapter);

      final response = await dio.get<dynamic>('/v1/machines');

      expect(adapter.calls, 1, reason: 'a 401 is never retried');
      expect(response.statusCode, 401);
      expect(notifications, hasLength(1));
    });

    test('a burst of 401s notifies re-authentication only once', () async {
      final adapter = _ScriptedAdapter([401]);
      final dio = _buildDio(adapter);

      await dio.get<dynamic>('/v1/machines');
      await dio.get<dynamic>('/v1/account/profile');
      await dio.get<dynamic>('/v2/sessions');

      expect(notifications, hasLength(1));
    });

    test('does not notify for 401s on the auth endpoints themselves '
        '(the re-auth listener re-verifies via /v1/auth/verify)', () async {
      final adapter = _ScriptedAdapter([401]);
      final dio = _buildDio(adapter);

      final response = await dio.get<dynamic>('/v1/auth/verify');

      expect(response.statusCode, 401);
      expect(notifications, isEmpty);
    });
  });

  group('RetryInterceptor transport failures', () {
    test('retries connection errors surfaced through onError', () async {
      var calls = 0;
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://test.example.com',
          validateStatus: (_) => true,
        ),
      );
      dio.interceptors.add(
        RetryInterceptor(
          dioGetter: () => dio,
          maxRetries: 2,
          baseDelayMs: 1,
          maxDelayMs: 2,
        ),
      );
      dio.httpClientAdapter = _ThrowingAdapter(() {
        calls++;
        if (calls == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: '/v1/machines'),
            type: DioExceptionType.connectionError,
          );
        }
      });

      final response = await dio.get<dynamic>('/v1/machines');

      expect(calls, 2);
      expect(response.statusCode, 200);
    });
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  _ThrowingAdapter(this.onFetch);

  final void Function() onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onFetch();
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
