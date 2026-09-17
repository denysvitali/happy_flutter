import 'settings.dart';

/// Native providers share the same preference as their built-in profile.
String favoriteModelProviderKey(AIBackendProfile? profile, String? agent) {
  if (profile != null) return profile.id;
  return switch (normalizeAgentKey(agent)) {
    'claude' => 'anthropic',
    'codex' => 'openai',
    final key => 'agent:$key',
  };
}

String? favoriteModelForProvider(
  Map<String, String> favorites,
  AIBackendProfile? profile,
  String? agent,
) {
  final value = favorites[favoriteModelProviderKey(profile, agent)]?.trim();
  return value == null || value.isEmpty ? null : value;
}
