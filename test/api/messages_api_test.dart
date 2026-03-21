import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/messages_api.dart';
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
  group('MessagesApi', () {
    late MockApiClient mockClient;
    late MessagesApi api;

    setUp(() {
      mockClient = MockApiClient();
      api = MessagesApi(client: mockClient);
    });

    group('fetchMessages', () {
      test('sends correct GET path and query params', () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.get(
            '/v3/sessions/sess-123/messages',
            queryParameters: anyNamed('queryParameters'),
          ),
        ).thenAnswer(
          (_) async => _response({
            'messages': <Map<String, dynamic>>[],
            'hasMore': false,
          }, 200),
        );

        await api.fetchMessages('sess-123', afterSeq: 0);

        verify(
          mockClient.get(
            '/v3/sessions/sess-123/messages',
            queryParameters: {
              'after_seq': 0,
              'limit': 100,
            },
          ),
        ).called(1);
      });

      test('passes custom limit in query params', () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.get(
            any,
            queryParameters: anyNamed('queryParameters'),
          ),
        ).thenAnswer(
          (_) async => _response({
            'messages': <Map<String, dynamic>>[],
            'hasMore': false,
          }, 200),
        );

        await api.fetchMessages(
          'sess-456',
          afterSeq: 10,
          limit: 50,
        );

        verify(
          mockClient.get(
            '/v3/sessions/sess-456/messages',
            queryParameters: {
              'after_seq': 10,
              'limit': 50,
            },
          ),
        ).called(1);
      });

      test('returns messages and hasMore from response',
          () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.get(
            any,
            queryParameters: anyNamed('queryParameters'),
          ),
        ).thenAnswer(
          (_) async => _response({
            'messages': [
              {
                'id': 'msg-1',
                'content': 'hello',
                'seq': 1,
              },
              {
                'id': 'msg-2',
                'content': 'world',
                'seq': 2,
              },
            ],
            'hasMore': true,
          }, 200),
        );

        final result = await api.fetchMessages(
          'sess-1',
          afterSeq: 0,
        );

        expect(result.messages, hasLength(2));
        expect(result.messages[0]['id'], 'msg-1');
        expect(result.messages[1]['id'], 'msg-2');
        expect(result.hasMore, isTrue);
      });

      test('returns empty messages when none exist',
          () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.get(
            any,
            queryParameters: anyNamed('queryParameters'),
          ),
        ).thenAnswer(
          (_) async => _response({
            'messages': <Map<String, dynamic>>[],
            'hasMore': false,
          }, 200),
        );

        final result = await api.fetchMessages(
          'sess-empty',
          afterSeq: 0,
        );

        expect(result.messages, isEmpty);
        expect(result.hasMore, isFalse);
      });

      test('handles missing messages key gracefully',
          () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.get(
            any,
            queryParameters: anyNamed('queryParameters'),
          ),
        ).thenAnswer(
          (_) async => _response(<String, dynamic>{}, 200),
        );

        final result = await api.fetchMessages(
          'sess-1',
          afterSeq: 0,
        );

        expect(result.messages, isEmpty);
        expect(result.hasMore, isFalse);
      });

      test('throws on 400 status', () async {
        when(mockClient.isSuccess(any)).thenReturn(false);
        when(
          mockClient.get(
            any,
            queryParameters: anyNamed('queryParameters'),
          ),
        ).thenAnswer(
          (_) async => _response({'error': 'bad request'}, 400),
        );

        expect(
          () => api.fetchMessages('sess-1', afterSeq: 0),
          throwsA(
            isA<MessagesApiException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  400,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('Failed to fetch messages'),
                ),
          ),
        );
      });

      test('throws on 404 status', () async {
        when(mockClient.isSuccess(any)).thenReturn(false);
        when(
          mockClient.get(
            any,
            queryParameters: anyNamed('queryParameters'),
          ),
        ).thenAnswer(
          (_) async => _response({'error': 'not found'}, 404),
        );

        expect(
          () => api.fetchMessages('sess-gone', afterSeq: 0),
          throwsA(
            isA<MessagesApiException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  404,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('Failed to fetch messages'),
                ),
          ),
        );
      });

      test('throws on 500 status', () async {
        when(mockClient.isSuccess(any)).thenReturn(false);
        when(
          mockClient.get(
            any,
            queryParameters: anyNamed('queryParameters'),
          ),
        ).thenAnswer(
          (_) async =>
              _response({'error': 'internal error'}, 500),
        );

        expect(
          () => api.fetchMessages('sess-1', afterSeq: 0),
          throwsA(
            isA<MessagesApiException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  500,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('Failed to fetch messages'),
                ),
          ),
        );
      });
    });

    group('sendMessage', () {
      test('sends correct POST body structure', () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _response({
            'messages': [
              {
                'id': 'server-msg-1',
                'seq': 42,
                'createdAt': 1700000000000,
                'localId': 'local-1',
              },
            ],
          }, 200),
        );

        await api.sendMessage(
          'sess-123',
          encryptedContent: 'encrypted-data',
          localId: 'local-1',
        );

        verify(
          mockClient.post(
            '/v3/sessions/sess-123/messages',
            data: {
              'messages': [
                {
                  'content': 'encrypted-data',
                  'localId': 'local-1',
                },
              ],
            },
          ),
        ).called(1);
      });

      test('omits localId from body when null', () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _response({
            'messages': [
              {
                'id': 'server-msg-2',
                'seq': 1,
                'createdAt': 1700000000000,
              },
            ],
          }, 200),
        );

        await api.sendMessage(
          'sess-123',
          encryptedContent: 'encrypted-data',
        );

        verify(
          mockClient.post(
            '/v3/sessions/sess-123/messages',
            data: {
              'messages': [
                {'content': 'encrypted-data'},
              ],
            },
          ),
        ).called(1);
      });

      test('returns parsed response with server data',
          () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _response({
            'messages': [
              {
                'id': 'server-msg-1',
                'seq': 42,
                'createdAt': 1700000000000,
                'localId': 'local-1',
              },
            ],
          }, 200),
        );

        final result = await api.sendMessage(
          'sess-123',
          encryptedContent: 'encrypted-data',
          localId: 'local-1',
        );

        expect(result.id, 'server-msg-1');
        expect(result.seq, 42);
        expect(result.createdAt, 1700000000000);
        expect(result.localId, 'local-1');
      });

      test(
          'throws when server returns empty messages '
          'list', () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _response({
            'messages': <Map<String, dynamic>>[],
          }, 200),
        );

        expect(
          () => api.sendMessage(
            'sess-123',
            encryptedContent: 'encrypted-data',
          ),
          throwsA(
            isA<MessagesApiException>().having(
              (e) => e.message,
              'message',
              contains('No message returned'),
            ),
          ),
        );
      });

      test('throws on 400 status', () async {
        when(mockClient.isSuccess(any)).thenReturn(false);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _response({'error': 'bad request'}, 400),
        );

        expect(
          () => api.sendMessage(
            'sess-123',
            encryptedContent: 'encrypted-data',
          ),
          throwsA(
            isA<MessagesApiException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  400,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('Failed to send message'),
                ),
          ),
        );
      });

      test('throws on 404 status', () async {
        when(mockClient.isSuccess(any)).thenReturn(false);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _response({'error': 'not found'}, 404),
        );

        expect(
          () => api.sendMessage(
            'sess-gone',
            encryptedContent: 'encrypted-data',
          ),
          throwsA(
            isA<MessagesApiException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  404,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('Failed to send message'),
                ),
          ),
        );
      });

      test('throws on 500 status', () async {
        when(mockClient.isSuccess(any)).thenReturn(false);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async =>
              _response({'error': 'internal error'}, 500),
        );

        expect(
          () => api.sendMessage(
            'sess-123',
            encryptedContent: 'encrypted-data',
          ),
          throwsA(
            isA<MessagesApiException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  500,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('Failed to send message'),
                ),
          ),
        );
      });
    });

    group('sendMessagesBatch', () {
      test('sends correct POST body for multiple messages',
          () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _response({
            'messages': [
              {
                'id': 'srv-1',
                'seq': 1,
                'createdAt': 1700000000000,
                'localId': 'loc-1',
              },
              {
                'id': 'srv-2',
                'seq': 2,
                'createdAt': 1700000001000,
              },
            ],
          }, 200),
        );

        await api.sendMessagesBatch(
          'sess-123',
          messages: [
            const SendMessageRequest(
              encryptedContent: 'enc-1',
              localId: 'loc-1',
            ),
            const SendMessageRequest(
              encryptedContent: 'enc-2',
            ),
          ],
        );

        verify(
          mockClient.post(
            '/v3/sessions/sess-123/messages',
            data: {
              'messages': [
                {
                  'content': 'enc-1',
                  'localId': 'loc-1',
                },
                {'content': 'enc-2'},
              ],
            },
          ),
        ).called(1);
      });

      test('returns parsed responses for each message',
          () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _response({
            'messages': [
              {
                'id': 'srv-1',
                'seq': 10,
                'createdAt': 1700000000000,
                'localId': 'loc-1',
              },
              {
                'id': 'srv-2',
                'seq': 11,
                'createdAt': 1700000001000,
              },
            ],
          }, 200),
        );

        final results = await api.sendMessagesBatch(
          'sess-123',
          messages: [
            const SendMessageRequest(
              encryptedContent: 'enc-1',
              localId: 'loc-1',
            ),
            const SendMessageRequest(
              encryptedContent: 'enc-2',
            ),
          ],
        );

        expect(results, hasLength(2));
        expect(results[0].id, 'srv-1');
        expect(results[0].seq, 10);
        expect(results[0].createdAt, 1700000000000);
        expect(results[0].localId, 'loc-1');
        expect(results[1].id, 'srv-2');
        expect(results[1].seq, 11);
        expect(results[1].localId, isNull);
      });

      test('returns empty list for empty input', () async {
        final results = await api.sendMessagesBatch(
          'sess-123',
          messages: [],
        );

        expect(results, isEmpty);
        verifyNever(
          mockClient.post(any, data: anyNamed('data')),
        );
      });

      test('returns empty list when server returns no '
          'messages', () async {
        when(mockClient.isSuccess(any)).thenReturn(true);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _response({
            'messages': <Map<String, dynamic>>[],
          }, 200),
        );

        final results = await api.sendMessagesBatch(
          'sess-123',
          messages: [
            const SendMessageRequest(
              encryptedContent: 'enc-1',
            ),
          ],
        );

        expect(results, isEmpty);
      });

      test('throws on 400 status', () async {
        when(mockClient.isSuccess(any)).thenReturn(false);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async => _response({'error': 'bad request'}, 400),
        );

        expect(
          () => api.sendMessagesBatch(
            'sess-123',
            messages: [
              const SendMessageRequest(
                encryptedContent: 'enc-1',
              ),
            ],
          ),
          throwsA(
            isA<MessagesApiException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  400,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('Failed to send messages'),
                ),
          ),
        );
      });

      test('throws on 500 status', () async {
        when(mockClient.isSuccess(any)).thenReturn(false);
        when(
          mockClient.post(any, data: anyNamed('data')),
        ).thenAnswer(
          (_) async =>
              _response({'error': 'internal error'}, 500),
        );

        expect(
          () => api.sendMessagesBatch(
            'sess-123',
            messages: [
              const SendMessageRequest(
                encryptedContent: 'enc-1',
              ),
            ],
          ),
          throwsA(
            isA<MessagesApiException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  500,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains('Failed to send messages'),
                ),
          ),
        );
      });
    });

    group('MessagesApiException', () {
      test('has correct properties', () {
        const exception = MessagesApiException(
          'Test error',
          statusCode: 500,
        );

        expect(exception.message, 'Test error');
        expect(exception.statusCode, 500);
        expect(
          exception.toString(),
          'MessagesApiException: Test error',
        );
      });

      test('implements equality', () {
        const e1 = MessagesApiException(
          'Error',
          statusCode: 500,
        );
        const e2 = MessagesApiException(
          'Error',
          statusCode: 500,
        );
        const e3 = MessagesApiException(
          'Different',
          statusCode: 500,
        );

        expect(e1, equals(e2));
        expect(e1, isNot(equals(e3)));
        expect(e1.hashCode, equals(e2.hashCode));
      });

      test('supports null statusCode', () {
        const exception = MessagesApiException('No status');

        expect(exception.statusCode, isNull);
        expect(exception.message, 'No status');
      });
    });
  });
}
