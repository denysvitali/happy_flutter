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
}

AIBackendProfile _profile({
  required String id,
  String? defaultModelMode,
  String? defaultPermissionMode,
  AnthropicConfig? anthropicConfig,
  ProfileCompatibility compatibility = const ProfileCompatibility(),
}) {
  return AIBackendProfile(
    id: id,
    name: id,
    defaultModelMode: defaultModelMode,
    defaultPermissionMode: defaultPermissionMode,
    anthropicConfig: anthropicConfig,
    compatibility: compatibility,
  );
}
