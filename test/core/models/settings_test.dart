import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/settings_update.dart';

void main() {
  group('Settings last-used profiles', () {
    test('serializes and restores hide tool calls preference', () {
      final settings = Settings()..hideToolCalls = true;

      final restored = Settings.fromJson(settings.toJson());

      expect(restored.hideToolCalls, isTrue);
    });

    test('scopes selected profiles by agent', () {
      final settings = Settings()
        ..lastUsedProfilesByAgent = {'codex': 'openai', 'claude': 'anthropic'};

      expect(settings.lastUsedProfileForAgent('codex'), 'openai');
      expect(settings.lastUsedProfileForAgent('claude'), 'anthropic');
      expect(settings.lastUsedProfileForAgent('agy'), isNull);
    });

    test('does not share a scoped Codex profile with Claude', () {
      final settings = Settings()
        ..lastUsedProfilesByAgent = {'codex': 'openai'};

      expect(settings.lastUsedProfileForAgent('codex'), 'openai');
      expect(settings.lastUsedProfileForAgent('claude'), isNull);
    });

    test('legacy lastUsedProfile only applies to the last-used agent', () {
      final settings = Settings()
        ..lastUsedAgent = 'codex'
        ..lastUsedProfile = 'openai';

      expect(settings.lastUsedProfileForAgent('codex'), 'openai');
      expect(settings.lastUsedProfileForAgent('claude'), isNull);
    });

    test('compatible legacy profile can be resolved for an agent', () {
      final settings = Settings()
        ..lastUsedAgent = 'codex'
        ..lastUsedProfile = 'minimax';

      expect(resolveSelectedProfileIdForAgent(settings, 'claude'), 'minimax');
      expect(resolveSelectedProfileIdForAgent(settings, 'codex'), isNull);
    });

    test('incompatible legacy profile is not resolved for an agent', () {
      final settings = Settings()
        ..lastUsedAgent = 'claude'
        ..lastUsedProfile = 'openai';

      expect(resolveSelectedProfileIdForAgent(settings, 'claude'), isNull);
      expect(resolveSelectedProfileIdForAgent(settings, 'codex'), 'openai');
    });

    test('serializes and restores scoped profile selections', () {
      final settings = Settings()
        ..lastUsedProfilesByAgent = {'claude': 'anthropic', 'codex': 'openai'};

      final restored = Settings.fromJson(settings.toJson());

      expect(restored.lastUsedProfileForAgent('claude'), 'anthropic');
      expect(restored.lastUsedProfileForAgent('codex'), 'openai');
    });

    test('migrates retired Gemini profile selections to AGY', () {
      final restored = Settings.fromJson({
        ...Settings().toJson(),
        'lastUsedAgent': 'gemini',
        'lastUsedProfilesByAgent': {'gemini': 'legacy-profile'},
      });

      expect(restored.lastUsedAgent, 'agy');
      expect(restored.lastUsedProfileForAgent('agy'), 'legacy-profile');
      expect(restored.lastUsedProfilesByAgent, {'agy': 'legacy-profile'});
    });

    test('prefers an existing AGY profile over retired Gemini data', () {
      final restored = Settings.fromJson({
        ...Settings().toJson(),
        'lastUsedProfilesByAgent': {
          'gemini': 'legacy-profile',
          'agy': 'current-profile',
        },
      });

      expect(restored.lastUsedProfileForAgent('agy'), 'current-profile');
      expect(restored.lastUsedProfilesByAgent, {'agy': 'current-profile'});
    });

    test('fallback decode preserves existing values for partial payloads', () {
      final existing = Settings()
        ..themeMode = 'dark'
        ..avatarStyle = 'gradient'
        ..agentInputEnterToSend = true
        ..ttsEnabled = true
        ..ttsEngine = 'system'
        ..usagePeriod = 'sevenDays'
        ..folders = ['Work'];

      final restored = Settings.fromJsonWithFallback({
        'themeMode': 'light',
        'avatarStyle': null,
        'folders': 'invalid',
      }, existing);

      expect(restored.themeMode, 'light');
      expect(restored.avatarStyle, 'gradient');
      expect(restored.agentInputEnterToSend, isTrue);
      expect(restored.ttsEnabled, isTrue);
      expect(restored.ttsEngine, 'system');
      expect(restored.usagePeriod, 'sevenDays');
      expect(restored.folders, ['Work']);
    });

    test('json storage roundtrip preserves all non-secret settings fields', () {
      final settings = Settings()
        ..avatarStyle = 'wave'
        ..agentInputEnterToSend = true
        ..ttsEnabled = true
        ..ttsEngine = 'system'
        ..voiceAssistantLanguage = 'en-US'
        ..usagePeriod = 'sevenDays'
        ..folders = ['Work', 'Personal'];

      final restored = Settings.fromJson(settings.toJson());

      expect(restored.avatarStyle, 'wave');
      expect(restored.agentInputEnterToSend, isTrue);
      expect(restored.ttsEnabled, isTrue);
      expect(restored.ttsEngine, 'system');
      expect(restored.voiceAssistantLanguage, 'en-US');
      expect(restored.usagePeriod, 'sevenDays');
      expect(restored.folders, ['Work', 'Personal']);
    });

    test('stale MiniMax-M3 defaultModelMode is normalized to MiniMax-M2.7', () {
      final stale = AIBackendProfile(
        id: 'minimax',
        name: 'MiniMax',
        defaultModelMode: 'MiniMax-M3',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_MODEL',
            value: r'${MINIMAX_MODEL:-MiniMax-M3}',
          ),
        ],
      );

      final normalized = normalizeBuiltInProfileDefaults(stale);

      expect(normalized.defaultModelMode, 'MiniMax-M2.7');
      expect(
        normalized.environmentVariables.single.value,
        r'${MINIMAX_MODEL:-MiniMax-M2.7}',
      );
    });

    test('user-edited MiniMax defaultModelMode is preserved', () {
      final edited = AIBackendProfile(
        id: 'minimax',
        name: 'MiniMax',
        defaultModelMode: 'MiniMax-custom',
      );

      final normalized = normalizeBuiltInProfileDefaults(edited);

      expect(normalized.defaultModelMode, 'MiniMax-custom');
    });
  });

  group('AIBackendProfile inferred default model', () {
    test('derives Codex model from OPENAI_MODEL env var', () {
      final profile = AIBackendProfile(
        id: 'kimi-codex',
        name: 'Kimi Codex',
        environmentVariables: [
          EnvironmentVariable(
            name: 'OPENAI_BASE_URL',
            value: 'https://api.kimi.com/coding/v1',
          ),
          EnvironmentVariable(name: 'OPENAI_MODEL', value: 'kimi-k2.7-code'),
        ],
      );

      expect(profile.inferredDefaultModelMode, 'kimi-k2.7-code');
    });

    test('prefers explicit defaultModelMode over env var', () {
      final profile = AIBackendProfile(
        id: 'custom-codex',
        name: 'Custom Codex',
        defaultModelMode: 'explicit-model',
        environmentVariables: [
          EnvironmentVariable(name: 'OPENAI_MODEL', value: 'env-model'),
        ],
      );

      expect(profile.inferredDefaultModelMode, 'explicit-model');
    });

    test('derives a default from a legacy profile model list', () {
      final profile = AIBackendProfile(
        id: 'legacy-claude-proxy',
        name: 'Legacy Claude Proxy',
        models: ['stealth/ox-alpha', 'stealth/ox-fast'],
      );

      expect(profile.inferredDefaultModelMode, 'stealth/ox-alpha');
    });
  });

  group('AIBackendProfile Codex providers', () {
    test('serializes and restores provider definitions', () {
      final profile = AIBackendProfile(
        id: 'custom-codex',
        name: 'Custom Codex',
        codexModelProvider: 'llm-proxy',
        codexProviders: [
          CodexProviderConfig(
            id: 'llm-proxy',
            name: 'LLM Proxy',
            baseUrl: 'http://llm-proxy.k2.k8s.best/v1',
            envKey: 'LLM_PROXY_API_KEY',
            wireApi: 'responses',
          ),
        ],
      );

      final restored = AIBackendProfile.fromJson(profile.toJson());

      expect(restored.codexModelProvider, 'llm-proxy');
      expect(restored.codexProviders, hasLength(1));
      expect(restored.codexProviders.single.id, 'llm-proxy');
      expect(restored.codexProviders.single.name, 'LLM Proxy');
      expect(
        restored.codexProviders.single.baseUrl,
        'http://llm-proxy.k2.k8s.best/v1',
      );
      expect(restored.codexProviders.single.envKey, 'LLM_PROXY_API_KEY');
      expect(restored.codexProviders.single.wireApi, 'responses');
    });
  });

  group('Pi agent profile bucketing', () {
    test('normalizeAgentKey routes pi to its own bucket', () {
      expect(normalizeAgentKey('pi'), 'pi');
      expect(normalizeAgentKey('claude'), 'claude');
      expect(normalizeAgentKey('codex'), 'codex');
      expect(normalizeAgentKey('agy'), 'agy');
      expect(normalizeAgentKey('gemini'), 'agy');
      expect(normalizeAgentKey('opencode'), 'opencode');
      expect(normalizeAgentKey('grok'), 'grok');
      expect(normalizeAgentKey('grok-build'), 'grok');
      expect(normalizeAgentKey(null), 'claude');
    });

    test('lastUsedProfileForAgent returns pi-scoped profile, not claude', () {
      final settings = Settings()
        ..lastUsedProfilesByAgent = {
          'pi': 'profile-x',
          'claude': 'profile-claude',
        };

      expect(settings.lastUsedProfileForAgent('pi'), 'profile-x');
      expect(settings.lastUsedProfileForAgent('claude'), 'profile-claude');
    });

    test('lastUsedProfileForAgent does not leak pi profile to claude', () {
      final settings = Settings()
        ..lastUsedProfilesByAgent = {'pi': 'profile-x'};

      expect(settings.lastUsedProfileForAgent('pi'), 'profile-x');
      expect(settings.lastUsedProfileForAgent('claude'), isNull);
    });

    test('lastUsedProfilesWithAgent buckets pi under the pi key', () {
      final settings = Settings();

      final next = settings.lastUsedProfilesWithAgent('pi', 'profile-y');

      expect(next['pi'], 'profile-y');
      expect(next.containsKey('claude'), isFalse);
    });

    test('lastUsedProfilesWithAgent writes survive a read-back via '
        'lastUsedProfileForAgent', () {
      final settings = Settings()
        ..lastUsedProfilesByAgent = Settings().lastUsedProfilesWithAgent(
          'pi',
          'profile-z',
        );

      expect(settings.lastUsedProfileForAgent('pi'), 'profile-z');
      expect(settings.lastUsedProfileForAgent('claude'), isNull);
    });

    test('lastUsedProfilesWithAgent removes pi entry when null is passed', () {
      final settings = Settings()
        ..lastUsedProfilesByAgent = {'pi': 'profile-y'};

      final next = settings.lastUsedProfilesWithAgent('pi', null);

      expect(next.containsKey('pi'), isFalse);
    });

    test(
      'resolveSelectedProfileIdForAgent prefers pi-only profile for pi agent',
      () {
        final piOnly = AIBackendProfile(
          id: 'pi-only',
          name: 'Pi only',
          compatibility: const ProfileCompatibility(
            claude: false,
            codex: false,
            agy: false,
            pi: true,
          ),
        );
        final claudeOnly = AIBackendProfile(
          id: 'claude-only',
          name: 'Claude only',
          compatibility: const ProfileCompatibility(
            claude: true,
            codex: false,
            agy: false,
            pi: false,
          ),
        );

        final settings = Settings()
          ..profiles = [piOnly, claudeOnly]
          ..lastUsedProfilesByAgent = {
            'pi': 'pi-only',
            'claude': 'claude-only',
          };

        expect(resolveSelectedProfileIdForAgent(settings, 'pi'), 'pi-only');
        expect(
          resolveSelectedProfileIdForAgent(settings, 'claude'),
          'claude-only',
        );
      },
    );

    test(
      'resolveSelectedProfileIdForAgent rejects claude-only profile for pi',
      () {
        final claudeOnly = AIBackendProfile(
          id: 'claude-only',
          name: 'Claude only',
          compatibility: const ProfileCompatibility(
            claude: true,
            codex: false,
            agy: false,
            pi: false,
          ),
        );

        // Simulate the pre-fix bug input: caller provides agent 'pi' but the
        // settings have a Claude profile selected. After the fix, the agent
        // bucket is correctly distinct, so a Claude-only profile must not
        // satisfy a pi agent request.
        final settings = Settings()
          ..profiles = [claudeOnly]
          ..lastUsedProfilesByAgent = {'pi': 'claude-only'};

        expect(resolveSelectedProfileIdForAgent(settings, 'pi'), isNull);
      },
    );
  });

  group('Settings.shallowClone', () {
    test('produces an equal-by-value copy of all primitive fields', () {
      final original = Settings()
        ..themeMode = 'dark'
        ..viewInline = true
        ..hideToolCalls = true
        ..avatarStyle = 'wave'
        ..ttsEnabled = true
        ..ttsUseOffline = false
        ..ttsEngine = 'system'
        ..ttsVoiceId = 'voice-a'
        ..sttModelId = 'parakeet-tdt-0.6b-v3-int8-v1'
        ..voiceAssistantLanguage = 'en-US'
        ..preferredLanguage = 'en'
        ..usagePeriod = 'sevenDays'
        ..lastUsedAgent = 'codex'
        ..lastUsedPermissionMode = 'plan'
        ..lastUsedModelMode = 'fast'
        ..lastUsedProfile = 'openai'
        ..folders = ['Work', 'Personal']
        ..favoriteDirectories = ['~/dev']
        ..favoriteMachines = ['m-1']
        ..lastUsedProfilesByAgent = {'codex': 'openai', 'claude': 'anth'};

      final clone = original.shallowClone();

      // Roundtrip JSON equality is the contract that the old
      // `Settings.fromJson(toJson())` clone provided. shallowClone
      // must preserve it.
      expect(clone.toJson(), equals(original.toJson()));
    });

    test('detaches collection fields so mutations do not leak back', () {
      final original = Settings()
        ..folders = ['Work']
        ..favoriteDirectories = ['~/dev']
        ..favoriteMachines = ['m-1']
        ..lastUsedProfilesByAgent = {'codex': 'openai'};

      final clone = original.shallowClone();

      // Mutating the clone's collections must not affect the original.
      clone.folders.add('Personal');
      clone.favoriteDirectories.add('~/projects');
      clone.favoriteMachines.add('m-2');
      clone.lastUsedProfilesByAgent['claude'] = 'anth';

      expect(original.folders, ['Work']);
      expect(original.favoriteDirectories, ['~/dev']);
      expect(original.favoriteMachines, ['m-1']);
      expect(original.lastUsedProfilesByAgent, {'codex': 'openai'});
    });

    test('mutating top-level fields on the clone leaves original intact', () {
      final original = Settings()
        ..themeMode = 'dark'
        ..ttsEnabled = true;

      final clone = original.shallowClone()
        ..themeMode = 'light'
        ..ttsEnabled = false;

      expect(original.themeMode, 'dark');
      expect(original.ttsEnabled, isTrue);
      expect(clone.themeMode, 'light');
      expect(clone.ttsEnabled, isFalse);
    });
  });

  group('Settings legacy/unknown key handling', () {
    test('Settings.fromJson silently drops persisted legacy keys '
        '(regression: HAPPY_FLUTTER-3C6 ttsUseOffline crash)', () {
      // Simulate a Settings JSON persisted by a previous build that
      // included the legacy ttsUseOffline key. Loading it on a build
      // where the key has been removed must not throw — unknown JSON
      // fields are simply not deserialized.
      final baseline = Settings().toJson();
      final legacyJson = <String, dynamic>{
        ...baseline,
        // Pretend ttsUseOffline is no longer part of the schema.
        'someRemovedLegacyKey': true,
      };

      expect(() => Settings.fromJson(legacyJson), returnsNormally);
    });

    test('SettingsUpdate.copyWithUpdated throws a typed exception for '
        'unknown keys so callers can drop them', () {
      final settings = Settings();

      expect(
        () => SettingsUpdate.copyWithUpdated(
          settings,
          'someRemovedLegacyKey',
          true,
        ),
        throwsA(
          isA<UnknownSettingsKeyException>().having(
            (e) => e.key,
            'key',
            'someRemovedLegacyKey',
          ),
        ),
      );
    });

    test('SettingsUpdate.isKnownKey reports current schema membership', () {
      // Pick any field that is unambiguously part of the schema today
      // and assert positive identification, then a synthetic missing
      // key for the negative case.
      expect(SettingsUpdate.isKnownKey('themeMode'), isTrue);
      expect(SettingsUpdate.isKnownKey('ttsEnabled'), isTrue);
      expect(SettingsUpdate.isKnownKey('ttsUseOffline'), isTrue);
      expect(SettingsUpdate.isKnownKey('sttModelId'), isTrue);
      expect(SettingsUpdate.isKnownKey('someRemovedLegacyKey'), isFalse);
    });
  });
}
