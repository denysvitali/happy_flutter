import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/features/chat/model_selection_resolver.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';
import 'package:happy_flutter/features/chat/widgets/permission_mode_selector.dart';

void main() {
  group('resolveSessionDisplayModel', () {
    test('hides absent or default session model', () {
      expect(resolveSessionDisplayModel(null), ChatModelMode.defaultModel);
      expect(resolveSessionDisplayModel(''), ChatModelMode.defaultModel);
      expect(
        resolveSessionDisplayModel(' default '),
        ChatModelMode.defaultModel,
      );
    });

    test('parses the model recorded on the session', () {
      expect(resolveSessionDisplayModel('sonnet'), ChatModelMode.sonnet);

      final codex = resolveSessionDisplayModel('gpt-5.5:medium');
      expect(codex.modeString, 'gpt-5.5:medium');
      expect(codex.label, 'GPT 5.5 Medium');
    });

    test('preserves raw provider-owned session models', () {
      final model = resolveSessionDisplayModel('GLM-5');

      expect(model.modeString, 'GLM-5');
      expect(model.label, 'GLM-5');
    });
  });

  group('resolveModelSelection', () {
    test('uses saved draft values before session and settings defaults', () {
      final profile = _profile(
        id: 'glm',
        defaultModelMode: 'GLM-5',
        defaultPermissionMode: 'plan',
      );

      final result = resolveModelSelection(
        savedPermissionMode: 'acceptEdits',
        savedModelMode: 'sonnet',
        savedProfileId: 'glm',
        sessionModelMode: 'opus',
        sessionPermissionMode: 'bypassPermissions',
        flavor: 'claude',
        settingsProfiles: [profile],
        builtInProfiles: const [],
        lastUsedModelMode: 'fable',
      );

      expect(result.resolvedPermissionMode, PermissionMode.acceptEdits);
      expect(result.shouldPersistPermissionMode, isFalse);
      expect(result.resolvedModelMode, ChatModelMode.sonnet);
      expect(result.resolvedRawModelString, 'sonnet');
      expect(result.resolvedProfile, same(profile));
      expect(result.hadGhostProfileReference, isFalse);
    });

    test('persists session permission when no draft exists', () {
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: null,
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: 'plan',
        flavor: 'claude',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedPermissionMode, PermissionMode.plan);
      expect(result.shouldPersistPermissionMode, isTrue);
    });

    test('flags ghost profile reference and filters available profiles', () {
      final codexOnly = _profile(
        id: 'codex',
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
          pi: false,
        ),
      );
      final claudeProfile = _profile(id: 'claude');

      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: null,
        savedProfileId: 'missing',
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: [codexOnly, claudeProfile],
        builtInProfiles: [claudeProfile],
        lastUsedModelMode: null,
      );

      expect(result.resolvedProfile, isNull);
      expect(result.hadGhostProfileReference, isTrue);
      expect(result.availableProfiles, [claudeProfile]);
    });

    test(
      'uses selected profile default model before global last used model',
      () {
        final profile = _profile(id: 'glm', defaultModelMode: 'GLM-5');

        final result = resolveModelSelection(
          savedPermissionMode: null,
          savedModelMode: null,
          savedProfileId: 'glm',
          sessionModelMode: null,
          sessionPermissionMode: null,
          flavor: 'claude',
          settingsProfiles: [profile],
          builtInProfiles: const [],
          lastUsedModelMode: 'opus',
        );

        expect(result.resolvedModelMode, ChatModelMode.defaultModel);
        expect(result.resolvedRawModelString, 'GLM-5');
        expect(result.resolvedProfile, same(profile));
      },
    );

    test('does not leak Claude last-used model into Codex session', () {
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: null,
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'codex',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: 'opus',
      );

      expect(result.resolvedModelMode, ChatModelMode.defaultModel);
      expect(result.resolvedRawModelString, isNull);
    });

    test('does not leak provider-owned last-used model into Codex default', () {
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: null,
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'codex',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: 'MiniMax-M3:high',
      );

      expect(result.resolvedModelMode, ChatModelMode.defaultModel);
      expect(result.resolvedRawModelString, isNull);
    });

    test('does not leak provider-owned saved model into Codex default', () {
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'MiniMax-M3',
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'codex',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedModelMode, ChatModelMode.defaultModel);
      expect(result.resolvedRawModelString, 'default');
    });

    test('does not show provider-owned saved Codex-style model after drop', () {
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'MiniMax-M3:high',
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'codex',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedModelMode, ChatModelMode.defaultModel);
      expect(result.resolvedRawModelString, 'default');
    });

    test('keeps Codex last-used model for Codex session', () {
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: null,
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'codex',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: 'gpt-5.5:medium',
      );

      expect(result.resolvedModelMode.modeString, 'gpt-5.5:medium');
      expect(result.resolvedRawModelString, 'gpt-5.5:medium');
    });

    test('session model wins over profile default and global last used', () {
      final profile = _profile(id: 'glm', defaultModelMode: 'GLM-5');

      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: null,
        savedProfileId: 'glm',
        sessionModelMode: 'opus:high',
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: [profile],
        builtInProfiles: const [],
        lastUsedModelMode: 'fable',
      );

      expect(result.resolvedModelMode.modeString, 'opus:high');
      expect(result.resolvedRawModelString, 'opus:high');
    });

    test('global lastUsedModelMode wins over ChatModelMode.defaultModel', () {
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: null,
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: 'fable',
      );

      expect(result.resolvedModelMode, ChatModelMode.fable);
      expect(result.resolvedRawModelString, 'fable');
    });

    test('falls back to ChatModelMode.defaultModel with nothing saved', () {
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: null,
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedModelMode, ChatModelMode.defaultModel);
      expect(result.resolvedRawModelString, isNull);
    });

    test('provider-owned raw model string (MiniMax) survives unmodified for '
        'a Claude-flavor session via the saved draft', () {
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'MiniMax-Text-01',
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedRawModelString, 'MiniMax-Text-01');
    });
  });

  group('regression: model/profile pairing', () {
    test('restores model and profile together after reopening a session', () {
      // Pin for the bug fixed in this change: _effectiveModelModeString
      // derived from a non-nullable ChatModelMode field and was never
      // null, so the restore branch in `_loadInitialSettings` was
      // permanently dead code: the saved model was silently discarded
      // on every load even though the saved profile id restored fine
      // (it used `??=` against an initially-null field). User-visible
      // symptom: reopen a session and the profile chip shows the right
      // provider but the model chip resets to "Default". Both must
      // resolve together here.
      final selectedProfile = _profile(
        id: 'profile-x',
        defaultModelMode: 'opus',
      );

      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'opus:high',
        savedProfileId: 'profile-x',
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: [selectedProfile],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedProfile?.id, 'profile-x');
      expect(result.resolvedModelMode.modeString, 'opus:high');
      expect(result.resolvedRawModelString, 'opus:high');
    });
  });

  group('third-party Anthropic profiles', () {
    test('detects custom base URLs and hides Claude aliases', () {
      final profile = _profile(
        id: 'kimi',
        anthropicConfig: AnthropicConfig(baseUrl: 'https://api.kimi.com'),
      );

      expect(profileUsesThirdPartyAnthropicBaseUrl(profile), isTrue);
      expect(profileBackendHost(profile), 'api.kimi.com');
      expect(
        ChatModelMode.availableForProfile(
          flavor: 'claude',
          claudeCompatible: true,
          allowClaudeAliases: !profileUsesThirdPartyAnthropicBaseUrl(profile),
        ),
        const [ChatModelMode.defaultModel],
      );
    });

    test('keeps Claude aliases for the official endpoint', () {
      final profile = _profile(
        id: 'anthropic',
        anthropicConfig: AnthropicConfig(baseUrl: 'https://api.anthropic.com'),
      );

      expect(profileUsesThirdPartyAnthropicBaseUrl(profile), isFalse);
      expect(profileBackendHost(profile), 'api.anthropic.com');
    });

    test(
      r'expands ${VAR:-default} base URLs so built-in Qwen is third-party',
      () {
        // Built-in profiles store daemon expansion refs, not bare URLs.
        // Without expanding the default, host parse fails and Qwen is
        // misclassified as official Anthropic (Claude aliases stay on).
        final profile = _profile(
          id: 'qwen',
          environmentVariables: [
            EnvironmentVariable(
              name: 'ANTHROPIC_BASE_URL',
              value:
                  r'${QWEN_BASE_URL:-https://token-plan.ap-southeast-1.maas.aliyuncs.com/apps/anthropic}',
            ),
          ],
        );

        expect(
          expandEnvDefault(
            r'${QWEN_BASE_URL:-https://token-plan.ap-southeast-1.maas.aliyuncs.com/apps/anthropic}',
          ),
          'https://token-plan.ap-southeast-1.maas.aliyuncs.com/apps/anthropic',
        );
        expect(profileUsesThirdPartyAnthropicBaseUrl(profile), isTrue);
        expect(
          profileBackendHost(profile),
          'token-plan.ap-southeast-1.maas.aliyuncs.com',
        );
      },
    );

    test('surfaces host for a misnamed custom profile pointing at Kimi', () {
      // Regression: name "Qwen 3.8" + env → kimi.com was invisible in the
      // chip/picker, so the user thought they were on Qwen while every
      // spawn hit Kimi and returned 403 usage-limit errors.
      final profile = _profile(
        id: 'custom-qwen-misrouted',
        name: 'Qwen 3.8',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://api.kimi.com/coding/',
          ),
        ],
      );

      expect(profileBackendHost(profile), 'api.kimi.com');
      expect(profileUsesThirdPartyAnthropicBaseUrl(profile), isTrue);
    });
  });
  group('provider-owned Codex effort round-trip', () {
    test('resolved provider-owned effort model is selectable in the picker',
        () {
      // A Codex session whose profile owns the model: the user picked an
      // effort (qwen3.7-max:high) and it was saved as the draft model mode.
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'qwen3.7-max:high',
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'codex',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedRawModelString, 'qwen3.7-max:high');
      expect(result.resolvedModelMode.modeString, 'qwen3.7-max:high');
      expect(result.resolvedModelMode.isCodex, isTrue);

      // The picker options built from the provider-owned model must
      // contain the resolved selection so it highlights on reopen.
      final options = ChatModelMode.availableForProfile(
        flavor: 'codex',
        claudeCompatible: false,
        providerOwnedCodexModel: result.resolvedRawModelString,
      );
      expect(options, contains(result.resolvedModelMode));
    });
  });
  group('profile-configured model list', () {
    test('saved profile model survives restore as both UI model and raw '
        'string', () {
      // Regression: picking a profile-configured model ('GLM-5') saved the
      // draft correctly, but on the next chat open the resolver normalized
      // the unknown slug back to 'default', so the pick appeared to never
      // take effect.
      final profile = _profile(id: 'glm', models: ['GLM-5', 'GLM-4.6']);

      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'GLM-5',
        savedProfileId: 'glm',
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: [profile],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedRawModelString, 'GLM-5');
      expect(result.resolvedModelMode.modeString, 'GLM-5');
    });

    test('saved profile model with effort suffix keeps its raw string', () {
      // Regression: 'GLM-5:high' parses as a Codex variant, so
      // normalizeRawForFlavor rewrote it to 'default' on Claude sessions
      // even though the profile explicitly offers it.
      final profile = _profile(id: 'glm', models: ['GLM-5', 'GLM-5:high']);

      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'GLM-5:high',
        savedProfileId: 'glm',
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: [profile],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedRawModelString, 'GLM-5:high');
      expect(result.resolvedModelMode.modeString, 'GLM-5:high');

      // The restored selection must be one of the picker's options so it
      // highlights on reopen.
      final options = ChatModelMode.availableForProfile(
        flavor: 'claude',
        claudeCompatible: true,
        profileModels: profile.models,
      );
      expect(options, contains(result.resolvedModelMode));
    });

    test('effort pick on a base-only profile model survives restore', () {
      // The picker offers slug:effort variants for every configured
      // model. A draft saved as 'GLM-5:high' must restore even though
      // the profile lists only the plain slug — it used to parse as a
      // Codex variant and normalize to 'default'.
      final profile = _profile(id: 'glm', models: ['GLM-5']);

      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'GLM-5:high',
        savedProfileId: 'glm',
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: [profile],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedRawModelString, 'GLM-5:high');
      expect(result.resolvedModelMode.modeString, 'GLM-5:high');
      expect(result.resolvedModelMode.reasoningEffort, 'high');
      expect(result.resolvedModelMode.isCodex, isFalse);

      // The restored selection must be one of the picker's options so
      // it highlights on reopen.
      final options = ChatModelMode.availableForProfile(
        flavor: 'claude',
        claudeCompatible: true,
        profileModels: profile.models,
      );
      expect(options, contains(result.resolvedModelMode));
    });

    test('unknown saved model without a profile still normalizes to '
        'default', () {
      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'GLM-5:high',
        savedProfileId: null,
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: const [],
        builtInProfiles: const [],
        lastUsedModelMode: null,
      );

      expect(result.resolvedRawModelString, 'default');
      expect(result.resolvedModelMode, ChatModelMode.defaultModel);
    });

    test('effort-suffixed gateway draft survives reopen on a third-party '
        'profile without a model list', () {
      // Regression: built-in gateway profiles (DeepSeek, …) ship an empty
      // `models` allowlist, so a saved '<slug>:<high>' draft parsed as a
      // Codex variant and collapsed to 'default' on reopen. The next send
      // then respawned the session with model=default and the session
      // silently fell back to the provider's default (or sonnet).
      final deepseek = _profile(
        id: 'deepseek',
        anthropicConfig: AnthropicConfig(
          baseUrl: r'${DEEPSEEK_BASE_URL:-https://api.deepseek.com/anthropic}',
        ),
      );

      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'deepseek-chat:high',
        savedProfileId: 'deepseek',
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: const [],
        builtInProfiles: [deepseek],
        lastUsedModelMode: null,
      );

      expect(result.resolvedRawModelString, 'deepseek-chat:high');
      expect(
        result.resolvedModelMode.modeString,
        'deepseek-chat:high',
        reason: 'the picker selection must not collapse to default',
      );
      expect(result.resolvedModelMode.reasoningEffort, 'high');
    });

    test('official-profile drafts still normalize unknown slugs to default',
        () {
      // Preservation is scoped to profiles that actually route to a
      // third-party gateway; an official-Anthropic profile must keep
      // rejecting unknown slugs.
      final official = _profile(
        id: 'anthropic',
        anthropicConfig: AnthropicConfig(baseUrl: 'https://api.anthropic.com'),
      );

      final result = resolveModelSelection(
        savedPermissionMode: null,
        savedModelMode: 'deepseek-chat:high',
        savedProfileId: 'anthropic',
        sessionModelMode: null,
        sessionPermissionMode: null,
        flavor: 'claude',
        settingsProfiles: const [],
        builtInProfiles: [official],
        lastUsedModelMode: null,
      );

      expect(result.resolvedRawModelString, 'default');
      expect(result.resolvedModelMode, ChatModelMode.defaultModel);
    });
  });
}

AIBackendProfile _profile({
  required String id,
  String? name,
  String? defaultModelMode,
  String? defaultPermissionMode,
  AnthropicConfig? anthropicConfig,
  ProfileCompatibility compatibility = const ProfileCompatibility(),
  List<String> models = const [],
  List<EnvironmentVariable> environmentVariables = const [],
}) {
  return AIBackendProfile(
    id: id,
    name: name ?? id,
    defaultModelMode: defaultModelMode,
    defaultPermissionMode: defaultPermissionMode,
    anthropicConfig: anthropicConfig,
    environmentVariables: environmentVariables,
    compatibility: compatibility,
    models: models,
  );
}
