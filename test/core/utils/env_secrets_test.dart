import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/utils/env_secrets.dart';

void main() {
  group('isSecretEnvName', () {
    group('secrets', () {
      const secretNames = [
        'ANTHROPIC_AUTH_TOKEN',
        'ANTHROPIC_API_KEY',
        'OPENAI_API_KEY',
        'AWS_SECRET_ACCESS_KEY',
        'GITHUB_TOKEN',
        'MY_PASSWORD',
        'DB_PASSWD',
        'SERVICE_CREDENTIALS',
        'OAUTH_CLIENT_SECRET',
        'JWT_SIGNING_KEY',
        'api_key',
        'anthropic_auth_token',
        'APIKEY',
        'ACCESS_TOKEN',
        'X-API-KEY',
        'PRIVATE_KEY',
        'JWT_SIGNING_KEY',
        'SESSION_TOKEN',
      ];

      for (final name in secretNames) {
        test('$name is secret', () {
          expect(isSecretEnvName(name), isTrue);
        });
      }
    });

    group('non-secrets', () {
      const plainNames = [
        'ANTHROPIC_BASE_URL',
        'ANTHROPIC_MODEL',
        'ANTHROPIC_DEFAULT_OPUS_MODEL',
        'ANTHROPIC_SMALL_FAST_MODEL',
        'API_TIMEOUT_MS',
        'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC',
        'AZURE_OPENAI_API_VERSION',
        'AZURE_OPENAI_DEPLOYMENT_NAME',
        'OPENAI_MODEL',
        'OPENAI_SMALL_FAST_MODEL',
        'CLAUDE_CODE_SUBAGENT_MODEL',
        'MONKEY',
        'TURKEY',
        'AUTH_URL',
        'MAX_TOKEN_COUNT',
        'KEYSTONE_URL',
        '',
      ];

      for (final name in plainNames) {
        test('$name is not secret', () {
          expect(isSecretEnvName(name), isFalse);
        });
      }
    });
  });

  group('suggestProfileName', () {
    test('prefers well-known model variables', () {
      final name = suggestProfileName([
        EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: 'sk-secret'),
        EnvironmentVariable(name: 'ANTHROPIC_MODEL', value: 'deepseek-chat'),
      ]);
      expect(name, 'deepseek-chat');
    });

    test('never derives the name from a secret value', () {
      final name = suggestProfileName([
        EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: 'sk-secret'),
      ]);
      expect(name, isNull);
    });

    test('falls back to the first non-secret variable', () {
      final name = suggestProfileName([
        EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: 'sk-secret'),
        EnvironmentVariable(name: 'MY_BASE_URL', value: 'https://x/y'),
      ]);
      expect(name, 'y');
    });

    test('uses the last path segment of a model value', () {
      final name = suggestProfileName([
        EnvironmentVariable(
          name: 'OPENAI_MODEL',
          value: 'anthropic/claude-opus-4.6',
        ),
      ]);
      expect(name, 'claude-opus-4.6');
    });

    test('returns null when values are empty', () {
      final name = suggestProfileName([
        EnvironmentVariable(name: 'ANTHROPIC_MODEL', value: ''),
        EnvironmentVariable(name: 'MY_BASE_URL', value: ''),
      ]);
      expect(name, isNull);
    });
  });
}
