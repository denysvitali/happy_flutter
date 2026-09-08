import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/api/retry_interceptor.dart';
import 'package:happy_flutter/core/api/timed_http_adapter.dart';

class _BodyAdapter implements HttpClientAdapter {
  _BodyAdapter(this.chunks);
  final List<Uint8List> chunks;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(
    Stream.fromIterable(chunks),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('suspended optional reads emit the typed lifecycle reason', () async {
    final dio = Dio();
    final retry = RetryInterceptor(dioGetter: () => dio)..setSuspended(true);
    dio.interceptors.add(retry);
    try {
      await expectLater(
        dio.get<dynamic>('https://example.test/v2/sessions'),
        throwsA(predicate<Object>(isAppSuspensionCancellation)),
      );
    } finally {
      retry.dispose();
      dio.close();
    }
  });

  test('only typed suspend cancellation is expected in metrics', () {
    final options = RequestOptions(path: '/v2/sessions');
    for (final reason in <Object>[
      HttpCancellationReason.appSuspended,
      'HTTP request deadline exceeded',
      'HTTP client disposed',
      'App suspended; refresh deferred until resume',
    ]) {
      final error = DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: reason,
      );
      final attributes = ApiClient.debugBuildHttpMetricAttributes(
        options,
        phase: 'total',
        error: error,
      );
      final expected = reason == HttpCancellationReason.appSuspended;
      expect(isAppSuspensionCancellation(error), expected);
      expect(attributes['outcome'], expected ? 'cancelled' : 'transport_error');
      expect(attributes.containsKey('error.type'), !expected);
      expect(
        attributes['http.cancellation.reason'],
        expected ? 'app_suspended' : null,
      );
    }
    expect(
      isAppSuspensionCancellation(
        DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
          error: HttpCancellationReason.appSuspended,
        ),
      ),
      isFalse,
    );
    expect(
      ApiClient.debugBuildHttpMetricAttributes(
        options,
        phase: 'total',
        statusCode: 503,
      )['outcome'],
      'http_error',
    );
  });

  test(
    'counts complete adapter chunks without changing decoded response',
    () async {
      final adapter = TimedHttpAdapter(
        _BodyAdapter([
          Uint8List.fromList([123, 34, 97, 34]),
          Uint8List.fromList([58, 49, 125]),
        ]),
        lifecycle: () => 'active',
      );
      final dio = Dio()..httpClientAdapter = adapter;
      try {
        final response = await dio.get<dynamic>(
          'https://example.test/v2/sessions',
          options: Options(responseType: ResponseType.json),
        );
        expect(response.data, {'a': 1});
        expect(ApiClient.responseBodyBytes(response), 7);
      } finally {
        dio.close();
      }
    },
  );

  test('unknown JSON sizes are omitted; headers preserve empty bodies', () {
    final options = RequestOptions(path: '/v2/sessions');
    final response = Response<dynamic>(
      requestOptions: options,
      data: {
        'sessions': List.filled(10000, {'metadata': 'large'}),
      },
    );
    expect(ApiClient.responseBodyBytes(response), isNull);
    response.data = [1, 2, 3];
    expect(ApiClient.responseBodyBytes(response), isNull);
    response.headers.set(Headers.contentLengthHeader, '1198850');
    expect(ApiClient.responseBodyBytes(response), 1198850);
    response.headers.set(Headers.contentLengthHeader, '0');
    expect(ApiClient.responseBodyBytes(response), 0);
    response.headers.clear();
    final timing = HttpTransportTiming('test', 'active')..bodyBytes = 100;
    options.extra[HttpTransportTiming.extraKey] = timing;
    expect(ApiClient.responseBodyBytes(response), isNull);
    timing.bodyDoneUs = 1;
    expect(ApiClient.responseBodyBytes(response), 100);
  });
}
