import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  late Sync sync;

  setUp(() {
    sync = createTestSync();
  });

  group('_getModelOverride', () {
    group('when lastUsedModelMode is a specific model', () {
      test('returns the model string directly', () {
        sync.testSettingsSnapshot = Settings()
          ..lastUsedModelMode = 'claude-3-opus';

        final result = sync.testGetModelOverride();

        expect(result, 'claude-3-opus');
      });

      test(
        'returns model string even when profile is provided',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'claude-3-opus';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Test',
            openaiConfig: OpenAIConfig(model: 'gpt-4'),
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'claude-3-opus');
        },
      );
    });

    group('when lastUsedModelMode is null', () {
      test('returns null with no profile', () {
        sync.testSettingsSnapshot = Settings()
          ..lastUsedModelMode = null;

        final result = sync.testGetModelOverride();

        expect(result, isNull);
      });

      test(
        'returns openaiConfig.model when profile has it',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = null;

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'OpenAI Profile',
            openaiConfig: OpenAIConfig(model: 'gpt-4o'),
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'gpt-4o');
        },
      );

      test(
        'returns anthropicConfig.model when profile has it',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = null;

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Anthropic Profile',
            anthropicConfig: AnthropicConfig(
              model: 'claude-3-sonnet',
            ),
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'claude-3-sonnet');
        },
      );

      test(
        'returns defaultModelMode when profile has it',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = null;

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Built-in Profile',
            defaultModelMode: 'sonnet',
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'sonnet');
        },
      );
    });

    group("when lastUsedModelMode is 'default'", () {
      test('returns null with no profile', () {
        sync.testSettingsSnapshot = Settings()
          ..lastUsedModelMode = 'default';

        final result = sync.testGetModelOverride();

        expect(result, isNull);
      });

      test(
        'returns openaiConfig.model from profile',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'default';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'OpenAI Profile',
            openaiConfig: OpenAIConfig(model: 'gpt-4'),
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'gpt-4');
        },
      );

      test(
        'returns anthropicConfig.model from profile',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'default';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Anthropic Profile',
            anthropicConfig: AnthropicConfig(
              model: 'claude-3',
            ),
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'claude-3');
        },
      );

      test(
        'returns defaultModelMode from profile',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'default';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Built-in Profile',
            defaultModelMode: 'sonnet',
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'sonnet');
        },
      );

      test(
        "returns null when profile defaultModelMode is 'default'",
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'default';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Built-in Profile',
            defaultModelMode: 'default',
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, isNull);
        },
      );

      test(
        'returns null when profile has no model configs',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'default';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Empty Profile',
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, isNull);
        },
      );
    });

    group('profile model priority', () {
      test(
        'openaiConfig takes priority over anthropicConfig',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'default';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Dual Config',
            openaiConfig: OpenAIConfig(model: 'gpt-4o'),
            anthropicConfig: AnthropicConfig(
              model: 'claude-3',
            ),
            defaultModelMode: 'sonnet',
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'gpt-4o');
        },
      );

      test(
        'anthropicConfig takes priority over '
        'defaultModelMode',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'default';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Anthropic + Default',
            anthropicConfig: AnthropicConfig(
              model: 'claude-3',
            ),
            defaultModelMode: 'sonnet',
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'claude-3');
        },
      );

      test(
        'falls through to defaultModelMode when '
        'openai and anthropic models are null',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'default';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Configs Without Models',
            openaiConfig: OpenAIConfig(
              baseUrl: 'https://api.example.com',
            ),
            anthropicConfig: AnthropicConfig(
              baseUrl: 'https://api.example.com',
            ),
            defaultModelMode: 'haiku',
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'haiku');
        },
      );

      test(
        'returns null when all profile model sources '
        'are null',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'default';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'No Models',
            openaiConfig: OpenAIConfig(
              baseUrl: 'https://api.example.com',
            ),
            anthropicConfig: AnthropicConfig(
              baseUrl: 'https://api.example.com',
            ),
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, isNull);
        },
      );
    });

    group('edge cases', () {
      test(
        'explicit model mode overrides even when profile '
        'has models',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'claude-3-5-sonnet';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Profile',
            openaiConfig: OpenAIConfig(model: 'gpt-4o'),
            anthropicConfig: AnthropicConfig(
              model: 'claude-3',
            ),
            defaultModelMode: 'haiku',
          );

          final result = sync.testGetModelOverride(
            profile: profile,
          );

          expect(result, 'claude-3-5-sonnet');
        },
      );

      test('fresh Settings returns null with no profile', () {
        sync.testSettingsSnapshot = Settings();

        final result = sync.testGetModelOverride();

        expect(result, isNull);
      });

      test(
        'null profile with null lastUsedModelMode '
        'returns null',
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = null;

          final result = sync.testGetModelOverride(
            profile: null,
          );

          expect(result, isNull);
        },
      );
    });
  });
}
