import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/sessions_api.dart';
import 'package:mockito/mockito.dart';

import 'kv_api_test.mocks.dart';

Response<dynamic> _response(dynamic data, int statusCode) {
  return Response<dynamic>(
    data: data,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: ''),
  );
}

void main() {
  group('SessionsApi.fetchSessions', () {
    late MockApiClient mockClient;
    late SessionsApi api;

    setUp(() {
      mockClient = MockApiClient();
      api = SessionsApi(client: mockClient);
    });

    test('uses v2 pagination when v2 has data', () async {
      when(
        mockClient.get(
          '/v2/sessions',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final qp =
            invocation.namedArguments[#queryParameters]
                as Map<String, dynamic>?;
        if (qp?['cursor'] == null) {
          return _response({
            'sessions': [
              {'id': 'session-1'},
            ],
            'hasNext': true,
            'nextCursor': 'cursor-1',
          }, 200);
        }
        return _response({
          'sessions': [
            {'id': 'session-2'},
          ],
          'hasNext': false,
          'nextCursor': null,
        }, 200);
      });

      final result = await api.fetchSessions(limit: 50);

      expect(result, hasLength(2));
      expect(result[0]['id'], 'session-1');
      expect(result[1]['id'], 'session-2');
      verifyNever(mockClient.get('/v1/sessions'));
    });

    test('returns empty list when initial full v2 fetch is empty', () async {
      when(
        mockClient.get(
          '/v2/sessions',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _response({
          'sessions': [],
          'hasNext': false,
          'nextCursor': null,
        }, 200),
      );
      final result = await api.fetchSessions();

      expect(result, isEmpty);
      verifyNever(mockClient.get('/v1/sessions'));
    });

    test('throws when v2 fetch fails', () async {
      when(
        mockClient.get(
          '/v2/sessions',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer((_) async => _response({}, 500));

      expect(
        () => api.fetchSessions(),
        throwsA(isA<SessionsApiException>()),
      );
      verifyNever(mockClient.get('/v1/sessions'));
    });

    test('uses v2 only for delta fetches', () async {
      when(
        mockClient.get(
          '/v2/sessions',
          queryParameters: anyNamed('queryParameters'),
        ),
      ).thenAnswer(
        (_) async => _response({
          'sessions': [],
          'hasNext': false,
          'nextCursor': null,
        }, 200),
      );

      final result = await api.fetchSessions(changedSince: 1234567890);

      expect(result, isEmpty);
      verifyNever(mockClient.get('/v1/sessions'));
    });
  });
}
