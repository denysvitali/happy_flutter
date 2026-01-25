import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/services_api.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';

@GenerateMocks([ApiClient])
import 'services_api_test.mocks.dart';

void main() {
  group('ServicesApi', () {
    late MockApiClient mockClient;
    late ServicesApi servicesApi;

    setUp(() {
      mockClient = MockApiClient();
      servicesApi = ServicesApi(client: mockClient);
    });

    group('connectService', () {
      test('successfully connects a service', () async {
        when(mockClient.post(
          '/v1/connect/github/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await servicesApi.connectService('github', 'test-token');

        verify(mockClient.post(
          '/v1/connect/github/register',
          data: {'token': 'test-token'},
        )).called(1);
      });

      test('throws exception when service name is empty', () async {
        expect(
          () => servicesApi.connectService('', 'test-token'),
          throwsA(isA<ServicesApiException>()
              .having((e) => e.message, 'message',
                  contains('Service name cannot be empty'))),
        );
      });

      test('throws exception when token is empty', () async {
        expect(
          () => servicesApi.connectService('github', ''),
          throwsA(isA<ServicesApiException>()
              .having((e) => e.message, 'message',
                  contains('Service token cannot be empty'))),
        );
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.post(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'error': 'Invalid token'},
          statusCode: 401,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => servicesApi.connectService('github', 'invalid-token'),
          throwsA(isA<ServicesApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', contains('Failed to connect github'))),
        );
      });

      test('throws exception when success is false', () async {
        when(mockClient.post(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': false},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => servicesApi.connectService('github', 'test-token'),
          throwsA(isA<ServicesApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to connect github account'))),
        );
      });
    });

    group('disconnectService', () {
      test('successfully disconnects a service', () async {
        when(mockClient.delete('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await servicesApi.disconnectService('github');

        verify(mockClient.delete('/v1/connect/github')).called(1);
      });

      test('throws exception when service name is empty', () async {
        expect(
          () => servicesApi.disconnectService(''),
          throwsA(isA<ServicesApiException>()
              .having((e) => e.message, 'message',
                  contains('Service name cannot be empty'))),
        );
      });

      test('throws exception with service not connected (404)', () async {
        when(mockClient.delete(any))
            .thenAnswer((_) async => Response(
          data: {'error': 'GitHub account not connected'},
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => servicesApi.disconnectService('github'),
          throwsA(isA<ServicesApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message',
                  contains('GitHub account not connected'))),
        );
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.delete(any))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 500,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => servicesApi.disconnectService('github'),
          throwsA(isA<ServicesApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message',
                  contains('Failed to disconnect github'))),
        );
      });
    });

    group('isServiceConnected', () {
      test('returns true when service is connected (200)', () async {
        when(mockClient.get('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: {'connected': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await servicesApi.isServiceConnected('github');

        expect(result, isTrue);
      });

      test('returns false when service is not connected', () async {
        when(mockClient.get('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await servicesApi.isServiceConnected('github');

        expect(result, isFalse);
      });

      test('throws exception when service name is empty', () async {
        expect(
          () => servicesApi.isServiceConnected(''),
          throwsA(isA<ServicesApiException>()
              .having((e) => e.message, 'message',
                  contains('Service name cannot be empty'))),
        );
      });

      test('returns false on error', () async {
        when(mockClient.get(any))
            .thenThrow(Exception('Network error'));

        final result = await servicesApi.isServiceConnected('github');

        expect(result, isFalse);
      });
    });

    group('getAllConnectionStatus', () {
      test('returns connection status for all services', () async {
        when(mockClient.get('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));
        when(mockClient.get('/v1/connect/claude'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));
        when(mockClient.get('/v1/connect/gemini'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        ));
        when(mockClient.get('/v1/connect/openai'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await servicesApi.getAllConnectionStatus();

        expect(result, {
          'github': true,
          'claude': true,
          'gemini': false,
          'openai': false,
        });
      });

      test('handles errors gracefully', () async {
        when(mockClient.get(any))
            .thenThrow(Exception('Network error'));

        final result = await servicesApi.getAllConnectionStatus();

        expect(result, {
          'github': false,
          'claude': false,
          'gemini': false,
          'openai': false,
        });
      });
    });

    group('Convenience methods', () {
      test('connectGitHub calls connectService with correct params', () async {
        when(mockClient.post(
          '/v1/connect/github/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await servicesApi.connectGitHub('github-token');

        verify(mockClient.post(
          '/v1/connect/github/register',
          data: {'token': 'github-token'},
        )).called(1);
      });

      test('disconnectGitHub calls disconnectService', () async {
        when(mockClient.delete('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await servicesApi.disconnectGitHub();

        verify(mockClient.delete('/v1/connect/github')).called(1);
      });

      test('connectClaude calls connectService with correct params', () async {
        when(mockClient.post(
          '/v1/connect/claude/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await servicesApi.connectClaude('claude-token');

        verify(mockClient.post(
          '/v1/connect/claude/register',
          data: {'token': 'claude-token'},
        )).called(1);
      });

      test('connectGemini calls connectService with correct params', () async {
        when(mockClient.post(
          '/v1/connect/gemini/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await servicesApi.connectGemini('gemini-token');

        verify(mockClient.post(
          '/v1/connect/gemini/register',
          data: {'token': 'gemini-token'},
        )).called(1);
      });

      test('connectOpenAI calls connectService with correct params', () async {
        when(mockClient.post(
          '/v1/connect/openai/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await servicesApi.connectOpenAI('openai-token');

        verify(mockClient.post(
          '/v1/connect/openai/register',
          data: {'token': 'openai-token'},
        )).called(1);
      });
    });

    group('ServicesApiException', () {
      test('has correct properties', () {
        final exception = const ServicesApiException(
          'Test error',
          statusCode: 400,
        );

        expect(exception.message, 'Test error');
        expect(exception.statusCode, 400);
        expect(exception.toString(), 'ServicesApiException: Test error');
      });

      test('implements equality', () {
        const exception1 = ServicesApiException('Error', statusCode: 400);
        const exception2 = ServicesApiException('Error', statusCode: 400);
        const exception3 = ServicesApiException('Different', statusCode: 400);

        expect(exception1, equals(exception2));
        expect(exception1, isNot(equals(exception3)));
        expect(exception1.hashCode, equals(exception2.hashCode));
      });
    });
  });
}
