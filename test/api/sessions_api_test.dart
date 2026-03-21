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

  group('SessionsApi.setSessionArchived', () {
    late MockApiClient mockClient;
    late SessionsApi api;

    setUp(() {
      mockClient = MockApiClient();
      api = SessionsApi(client: mockClient);
    });

    test('sends POST with archived: true', () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _response({}, 200),
      );

      await api.setSessionArchived('sess-1', true);

      verify(
        mockClient.post(
          '/v1/sessions/sess-1/archive',
          data: {'archived': true},
        ),
      ).called(1);
    });

    test('sends POST with archived: false', () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _response({}, 200),
      );

      await api.setSessionArchived('sess-1', false);

      verify(
        mockClient.post(
          '/v1/sessions/sess-1/archive',
          data: {'archived': false},
        ),
      ).called(1);
    });

    test('throws on 500 status', () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _response({}, 500),
      );

      expect(
        () => api.setSessionArchived('sess-1', true),
        throwsA(
          isA<SessionsApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('error message includes archive for true',
        () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _response({}, 400),
      );

      expect(
        () => api.setSessionArchived('sess-1', true),
        throwsA(
          isA<SessionsApiException>().having(
            (e) => e.message,
            'message',
            contains('archive'),
          ),
        ),
      );
    });

    test('error message includes unarchive for false',
        () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _response({}, 400),
      );

      expect(
        () => api.setSessionArchived('sess-1', false),
        throwsA(
          isA<SessionsApiException>().having(
            (e) => e.message,
            'message',
            contains('unarchive'),
          ),
        ),
      );
    });
  });

  group('SessionsApi.deleteSession', () {
    late MockApiClient mockClient;
    late SessionsApi api;

    setUp(() {
      mockClient = MockApiClient();
      api = SessionsApi(client: mockClient);
    });

    test('sends DELETE to correct path', () async {
      when(mockClient.delete(any)).thenAnswer(
        (_) async => _response({}, 200),
      );

      await api.deleteSession('sess-42');

      verify(
        mockClient.delete('/v1/sessions/sess-42'),
      ).called(1);
    });

    test('throws on 404 status', () async {
      when(mockClient.delete(any)).thenAnswer(
        (_) async => _response({}, 404),
      );

      expect(
        () => api.deleteSession('sess-gone'),
        throwsA(
          isA<SessionsApiException>()
              .having(
                (e) => e.statusCode,
                'statusCode',
                404,
              )
              .having(
                (e) => e.message,
                'message',
                contains('Failed to delete session'),
              ),
        ),
      );
    });

    test('throws on 500 status', () async {
      when(mockClient.delete(any)).thenAnswer(
        (_) async => _response({}, 500),
      );

      expect(
        () => api.deleteSession('sess-1'),
        throwsA(
          isA<SessionsApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });
  });

  group('SessionsApi.updateSessionMetadata', () {
    late MockApiClient mockClient;
    late SessionsApi api;

    setUp(() {
      mockClient = MockApiClient();
      api = SessionsApi(client: mockClient);
    });

    test('sends POST with correct body', () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _response({}, 200),
      );

      await api.updateSessionMetadata(
        'sess-1',
        encryptedMetadata: 'enc-meta-blob',
        expectedVersion: 3,
      );

      verify(
        mockClient.post(
          '/v1/sessions/sess-1/metadata',
          data: {
            'metadata': 'enc-meta-blob',
            'expectedVersion': 3,
          },
        ),
      ).called(1);
    });

    test('throws on 500 status', () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _response({}, 500),
      );

      expect(
        () => api.updateSessionMetadata(
          'sess-1',
          encryptedMetadata: 'enc-meta',
          expectedVersion: 1,
        ),
        throwsA(
          isA<SessionsApiException>()
              .having(
                (e) => e.statusCode,
                'statusCode',
                500,
              )
              .having(
                (e) => e.message,
                'message',
                contains(
                  'Failed to update session metadata',
                ),
              ),
        ),
      );
    });

    test('throws on 409 conflict', () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async =>
            _response({'error': 'version conflict'}, 409),
      );

      expect(
        () => api.updateSessionMetadata(
          'sess-1',
          encryptedMetadata: 'enc-meta',
          expectedVersion: 2,
        ),
        throwsA(
          isA<SessionsApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            409,
          ),
        ),
      );
    });
  });

  group('SessionsApi.renameSession', () {
    late MockApiClient mockClient;
    late SessionsApi api;

    setUp(() {
      mockClient = MockApiClient();
      api = SessionsApi(client: mockClient);
    });

    test('sends POST with name in body', () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _response({}, 200),
      );

      await api.renameSession('sess-1', 'New Name');

      verify(
        mockClient.post(
          '/v1/sessions/sess-1/rename',
          data: {'name': 'New Name'},
        ),
      ).called(1);
    });

    test('throws on 400 status', () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _response({}, 400),
      );

      expect(
        () => api.renameSession('sess-1', ''),
        throwsA(
          isA<SessionsApiException>()
              .having(
                (e) => e.statusCode,
                'statusCode',
                400,
              )
              .having(
                (e) => e.message,
                'message',
                contains('Failed to rename session'),
              ),
        ),
      );
    });

    test('throws on 500 status', () async {
      when(
        mockClient.post(any, data: anyNamed('data')),
      ).thenAnswer(
        (_) async => _response({}, 500),
      );

      expect(
        () => api.renameSession('sess-1', 'Name'),
        throwsA(
          isA<SessionsApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });
  });

  group('SessionsApi.fetchSessionById', () {
    late MockApiClient mockClient;
    late SessionsApi api;

    setUp(() {
      mockClient = MockApiClient();
      api = SessionsApi(client: mockClient);
    });

    test('sends GET to correct path', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => _response({
          'session': {'id': 'sess-1', 'name': 'Test'},
        }, 200),
      );

      await api.fetchSessionById('sess-1');

      verify(
        mockClient.get('/v1/sessions/sess-1'),
      ).called(1);
    });

    test('returns session data on 200', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => _response({
          'session': {
            'id': 'sess-1',
            'name': 'My Session',
          },
        }, 200),
      );

      final result =
          await api.fetchSessionById('sess-1');

      expect(result, isNotNull);
      expect(result!['id'], 'sess-1');
      expect(result['name'], 'My Session');
    });

    test('returns null on 404', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => _response({}, 404),
      );

      final result =
          await api.fetchSessionById('sess-gone');

      expect(result, isNull);
    });

    test('returns null on 500', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => _response({}, 500),
      );

      final result =
          await api.fetchSessionById('sess-broken');

      expect(result, isNull);
    });

    test('returns null when get throws', () async {
      when(mockClient.get(any)).thenThrow(
        Exception('network error'),
      );

      final result =
          await api.fetchSessionById('sess-err');

      expect(result, isNull);
    });
  });
}
