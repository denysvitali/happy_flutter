import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/favorite_model.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/features/chat/model_selection_resolver.dart';

void main() {
  const favorites = {'anthropic': 'opus', 'openai': 'gpt-5.5:high'};

  ModelSelectionResolution resolve({
    String? draft,
    String? session,
    String? profileId,
    String flavor = 'claude',
    List<AIBackendProfile> profiles = const [],
    Map<String, String> values = favorites,
  }) => resolveModelSelection(
    savedPermissionMode: null,
    savedModelMode: draft,
    savedProfileId: profileId,
    sessionModelMode: session,
    sessionPermissionMode: null,
    flavor: flavor,
    settingsProfiles: profiles,
    builtInProfiles: const [],
    lastUsedModelMode: 'sonnet',
    favoriteModelsByProfile: values,
  );

  test('native providers use separate favorites before the global default', () {
    expect(resolve().resolvedRawModelString, 'opus');
    expect(resolve(flavor: 'codex').resolvedRawModelString, 'gpt-5.5:high');
  });

  test('explicit draft and server model always outrank a favorite', () {
    expect(resolve(draft: 'sonnet').resolvedRawModelString, 'sonnet');
    expect(resolve(session: 'fable').resolvedRawModelString, 'fable');
    expect(
      resolve(draft: 'default', session: 'sonnet').resolvedRawModelString,
      'default',
    );
    expect(resolve(session: 'default').resolvedRawModelString, 'default');
  });

  test('profile favorite preserves raw models and effort before default', () {
    final profile = AIBackendProfile(
      id: 'gateway',
      name: 'Gateway',
      defaultModelMode: 'GLM-5',
      models: const ['GLM-5', 'GLM-5:high'],
    );
    final result = resolve(
      profileId: profile.id,
      profiles: [profile],
      values: const {'gateway': 'GLM-5:high', 'anthropic': 'opus'},
    );
    expect(result.resolvedRawModelString, 'GLM-5:high');
    expect(result.resolvedModelMode.modeString, 'GLM-5:high');
  });

  test('missing profile does not inherit the native provider favorite', () {
    final result = resolve(profileId: 'deleted');
    expect(result.hadGhostProfileReference, isTrue);
    expect(result.resolvedRawModelString, 'sonnet');
  });

  test('blank and absent favorites keep existing fallback behavior', () {
    expect(resolve(values: const {}).resolvedRawModelString, 'sonnet');
    expect(
      resolve(values: const {'anthropic': '  '}).resolvedRawModelString,
      'sonnet',
    );
  });

  test('native and built-in profile identities share a preference key', () {
    final anthropic = AIBackendProfile(id: 'anthropic', name: 'Anthropic');
    final openai = AIBackendProfile(id: 'openai', name: 'OpenAI');
    expect(favoriteModelProviderKey(null, 'claude'), anthropic.id);
    expect(favoriteModelProviderKey(anthropic, 'claude'), anthropic.id);
    expect(favoriteModelProviderKey(null, 'codex'), openai.id);
    expect(favoriteModelProviderKey(openai, 'codex'), openai.id);
    // 'gemini' normalizes to the canonical 'agy' agent key.
    expect(favoriteModelProviderKey(null, 'gemini'), 'agent:agy');
  });

  test('custom providers stay isolated and favorite lookup trims values', () {
    final profile = AIBackendProfile(id: 'custom', name: 'Anthropic');
    expect(favoriteModelForProvider(favorites, profile, 'claude'), isNull);
    expect(
      favoriteModelForProvider({'custom': ' GLM-5 '}, profile, 'claude'),
      'GLM-5',
    );
  });
}
