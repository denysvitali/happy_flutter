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
    group('when lastUsedModelMode is a full model name', () {
      test('returns null for full model names (use env vars instead)', () {
        sync.testSettingsSnapshot = Settings()
          ..lastUsedModelMode = 'claude-3-opus';

        final result = sync.testGetModelOverride();

        expect(result, isNull);
      });

      test(
        'returns null for full model name even when profile is provided',
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

          expect(result, isNull);
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
        'returns null even when profile has openaiConfig.model',
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

          // Model is passed via ANTHROPIC_MODEL env var, not --model
          expect(result, isNull);
        },
      );

      test(
        'returns null even when profile has anthropicConfig.model',
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

          expect(result, isNull);
        },
      );

      test(
        'returns null even when profile has defaultModelMode',
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

          expect(result, isNull);
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
        'returns null even when profile has openaiConfig.model',
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

          // Model is passed via OPENAI_MODEL env var, not --model
          expect(result, isNull);
        },
      );

      test(
        'returns null even when profile has anthropicConfig.model',
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

          expect(result, isNull);
        },
      );

      test(
        'returns null even when profile has defaultModelMode',
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

          expect(result, isNull);
        },
      );

      test(
        'returns null when profile defaultModelMode is "default"',
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
      // When lastUsedModelMode is 'default', --model is not passed at all.
      // Profile models are set via env vars only.
      test(
        'returns null regardless of profile model configs '
        'when lastUsedModelMode is "default"',
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

          expect(result, isNull);
        },
      );

      test(
        'returns null when lastUsedModelMode is "default" '
        'and profile has no model configs',
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

          expect(result, isNull);
        },
      );
    });

    group("when lastUsedModelMode is 'sonnet' or 'opus'", () {
      test("'sonnet' returns 'sonnet' (valid CLI model identifier)", () {
        sync.testSettingsSnapshot = Settings()
          ..lastUsedModelMode = 'sonnet';

        final result = sync.testGetModelOverride();

        expect(result, 'sonnet');
      });

      test("'opus' returns 'opus' (valid CLI model identifier)", () {
        sync.testSettingsSnapshot = Settings()
          ..lastUsedModelMode = 'opus';

        final result = sync.testGetModelOverride();

        expect(result, 'opus');
      });

      test(
        "'sonnet' returns null when profile has anthropicConfig.model "
        "(use env vars instead)",
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'sonnet';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Anthropic Profile',
            anthropicConfig: AnthropicConfig(
              model: 'claude-3-sonnet',
            ),
          );

          final result = sync.testGetModelOverride(profile: profile);

          // Custom profile with anthropicConfig.model - model comes from
          // ANTHROPIC_MODEL env var, not --model
          expect(result, isNull);
        },
      );

      test(
        "'opus' returns null when profile has anthropicConfig.model "
        "(use env vars instead)",
        () {
          sync.testSettingsSnapshot = Settings()
            ..lastUsedModelMode = 'opus';

          final profile = AIBackendProfile(
            id: 'p1',
            name: 'Anthropic Profile',
            anthropicConfig: AnthropicConfig(
              model: 'claude-opus-4-6',
            ),
          );

          final result = sync.testGetModelOverride(profile: profile);

          // Custom profile with anthropicConfig.model - model comes from
          // ANTHROPIC_MODEL env var, not --model
          expect(result, isNull);
        },
      );
    });

    group('edge cases', () {
      test(
        'full model name like claude-3-5-sonnet returns null '
        '(use env vars instead)',
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

          // Full model names should come from ANTHROPIC_MODEL env var, not --model
          expect(result, isNull);
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
