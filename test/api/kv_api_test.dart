import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/kv_api.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/models/kv.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';

@GenerateMocks([ApiClient])
import 'kv_api_test.mocks.dart';

void main() {
  group('KvApi', () {
    late MockApiClient mockClient;
    late KvApi kvApi;

    setUp(() {
      mockClient = MockApiClient();
      kvApi = KvApi(client: mockClient);
    });

    group('get', () {
      test('successfully gets a value by key', () async {
        final mockResponse = {
          'key': 'test-key',
          'value': 'test-value',
          'version': 1,
        };

        when(mockClient.get('/v1/kv/test-key'))
            .thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await kvApi.get('test-key');

        expect(result, isNotNull);
        expect(result!.key, 'test-key');
        expect(result.value, 'test-value');
        expect(result.version, 1);
      });

      test('returns null when key not found (404)', () async {
        when(mockClient.get('/v1/kv/non-existent'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await kvApi.get('non-existent');

        expect(result, isNull);
      });

      test('throws exception on non-200/404 response', () async {
        when(mockClient.get(any))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 500,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => kvApi.get('test-key'),
          throwsA(isA<KvApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message',
                  contains('Failed to get KV value'))),
        );
      });

      test('encodes key properly', () async {
        when(mockClient.get(any))
            .thenAnswer((_) async => Response(
          data: {'key': 'test key', 'value': 'value', 'version': 1},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await kvApi.get('test key');

        verify(mockClient.get('/v1/kv/test%20key')).called(1);
      });

      test('throws exception on invalid response data', () async {
        when(mockClient.get(any))
            .thenAnswer((_) async => Response(
          data: {'invalid': 'data'},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => kvApi.get('test-key'),
          throwsA(isA<KvApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to parse KV item'))),
        );
      });
    });

    group('list', () {
      test('successfully lists all items', () async {
        final mockResponse = {
          'items': [
            {'key': 'key1', 'value': 'value1', 'version': 1},
            {'key': 'key2', 'value': 'value2', 'version': 2},
          ],
        };

        when(mockClient.get(
          '/v1/kv',
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await kvApi.list();

        expect(result.items, hasLength(2));
        expect(result.items[0].key, 'key1');
        expect(result.items[1].key, 'key2');
      });

      test('filters by prefix', () async {
        when(mockClient.get(
          '/v1/kv',
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => Response(
          data: {'items': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await kvApi.list(prefix: 'user:');

        verify(mockClient.get(
          '/v1/kv',
          queryParameters: {'prefix': 'user:'},
        )).called(1);
      });

      test('applies limit', () async {
        when(mockClient.get(
          '/v1/kv',
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => Response(
          data: {'items': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await kvApi.list(limit: 50);

        verify(mockClient.get(
          '/v1/kv',
          queryParameters: {'limit': '50'},
        )).called(1);
      });

      test('combines prefix and limit', () async {
        when(mockClient.get(
          '/v1/kv',
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => Response(
          data: {'items': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await kvApi.list(prefix: 'session:', limit: 100);

        verify(mockClient.get(
          '/v1/kv',
          queryParameters: {'prefix': 'session:', 'limit': '100'},
        )).called(1);
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => Response(
          data: {},
          statusCode: 500,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => kvApi.list(),
          throwsA(isA<KvApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message',
                  contains('Failed to list KV items'))),
        );
      });
    });

    group('bulkGet', () {
      test('successfully gets multiple values', () async {
        final mockResponse = {
          'values': [
            {'key': 'key1', 'value': 'value1', 'version': 1},
            {'key': 'key2', 'value': 'value2', 'version': 2},
          ],
        };

        when(mockClient.post(
          '/v1/kv/bulk',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await kvApi.bulkGet(['key1', 'key2']);

        expect(result.values, hasLength(2));
        expect(result.values[0].key, 'key1');
        expect(result.values[1].key, 'key2');

        verify(mockClient.post(
          '/v1/kv/bulk',
          data: {'keys': ['key1', 'key2']},
        )).called(1);
      });

      test('returns empty list for empty keys', () async {
        final result = await kvApi.bulkGet([]);

        expect(result.values, isEmpty);
        verifyNever(mockClient.post(any, data: anyNamed('data')));
      });

      test('throws exception for more than 100 keys', () async {
        final keys = List.generate(101, (i) => 'key$i');

        expect(
          () => kvApi.bulkGet(keys),
          throwsA(isA<KvApiException>()
              .having((e) => e.message, 'message',
                  contains('Cannot bulk get more than 100 keys'))),
        );
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.post(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {},
          statusCode: 500,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => kvApi.bulkGet(['key1']),
          throwsA(isA<KvApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message',
                  contains('Failed to bulk get KV values'))),
        );
      });
    });

    group('mutate', () {
      test('successfully creates new key', () async {
        final mockResponse = {
          'success': true,
          'results': [
            {'key': 'new-key', 'version': 1},
          ],
        };

        when(mockClient.post(
          '/v1/kv',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final mutations = [
          KvMutation(key: 'new-key', value: 'new-value', version: -1),
        ];

        final result = await kvApi.mutate(mutations);

        expect(result.isSuccess, isTrue);
        expect(result.results, hasLength(1));
        expect(result.results[0].key, 'new-key');
        expect(result.results[0].version, 1);
      });

      test('successfully updates existing key', () async {
        final mockResponse = {
          'success': true,
          'results': [
            {'key': 'existing-key', 'version': 2},
          ],
        };

        when(mockClient.post(
          '/v1/kv',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final mutations = [
          KvMutation(key: 'existing-key', value: 'updated-value', version: 1),
        ];

        final result = await kvApi.mutate(mutations);

        expect(result.isSuccess, isTrue);
        expect(result.results[0].version, 2);
      });

      test('handles version mismatch error', () async {
        final mockResponse = {
          'success': false,
          'errors': [
            {
              'key': 'conflicted-key',
              'error': 'version-mismatch',
              'version': 5,
              'value': 'server-value',
            },
          ],
        };

        when(mockClient.post(
          '/v1/kv',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 409,
          requestOptions: RequestOptions(path: ''),
        ));

        final mutations = [
          KvMutation(key: 'conflicted-key', value: 'client-value', version: 3),
        ];

        final result = await kvApi.mutate(mutations);

        expect(result.isError, isTrue);
        expect(result.errors, hasLength(1));
        expect(result.errors[0].key, 'conflicted-key');
        expect(result.errors[0].error, 'version-mismatch');
        expect(result.errors[0].version, 5);
        expect(result.errors[0].value, 'server-value');
      });

      test('returns empty success for empty mutations', () async {
        final result = await kvApi.mutate([]);

        expect(result.isSuccess, isTrue);
        expect(result.results, isEmpty);
        verifyNever(mockClient.post(any, data: anyNamed('data')));
      });

      test('throws exception for more than 100 mutations', () async {
        final mutations = List.generate(
          101,
          (i) => KvMutation(key: 'key$i', value: 'value', version: -1),
        );

        expect(
          () => kvApi.mutate(mutations),
          throwsA(isA<KvApiException>()
              .having((e) => e.message, 'message',
                  contains('Cannot mutate more than 100 keys'))),
        );
      });

      test('throws exception on non-200/409 response', () async {
        when(mockClient.post(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {},
          statusCode: 500,
          requestOptions: RequestOptions(path: ''),
        ));

        final mutations = [
          KvMutation(key: 'key', value: 'value', version: -1),
        ];

        expect(
          () => kvApi.mutate(mutations),
          throwsA(isA<KvApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message',
                  contains('Failed to mutate KV values'))),
        );
      });
    });

    group('set', () {
      test('sets a new key with default version', () async {
        when(mockClient.post(
          '/v1/kv',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true, 'results': [{'key': 'key', 'version': 1}]},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final version = await kvApi.set('key', 'value');

        expect(version, 1);

        verify(mockClient.post(
          '/v1/kv',
          data: argThat(
            allOf([
              containsPair('mutations', isList),
            ]),
            named: 'data'),
        )).called(1);
      });

      test('throws exception on version mismatch', () async {
        when(mockClient.post(
          '/v1/kv',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {
            'success': false,
            'errors': [
              {'key': 'key', 'error': 'version-mismatch', 'version': 5}
            ]
          },
          statusCode: 409,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => kvApi.set('key', 'value', version: 3),
          throwsA(isA<KvApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message',
                  contains('version-mismatch'))),
        );
      });
    });

    group('delete', () {
      test('deletes a key', () async {
        when(mockClient.post(
          '/v1/kv',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true, 'results': [{'key': 'key', 'version': 2}]},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await kvApi.delete('key', 1);

        verify(mockClient.post(
          '/v1/kv',
          data: argThat(
            allOf([
              containsPair('mutations', isList),
            ]),
            named: 'data'),
        )).called(1);
      });

      test('throws exception on version mismatch', () async {
        when(mockClient.post(
          '/v1/kv',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {
            'success': false,
            'errors': [
              {'key': 'key', 'error': 'version-mismatch', 'version': 5}
            ]
          },
          statusCode: 409,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => kvApi.delete('key', 3),
          throwsA(isA<KvApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message',
                  contains('version-mismatch'))),
        );
      });
    });

    group('getByPrefix', () {
      test('gets keys with prefix using default limit', () async {
        when(mockClient.get(
          '/v1/kv',
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => Response(
          data: {'items': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await kvApi.getByPrefix('user:');

        verify(mockClient.get(
          '/v1/kv',
          queryParameters: {'prefix': 'user:', 'limit': '100'},
        )).called(1);
      });

      test('uses custom limit', () async {
        when(mockClient.get(
          '/v1/kv',
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => Response(
          data: {'items': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await kvApi.getByPrefix('user:', limit: 50);

        verify(mockClient.get(
          '/v1/kv',
          queryParameters: {'prefix': 'user:', 'limit': '50'},
        )).called(1);
      });

      test('returns items from list response', () async {
        final mockResponse = {
          'items': [
            {'key': 'user:1', 'value': 'value1', 'version': 1},
            {'key': 'user:2', 'value': 'value2', 'version': 1},
          ],
        };

        when(mockClient.get(
          '/v1/kv',
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await kvApi.getByPrefix('user:');

        expect(result, hasLength(2));
        expect(result[0].key, 'user:1');
        expect(result[1].key, 'user:2');
      });
    });

    group('KvApiException', () {
      test('has correct properties', () {
        final exception = const KvApiException(
          'Test error',
          statusCode: 500,
        );

        expect(exception.message, 'Test error');
        expect(exception.statusCode, 500);
        expect(exception.toString(), 'KvApiException: Test error');
      });

      test('implements equality', () {
        const exception1 = KvApiException('Error', statusCode: 500);
        const exception2 = KvApiException('Error', statusCode: 500);
        const exception3 = KvApiException('Different', statusCode: 500);

        expect(exception1, equals(exception2));
        expect(exception1, isNot(equals(exception3)));
        expect(exception1.hashCode, equals(exception2.hashCode));
      });
    });
  });
}
