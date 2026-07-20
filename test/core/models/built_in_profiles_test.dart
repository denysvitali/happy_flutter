import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/features/settings/profile_setup_catalog.dart';

/// Extract the default from a `${VAR:-default}` daemon-expansion env
/// value; returns the raw value when it is not expansion syntax.
String _envDefault(String value) {
  final match = RegExp(r'^\$\{[^:}]+:-(.*)\}$').firstMatch(value);
  return match?.group(1) ?? value;
}

void main() {
  group('qwen-token-plan-codex built-in profile', () {
    final profile = getBuiltInProfile('qwen-token-plan-codex');

    test('is a codex-only built-in with the qwen3.7-max default', () {
      expect(profile, isNotNull);
      expect(profile!.isBuiltIn, isTrue);
      expect(profile.defaultModelMode, 'qwen3.7-max');
      expect(profile.compatibility.codex, isTrue);
      expect(profile.compatibility.claude, isFalse);
      expect(profile.compatibility.gemini, isFalse);
      expect(profile.compatibility.supportsAgent('codex'), isTrue);
      expect(profile.compatibility.supportsAgent('claude'), isFalse);
    });

    test('is listed for display alongside the other built-ins', () {
      expect(builtInProfileIds, contains('qwen-token-plan-codex'));
      expect(
        builtInProfiles.map((p) => p.id),
        contains('qwen-token-plan-codex'),
      );
      expect(
        resolveProfile('qwen-token-plan-codex', const []),
        isNotNull,
      );
    });

    test(
      'emits the OpenAI-compatible spawn env the daemon translates into '
      'Codex provider flags',
      () {
        final env = {
          for (final e in profile!.environmentVariables) e.name: e.value,
        };

        // OPENAI_BASE_URL: Singapore Token Plan OpenAI-compatible endpoint.
        expect(
          _envDefault(env['OPENAI_BASE_URL']!),
          'https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1',
        );

        // OPENAI_MODEL defaults to qwen3.7-max.
        expect(_envDefault(env['OPENAI_MODEL']!), 'qwen3.7-max');

        // The stored Qwen key becomes OPENAI_API_KEY: the value uses the
        // same `${QWEN_API_KEY:-}` daemon expansion as the Claude
        // 'Qwen (Token Plan)' profile's ANTHROPIC_AUTH_TOKEN, so one
        // daemon-side QWEN_API_KEY export feeds both agents.
        expect(env['OPENAI_API_KEY'], r'${QWEN_API_KEY:-}');
        final claudeQwen = getBuiltInProfile('qwen')!;
        expect(
          claudeQwen.environmentVariables
              .firstWhere((e) => e.name == 'ANTHROPIC_AUTH_TOKEN')
              .value,
          r'${QWEN_API_KEY:-}',
        );
      },
    );

    test('exposes the five stable Token Plan codex model slugs', () {
      expect(qwenTokenPlanCodexModels, [
        'qwen3.7-max',
        'qwen3.7-plus',
        'qwen3.6-flash',
        'glm-5.2',
        'deepseek-v4-pro',
      ]);
      for (final slug in qwenTokenPlanCodexModels) {
        expect(isTokenPlanCodexModelSlug(slug), isTrue);
      }
      expect(isTokenPlanCodexModelSlug('gpt-5-codex'), isFalse);
    });

    test('catalog and wizard entries mirror the built-in profile', () {
      final option = profileSetupOption('qwen-token-plan-codex');
      expect(option, isNotNull);
      expect(option!.apiKeyLabel, 'Qwen API Key');

      final template = profileSetupTemplate('qwen-token-plan-codex');
      expect(template, isNotNull);
      expect(template!.compatibility.codex, isTrue);
      expect(template.compatibility.claude, isFalse);
      final templateEnv = {
        for (final e in template.environmentVariables) e.name: e.value,
      };
      expect(
        templateEnv['OPENAI_BASE_URL'],
        'https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1',
      );
      expect(templateEnv['OPENAI_MODEL'], 'qwen3.7-max');
      expect(templateEnv.containsKey('OPENAI_API_KEY'), isTrue);
    });
  });
}
