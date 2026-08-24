part of 'sync_service.dart';

/// Binds the user's selected model to the spawn environment.
///
/// Profile env vars are a snapshot of the model the profile was created
/// with. The model picker can select any model the provider serves, and
/// `--model` alone is not enough for Claude: `ANTHROPIC_DEFAULT_*_MODEL`
/// and `CLAUDE_CODE_SUBAGENT_MODEL` still route aliases and subagents to
/// whatever the profile hardcoded. Every spawn path (create, model/profile
/// respawn, auto-restore) runs its env through [_spawnEnvForModel].
extension SyncSpawnModelEnv on Sync {
  /// Returns [envVars] with the Claude model-selection knobs pointed at
  /// [modelMode] when that is a concrete provider model for a Claude spawn
  /// against a third-party Anthropic-compatible base URL. Official tier
  /// aliases (`opus`, `sonnet`, ...) and `default` are left to `--model`;
  /// non-Claude agents and first-party Anthropic profiles are untouched.
  Map<String, String> _spawnEnvForModel(
    Map<String, String> envVars, {
    required String? agent,
    required AIBackendProfile? profile,
    required String? modelMode,
  }) {
    if (profile == null || modelMode == null) return envVars;
    if (modelMode.isEmpty || modelMode == 'default') return envVars;
    if ((agent ?? 'claude') != 'claude') return envVars;
    if (_isClaudeModelAlias(modelMode)) return envVars;
    final baseUrl =
        envVars['ANTHROPIC_BASE_URL'] ?? _anthropicBaseUrlForProfile(profile);
    if (!_isThirdPartyAnthropicBaseUrl(baseUrl)) return envVars;
    final bound = applyModelSelectionToEnv(envVars, modelMode);
    if (bound['ANTHROPIC_MODEL'] != envVars['ANTHROPIC_MODEL'] ||
        bound['ANTHROPIC_DEFAULT_OPUS_MODEL'] !=
            envVars['ANTHROPIC_DEFAULT_OPUS_MODEL']) {
      logger.info(
        '[spawn] bound model env to selected model=$modelMode '
        '(profile=${profile.id})',
      );
    }
    return bound;
  }
}
