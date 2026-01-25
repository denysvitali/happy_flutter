import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/github_api.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';

@GenerateMocks([ApiClient])
import 'github_api_test.mocks.dart';

void main() {
  group('GitHubApi', () {
    late MockApiClient mockClient;
    late GitHubApi githubApi;

    setUp(() {
      mockClient = MockApiClient();
      githubApi = GitHubApi(client: mockClient);
    });

    group('getOAuthParams', () {
      test('successfully gets OAuth parameters', () async {
        final mockResponse = {
          'url': 'https://github.com/login/oauth/authorize?client_id=123',
        };

        when(mockClient.get('/v1/connect/github/params'))
            .thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await githubApi.getOAuthParams();

        expect(result.url, contains('github.com/login/oauth/authorize'));
        expect(result.url, contains('client_id'));
      });

      test('throws exception with GitHub not configured (400)', () async {
        when(mockClient.get('/v1/connect/github/params'))
            .thenAnswer((_) async => Response(
          data: {'error': 'GitHub OAuth not configured on server'},
          statusCode: 400,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.getOAuthParams(),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message',
                  contains('GitHub OAuth not configured'))),
        );
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.get('/v1/connect/github/params'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 500,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.getOAuthParams(),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message',
                  contains('Failed to get GitHub OAuth params'))),
        );
      });

      test('throws exception on invalid response data', () async {
        when(mockClient.get('/v1/connect/github/params'))
            .thenAnswer((_) async => Response(
          data: {'invalid': 'data'},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.getOAuthParams(),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to parse OAuth params'))),
        );
      });
    });

    group('getAccountProfile', () {
      test('successfully gets account profile with GitHub', () async {
        final mockResponse = {
          'id': 'user-123',
          'timestamp': 1640995200,
          'github': {
            'id': 456,
            'login': 'testuser',
            'name': 'Test User',
            'avatar_url': 'https://github.com/testuser.png',
            'email': 'test@example.com',
          },
        };

        when(mockClient.get('/v1/account/profile'))
            .thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await githubApi.getAccountProfile();

        expect(result.id, 'user-123');
        expect(result.timestamp, 1640995200);
        expect(result.github, isNotNull);
        expect(result.github!.id, 456);
        expect(result.github!.login, 'testuser');
        expect(result.github!.name, 'Test User');
        expect(result.github!.avatarUrl, contains('testuser.png'));
        expect(result.github!.email, 'test@example.com');
      });

      test('successfully gets account profile without GitHub', () async {
        final mockResponse = {
          'id': 'user-123',
          'timestamp': 1640995200,
          'github': null,
        };

        when(mockClient.get('/v1/account/profile'))
            .thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await githubApi.getAccountProfile();

        expect(result.id, 'user-123');
        expect(result.github, isNull);
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.get('/v1/account/profile'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 401,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.getAccountProfile(),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message',
                  contains('Failed to get account profile'))),
        );
      });

      test('throws exception on invalid response data', () async {
        when(mockClient.get('/v1/account/profile'))
            .thenAnswer((_) async => Response(
          data: {'invalid': 'data'},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.getAccountProfile(),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to parse account profile'))),
        );
      });
    });

    group('disconnectGitHub', () {
      test('successfully disconnects GitHub', () async {
        when(mockClient.delete('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await githubApi.disconnectGitHub();

        verify(mockClient.delete('/v1/connect/github')).called(1);
      });

      test('throws exception when GitHub not connected (404)', () async {
        when(mockClient.delete('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: {'error': 'GitHub account not connected'},
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.disconnectGitHub(),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message',
                  contains('GitHub account not connected'))),
        );
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.delete('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: {},
          statusCode: 500,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.disconnectGitHub(),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message',
                  contains('Failed to disconnect GitHub'))),
        );
      });

      test('throws exception when success is false', () async {
        when(mockClient.delete('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: {'success': false},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.disconnectGitHub(),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to disconnect GitHub account'))),
        );
      });

      test('throws exception when response data is null', () async {
        when(mockClient.delete('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: null,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.disconnectGitHub(),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to disconnect GitHub account'))),
        );
      });
    });

    group('registerOAuthToken', () {
      test('successfully registers OAuth token', () async {
        when(mockClient.post(
          '/v1/connect/github/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await githubApi.registerOAuthToken('github-oauth-token');

        verify(mockClient.post(
          '/v1/connect/github/register',
          data: {'token': 'github-oauth-token'},
        )).called(1);
      });

      test('throws exception when token is empty', () async {
        expect(
          () => githubApi.registerOAuthToken(''),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.message, 'message',
                  contains('OAuth token cannot be empty'))),
        );
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.post(
          '/v1/connect/github/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'error': 'Invalid OAuth token'},
          statusCode: 401,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.registerOAuthToken('invalid-token'),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message',
                  contains('Failed to register GitHub token'))),
        );
      });

      test('throws exception when success is false', () async {
        when(mockClient.post(
          '/v1/connect/github/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': false},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.registerOAuthToken('test-token'),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to register GitHub token'))),
        );
      });

      test('throws exception when response data is null', () async {
        when(mockClient.post(
          '/v1/connect/github/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: null,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(
          () => githubApi.registerOAuthToken('test-token'),
          throwsA(isA<GitHubApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to register GitHub token'))),
        );
      });
    });

    group('isGitHubConnected', () {
      test('returns true when GitHub is connected', () async {
        when(mockClient.get('/v1/account/profile'))
            .thenAnswer((_) async => Response(
          data: {
            'id': 'user-123',
            'timestamp': 1640995200,
            'github': {
              'id': 456,
              'login': 'testuser',
              'name': 'Test User',
              'avatar_url': 'https://github.com/testuser.png',
            },
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await githubApi.isGitHubConnected();

        expect(result, isTrue);
      });

      test('returns false when GitHub is not connected', () async {
        when(mockClient.get('/v1/account/profile'))
            .thenAnswer((_) async => Response(
          data: {
            'id': 'user-123',
            'timestamp': 1640995200,
            'github': null,
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await githubApi.isGitHubConnected();

        expect(result, isFalse);
      });

      test('returns false on error', () async {
        when(mockClient.get('/v1/account/profile'))
            .thenThrow(Exception('Network error'));

        final result = await githubApi.isGitHubConnected();

        expect(result, isFalse);
      });

      test('returns false when profile is missing github field', () async {
        when(mockClient.get('/v1/account/profile'))
            .thenAnswer((_) async => Response(
          data: {
            'id': 'user-123',
            'timestamp': 1640995200,
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final result = await githubApi.isGitHubConnected();

        expect(result, isFalse);
      });
    });

    group('GitHubOAuthParams', () {
      test('creates from JSON correctly', () {
        const json = {'url': 'https://github.com/login/oauth/authorize'};
        final params = GitHubOAuthParams.fromJson(json);

        expect(params.url, 'https://github.com/login/oauth/authorize');
      });

      test('converts to JSON correctly', () {
        const params = GitHubOAuthParams(
          url: 'https://github.com/login/oauth/authorize',
        );
        final json = params.toJson();

        expect(json, {'url': 'https://github.com/login/oauth/authorize'});
      });

      test('toString provides useful info', () {
        const params = GitHubOAuthParams(
          url: 'https://github.com/login/oauth/authorize',
        );

        expect(
          params.toString(),
          'GitHubOAuthParams(url: https://github.com/login/oauth/authorize)',
        );
      });
    });

    group('AccountProfile', () {
      test('creates from JSON with GitHub profile', () {
        final json = {
          'id': 'user-123',
          'timestamp': 1640995200,
          'github': {
            'id': 456,
            'login': 'testuser',
            'name': 'Test User',
            'avatar_url': 'https://github.com/testuser.png',
            'email': 'test@example.com',
          },
        };

        final profile = AccountProfile.fromJson(json);

        expect(profile.id, 'user-123');
        expect(profile.timestamp, 1640995200);
        expect(profile.github, isNotNull);
        expect(profile.github!.login, 'testuser');
      });

      test('creates from JSON without GitHub profile', () {
        final json = {
          'id': 'user-123',
          'timestamp': 1640995200,
          'github': null,
        };

        final profile = AccountProfile.fromJson(json);

        expect(profile.id, 'user-123');
        expect(profile.github, isNull);
      });

      test('converts to JSON correctly', () {
        final profile = AccountProfile(
          id: 'user-123',
          timestamp: 1640995200,
          github: const GitHubProfileInfo(
            id: 456,
            login: 'testuser',
            name: 'Test User',
            avatarUrl: 'https://github.com/testuser.png',
          ),
        );

        final json = profile.toJson();

        expect(json['id'], 'user-123');
        expect(json['timestamp'], 1640995200);
        expect(json['github'], isNotNull);
        expect(json['github']['login'], 'testuser');
      });

      test('toString provides useful info', () {
        final profile = AccountProfile(
          id: 'user-123',
          timestamp: 1640995200,
          github: const GitHubProfileInfo(
            id: 456,
            login: 'testuser',
            name: 'Test User',
            avatarUrl: 'https://github.com/testuser.png',
          ),
        );

        expect(
          profile.toString(),
          'AccountProfile(id: user-123, timestamp: 1640995200, '
              'github: GitHubProfileInfo(id: 456, login: testuser, name: Test User))',
        );
      });
    });

    group('GitHubProfileInfo', () {
      test('creates from JSON correctly', () {
        final json = {
          'id': 456,
          'login': 'testuser',
          'name': 'Test User',
          'avatar_url': 'https://github.com/testuser.png',
          'email': 'test@example.com',
        };

        final profile = GitHubProfileInfo.fromJson(json);

        expect(profile.id, 456);
        expect(profile.login, 'testuser');
        expect(profile.name, 'Test User');
        expect(profile.avatarUrl, 'https://github.com/testuser.png');
        expect(profile.email, 'test@example.com');
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 456,
          'login': 'testuser',
          'name': 'Test User',
          'avatar_url': 'https://github.com/testuser.png',
        };

        final profile = GitHubProfileInfo.fromJson(json);

        expect(profile.id, 456);
        expect(profile.email, isNull);
      });

      test('converts to JSON correctly', () {
        const profile = GitHubProfileInfo(
          id: 456,
          login: 'testuser',
          name: 'Test User',
          avatarUrl: 'https://github.com/testuser.png',
          email: 'test@example.com',
        );

        final json = profile.toJson();

        expect(json['id'], 456);
        expect(json['login'], 'testuser');
        expect(json['name'], 'Test User');
        expect(json['avatar_url'], 'https://github.com/testuser.png');
        expect(json['email'], 'test@example.com');
      });

      test('toString provides useful info', () {
        const profile = GitHubProfileInfo(
          id: 456,
          login: 'testuser',
          name: 'Test User',
          avatarUrl: 'https://github.com/testuser.png',
        );

        expect(
          profile.toString(),
          'GitHubProfileInfo(id: 456, login: testuser, name: Test User)',
        );
      });
    });

    group('GitHubApiException', () {
      test('has correct properties', () {
        final exception = const GitHubApiException(
          'Test error',
          statusCode: 500,
        );

        expect(exception.message, 'Test error');
        expect(exception.statusCode, 500);
        expect(exception.toString(), 'GitHubApiException: Test error');
      });

      test('implements equality', () {
        const exception1 = GitHubApiException('Error', statusCode: 500);
        const exception2 = GitHubApiException('Error', statusCode: 500);
        const exception3 = GitHubApiException('Different', statusCode: 500);

        expect(exception1, equals(exception2));
        expect(exception1, isNot(equals(exception3)));
        expect(exception1.hashCode, equals(exception2.hashCode));
      });

      test('can be created without status code', () {
        const exception = GitHubApiException('Test error');

        expect(exception.message, 'Test error');
        expect(exception.statusCode, isNull);
      });
    });

    group('Integration scenarios', () {
      test('full GitHub connection flow', () async {
        // Get OAuth params
        when(mockClient.get('/v1/connect/github/params'))
            .thenAnswer((_) async => Response(
          data: {'url': 'https://github.com/oauth/authorize'},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final oauthParams = await githubApi.getOAuthParams();
        expect(oauthParams.url, contains('github.com'));

        // Register OAuth token after user completes flow
        when(mockClient.post(
          '/v1/connect/github/register',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await githubApi.registerOAuthToken('oauth-token-123');

        // Check profile
        when(mockClient.get('/v1/account/profile'))
            .thenAnswer((_) async => Response(
          data: {
            'id': 'user-123',
            'timestamp': 1640995200,
            'github': {
              'id': 456,
              'login': 'testuser',
              'name': 'Test User',
              'avatar_url': 'https://github.com/testuser.png',
            },
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final isConnected = await githubApi.isGitHubConnected();
        expect(isConnected, isTrue);
      });

      test('GitHub disconnection flow', () async {
        // Check connected
        when(mockClient.get('/v1/account/profile'))
            .thenAnswer((_) async => Response(
          data: {
            'id': 'user-123',
            'timestamp': 1640995200,
            'github': {
              'id': 456,
              'login': 'testuser',
              'name': 'Test User',
              'avatar_url': 'https://github.com/testuser.png',
            },
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(await githubApi.isGitHubConnected(), isTrue);

        // Disconnect
        when(mockClient.delete('/v1/connect/github'))
            .thenAnswer((_) async => Response(
          data: {'success': true},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await githubApi.disconnectGitHub();

        // Verify disconnected
        when(mockClient.get('/v1/account/profile'))
            .thenAnswer((_) async => Response(
          data: {
            'id': 'user-123',
            'timestamp': 1640995200,
            'github': null,
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        expect(await githubApi.isGitHubConnected(), isFalse);
      });
    });
  });
}
