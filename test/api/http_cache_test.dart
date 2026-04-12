import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/http_cache.dart';

Response<dynamic> _responseFor(
  String path, {
  Map<String, dynamic>? queryParameters,
  Map<String, dynamic>? extra,
}) {
  return Response<dynamic>(
    data: const {'ok': true},
    statusCode: 200,
    requestOptions: RequestOptions(
      path: path,
      method: 'GET',
      queryParameters: queryParameters ?? const <String, dynamic>{},
      extra: extra ?? const <String, dynamic>{},
    ),
  );
}

void main() {
  group('HttpResponseCache', () {
    late HttpResponseCache cache;

    setUp(() {
      cache = HttpResponseCache();
    });

    test('stores standard GET responses', () {
      final response = _responseFor(
        '/v2/sessions',
        queryParameters: const {'limit': 50},
      );

      cache.put(response.requestOptions, response);

      expect(cache.get(response.requestOptions), isNotNull);
    });

    test('does not store GET responses when bypassCache is true', () {
      final response = _responseFor(
        '/v3/sessions/sess-123/messages',
        queryParameters: const {'after_seq': 0, 'limit': 500},
        extra: const {'bypassCache': true},
      );

      cache.put(response.requestOptions, response);

      expect(cache.get(response.requestOptions), isNull);
    });
  });
}
