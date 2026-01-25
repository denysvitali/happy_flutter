import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/push_api.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';

@GenerateMocks([ApiClient])
import 'push_api_test.mocks.dart';

void main() {
  group('PushApi', () {
    late MockApiClient mockClient;
    late PushApi pushApi;

    setUp(() {
      mockClient = MockApiClient();
      pushApi = PushApi(client: mockClient);
    });

    group('registerToken', () {
      test('successfully registers a push token', () async {
        when(mockClient.post(
          '/v1/push-tokens',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await pushApi.registerToken('test-push-token');

        verify(mockClient.post(
          '/v1/push-tokens',
          data: {'token': 'test-push-token'},
        )).called(1);
      });

      test('throws exception when token is empty', () async {
        expect(
          () => pushApi.registerToken(''),
          throwsA(isA<PushApiException>()
              .having((e) => e.message, 'message',
                  contains('Push token cannot be empty'))),
        );
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.post(
          '/v1/push-tokens',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'error': 'Invalid token'},
          statusCode: 401,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => pushApi.registerToken('invalid-token'),
          throwsA(isA<PushApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message',
                  contains('Failed to register push token'))),
        );
      });

      test('throws exception when success is false', () async {
        when(mockClient.post(
          '/v1/push-tokens',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': false},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => pushApi.registerToken('test-token'),
          throwsA(isA<PushApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to register push token'))),
        );
      });

      test('throws exception when response data is null', () async {
        when(mockClient.post(
          '/v1/push-tokens',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: null,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => pushApi.registerToken('test-token'),
          throwsA(isA<PushApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to register push token'))),
        );
      });
    });

    group('unregisterToken', () {
      test('successfully unregisters a push token (200)', () async {
        when(mockClient.delete('/v1/push-tokens/test-token'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await pushApi.unregisterToken('test-token');

        verify(mockClient.delete('/v1/push-tokens/test-token')).called(1);
      });

      test('successfully unregisters a push token (204)', () async {
        when(mockClient.delete('/v1/push-tokens/test-token'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 204,
          requestOptions: RequestOptions(path: ''),
        ));

        await pushApi.unregisterToken('test-token');

        verify(mockClient.delete('/v1/push-tokens/test-token')).called(1);
      });

      test('throws exception when token is empty', () async {
        expect(
          () => pushApi.unregisterToken(''),
          throwsA(isA<PushApiException>()
              .having((e) => e.message, 'message',
                  contains('Push token cannot be empty'))),
        );
      });

      test('throws exception on non-200/204 response', () async {
        when(mockClient.delete(any))
            .thenAnswer((_) async => Response(
          data: {'error': 'Token not found'},
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => pushApi.unregisterToken('non-existent-token'),
          throwsA(isA<PushApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message',
                  contains('Failed to unregister push token'))),
        );
      });

      test('properly encodes token in URL', () async {
        when(mockClient.delete(any))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await pushApi.unregisterToken('token with spaces');

        verify(mockClient.delete('/v1/push-tokens/token with spaces'))
            .called(1);
      });
    });

    group('updateToken', () {
      test('successfully updates a push token', () async {
        when(mockClient.put(
          '/v1/push-tokens/old-token',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await pushApi.updateToken('old-token', 'new-token');

        verify(mockClient.put(
          '/v1/push-tokens/old-token',
          data: {'token': 'new-token'},
        )).called(1);
      });

      test('throws exception when old token is empty', () async {
        expect(
          () => pushApi.updateToken('', 'new-token'),
          throwsA(isA<PushApiException>()
              .having((e) => e.message, 'message',
                  contains('Push tokens cannot be empty'))),
        );
      });

      test('throws exception when new token is empty', () async {
        expect(
          () => pushApi.updateToken('old-token', ''),
          throwsA(isA<PushApiException>()
              .having((e) => e.message, 'message',
                  contains('Push tokens cannot be empty'))),
        );
      });

      test('throws exception when both tokens are empty', () async {
        expect(
          () => pushApi.updateToken('', ''),
          throwsA(isA<PushApiException>()
              .having((e) => e.message, 'message',
                  contains('Push tokens cannot be empty'))),
        );
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.put(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'error': 'Old token not found'},
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => pushApi.updateToken('old-token', 'new-token'),
          throwsA(isA<PushApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message',
                  contains('Failed to update push token'))),
        );
      });

      test('throws exception when success is false', () async {
        when(mockClient.put(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': false},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => pushApi.updateToken('old-token', 'new-token'),
          throwsA(isA<PushApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to update push token'))),
        );
      });

      test('throws exception when response data is null', () async {
        when(mockClient.put(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: null,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => pushApi.updateToken('old-token', 'new-token'),
          throwsA(isA<PushApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to update push token'))),
        );
      });

      test('properly encodes old token in URL', () async {
        when(mockClient.put(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await pushApi.updateToken('old token with spaces', 'new-token');

        verify(mockClient.put(
          '/v1/push-tokens/old token with spaces',
          data: {'token': 'new-token'},
        )).called(1);
      });
    });

    group('PushApiException', () {
      test('has correct properties', () {
        final exception = const PushApiException(
          'Test error',
          statusCode: 500,
        );

        expect(exception.message, 'Test error');
        expect(exception.statusCode, 500);
        expect(exception.toString(), 'PushApiException: Test error');
      });

      test('implements equality', () {
        const exception1 = PushApiException('Error', statusCode: 500);
        const exception2 = PushApiException('Error', statusCode: 500);
        const exception3 = PushApiException('Different', statusCode: 500);

        expect(exception1, equals(exception2));
        expect(exception1, isNot(equals(exception3)));
        expect(exception1.hashCode, equals(exception2.hashCode));
      });

      test('can be created without status code', () {
        const exception = PushApiException('Test error');

        expect(exception.message, 'Test error');
        expect(exception.statusCode, isNull);
      });
    });

    group('Integration scenarios', () {
      test('full token lifecycle', () async {
        // Register
        when(mockClient.post(
          '/v1/push-tokens',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await pushApi.registerToken('initial-token');

        // Update
        when(mockClient.put(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await pushApi.updateToken('initial-token', 'updated-token');

        // Unregister
        when(mockClient.delete(any))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await pushApi.unregisterToken('updated-token');

        verify(mockClient.post('/v1/push-tokens', data: anyNamed('data')))
            .called(1);
        verify(mockClient.put(any, data: anyNamed('data'))).called(1);
        verify(mockClient.delete(any)).called(1);
      });

      test('handles token refresh scenario', () async {
        // System provides new token from platform
        const oldToken = 'old-expired-token';
        const newToken = 'new-fresh-token';

        when(mockClient.put(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await pushApi.updateToken(oldToken, newToken);

        verify(mockClient.put(
          '/v1/push-tokens/$oldToken',
          data: {'token': newToken},
        )).called(1);
      });
    });
  });
}
