import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/models/settings.dart';

void main() {
  AIBackendProfile profileWithEnv(
    List<EnvironmentVariable> envVars, {
    String? model,
  }) => AIBackendProfile(
    id: 'custom_1',
    name: 'opencode-proxy',
    environmentVariables: envVars,
    defaultModelMode: model,
    isBuiltIn: false,
    compatibility: const ProfileCompatibility(
      claude: true,
      codex: false,
      gemini: false,
    ),
  );

  String valueFor(AIBackendProfile p, String name) =>
      p.environmentVariables.firstWhere((e) => e.name == name).value;

  group('normalizeModelSelectionEnv', () {
    test('backfills all selection knobs from ANTHROPIC_MODEL', () {
      final profile = normalizeModelSelectionEnv(
        profileWithEnv([
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://opencode-proxy.beago-bass.ts.net',
          ),
          EnvironmentVariable(name: 'ANTHROPIC_AUTH_TOKEN', value: 'token'),
          EnvironmentVariable(
            name: 'ANTHROPIC_MODEL',
            value: 'x-preview-f-free',
          ),
        ]),
      );

      expect(valueFor(profile, 'ANTHROPIC_MODEL'), 'x-preview-f-free');
      expect(
        valueFor(profile, 'ANTHROPIC_SMALL_FAST_MODEL'),
        'x-preview-f-free',
      );
      expect(
        valueFor(profile, 'ANTHROPIC_DEFAULT_OPUS_MODEL'),
        'x-preview-f-free',
      );
      expect(
        valueFor(profile, 'ANTHROPIC_DEFAULT_SONNET_MODEL'),
        'x-preview-f-free',
      );
      expect(
        valueFor(profile, 'ANTHROPIC_DEFAULT_HAIKU_MODEL'),
        'x-preview-f-free',
      );
      expect(
        valueFor(profile, 'CLAUDE_CODE_SUBAGENT_MODEL'),
        'x-preview-f-free',
      );
    });

    test('keeps an existing fast model for haiku-class slots', () {
      final profile = normalizeModelSelectionEnv(
        profileWithEnv([
          EnvironmentVariable(name: 'ANTHROPIC_MODEL', value: 'glm-5.1'),
          EnvironmentVariable(
            name: 'ANTHROPIC_SMALL_FAST_MODEL',
            value: 'GLM-4.7',
          ),
        ]),
      );

      expect(valueFor(profile, 'ANTHROPIC_DEFAULT_OPUS_MODEL'), 'glm-5.1');
      expect(valueFor(profile, 'ANTHROPIC_DEFAULT_SONNET_MODEL'), 'GLM-4.7');
      expect(valueFor(profile, 'ANTHROPIC_DEFAULT_HAIKU_MODEL'), 'GLM-4.7');
      expect(valueFor(profile, 'CLAUDE_CODE_SUBAGENT_MODEL'), 'glm-5.1');
    });

    test('leaves fully-mapped profiles untouched', () {
      final before = profileWithEnv([
        EnvironmentVariable(name: 'ANTHROPIC_MODEL', value: 'm'),
        EnvironmentVariable(name: 'ANTHROPIC_SMALL_FAST_MODEL', value: 'f'),
        EnvironmentVariable(name: 'ANTHROPIC_DEFAULT_OPUS_MODEL', value: 'm'),
        EnvironmentVariable(name: 'ANTHROPIC_DEFAULT_SONNET_MODEL', value: 'f'),
        EnvironmentVariable(name: 'ANTHROPIC_DEFAULT_HAIKU_MODEL', value: 'f'),
        EnvironmentVariable(name: 'CLAUDE_CODE_SUBAGENT_MODEL', value: 'm'),
      ]);

      final after = normalizeModelSelectionEnv(before);
      expect(identical(after, before), isTrue);
    });

    test('skips non-Claude profiles', () {
      final before = AIBackendProfile(
        id: 'codex_1',
        name: 'OpenAI',
        environmentVariables: [
          EnvironmentVariable(name: 'OPENAI_MODEL', value: 'gpt-5-codex'),
        ],
        defaultModelMode: 'gpt-5-codex',
        isBuiltIn: false,
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
        ),
      );

      expect(identical(normalizeModelSelectionEnv(before), before), isTrue);
    });

    test('skips profiles without a selected model', () {
      final before = profileWithEnv([
        EnvironmentVariable(
          name: 'ANTHROPIC_BASE_URL',
          value: 'https://api.anthropic.com',
        ),
      ]);

      // No model anywhere -> nothing to map; official API serves real
      // Claude names so leaving it alone is correct.
      final after = normalizeModelSelectionEnv(before);
      expect(
        after.environmentVariables.any(
          (e) => e.name == 'CLAUDE_CODE_SUBAGENT_MODEL',
        ),
        isFalse,
      );
    });
  });
}
