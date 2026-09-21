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
      expect(profile.compatibility.agy, isFalse);
      expect(profile.compatibility.supportsAgent('codex'), isTrue);
      expect(profile.compatibility.supportsAgent('claude'), isFalse);
    });

    test('is listed for display alongside the other built-ins', () {
      expect(builtInProfileIds, contains('qwen-token-plan-codex'));
      expect(
        builtInProfiles.map((p) => p.id),
        contains('qwen-token-plan-codex'),
      );
      expect(resolveProfile('qwen-token-plan-codex', const []), isNotNull);
    });

    test('emits the OpenAI-compatible spawn env the daemon translates into '
        'Codex provider flags', () {
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
    });

    test('exposes the stable Token Plan codex model slugs', () {
      expect(qwenTokenPlanCodexModels, [
        'qwen3.8-max-preview',
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

  group('custom-codex-proxy built-in profile', () {
    final profile = getBuiltInProfile('custom-codex-proxy');

    test('is a codex-only built-in listed for display', () {
      expect(profile, isNotNull);
      expect(profile!.isBuiltIn, isTrue);
      expect(profile.compatibility.codex, isTrue);
      expect(profile.compatibility.claude, isFalse);
      expect(profile.compatibility.agy, isFalse);
      expect(builtInProfileIds, contains('custom-codex-proxy'));
      expect(resolveProfile('custom-codex-proxy', const []), isNotNull);
    });

    test('carries the optional Codex provider-definition overrides the daemon '
        'translates into -c model_providers flags', () {
      final env = {
        for (final e in profile!.environmentVariables) e.name: e.value,
      };

      // Base URL is required but has no default — an unconfigured profile
      // must not route codex anywhere.
      expect(_envDefault(env['OPENAI_BASE_URL']!), '');

      // env_key override defaults to OPENAI_API_KEY; wire_api defaults to
      // chat (OpenAI-compatible gateways); name override stays empty so
      // the daemon keeps its own default display name.
      expect(
        _envDefault(env['HAPPY_CODEX_PROVIDER_ENV_KEY']!),
        'OPENAI_API_KEY',
      );
      expect(_envDefault(env['HAPPY_CODEX_PROVIDER_WIRE_API']!), 'chat');
      expect(_envDefault(env['HAPPY_CODEX_PROVIDER_NAME']!), '');
    });

    test('catalog and wizard entries mirror the built-in profile', () {
      final option = profileSetupOption('custom-codex-proxy');
      expect(option, isNotNull);

      final template = profileSetupTemplate('custom-codex-proxy');
      expect(template, isNotNull);
      expect(template!.compatibility.codex, isTrue);
      expect(template.compatibility.claude, isFalse);
      final templateEnv = {
        for (final e in template.environmentVariables) e.name: e.value,
      };
      // The wizard template seeds editable plain values; the overrides are
      // present so users can flip them in the editor.
      expect(templateEnv.containsKey('OPENAI_BASE_URL'), isTrue);
      expect(templateEnv['HAPPY_CODEX_PROVIDER_ENV_KEY'], 'OPENAI_API_KEY');
      expect(templateEnv['HAPPY_CODEX_PROVIDER_WIRE_API'], 'chat');
    });
  });

  group('profile setup catalog mirrors all 11 built-in presets', () {
    test('covers every built-in id with an option and a template', () {
      expect(builtInProfileIds.length, 11);
      expect(builtInProfiles.length, 11);
      for (final id in builtInProfileIds) {
        expect(profileSetupOption(id), isNotNull, reason: id);
        expect(profileSetupTemplate(id), isNotNull, reason: id);
      }
    });

    test('templates match built-in env keys, defaults and compatibility', () {
      for (final id in builtInProfileIds) {
        final builtIn = getBuiltInProfile(id)!;
        final template = profileSetupTemplate(id)!;
        final where = 'preset $id';

        expect(
          template.compatibility.claude,
          builtIn.compatibility.claude,
          reason: where,
        );
        expect(
          template.compatibility.codex,
          builtIn.compatibility.codex,
          reason: where,
        );
        expect(
          template.compatibility.agy,
          builtIn.compatibility.agy,
          reason: where,
        );
        expect(
          template.compatibility.pi,
          builtIn.compatibility.pi,
          reason: where,
        );
        expect(
          template.defaultModelMode,
          builtIn.defaultModelMode,
          reason: where,
        );

        final builtInEnv = {
          for (final e in builtIn.environmentVariables) e.name: e.value,
        };
        final templateEnv = {
          for (final e in template.environmentVariables) e.name: e.value,
        };
        for (final entry in builtInEnv.entries) {
          expect(
            templateEnv.containsKey(entry.key),
            isTrue,
            reason: '${entry.key} missing from $where template',
          );
          expect(
            templateEnv[entry.key],
            _envDefault(entry.value),
            reason: '${entry.key} default mismatch in $where template',
          );
        }
      }
    });

    test(
      'isBuiltInPresetId identifies presets without gating deletability',
      () {
        for (final id in builtInProfileIds) {
          expect(isBuiltInPresetId(id), isTrue, reason: id);
        }
        expect(isBuiltInPresetId('custom_1'), isFalse);
        expect(isBuiltInPresetId(''), isFalse);
      },
    );
  });
}
