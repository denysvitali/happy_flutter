import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/features/chat/model_selection_resolver.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';
import 'package:happy_flutter/features/chat/widgets/permission_mode_selector.dart';

void main() {
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
  });
}

AIBackendProfile _profile({
  required String id,
  String? defaultModelMode,
  String? defaultPermissionMode,
  ProfileCompatibility compatibility = const ProfileCompatibility(),
}) {
  return AIBackendProfile(
    id: id,
    name: id,
    defaultModelMode: defaultModelMode,
    defaultPermissionMode: defaultPermissionMode,
    compatibility: compatibility,
  );
}
