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
  /// Returns [envVars] with the selected model bound to every process knob
  /// that can override it.
  ///
  /// Claude third-party gateways need all Anthropic aliases and subagent
  /// knobs re-pointed. Custom OpenAI-compatible Codex profiles need
  /// `OPENAI_MODEL` (and its reasoning-effort knob) synchronized because a
  /// profile snapshot otherwise keeps launching its originally configured
  /// model.
  Map<String, String> _spawnEnvForModel(
    Map<String, String> envVars, {
    required String? agent,
    required AIBackendProfile? profile,
    required String? modelMode,
  }) {
    if (profile == null || modelMode == null) return envVars;
    if (modelMode.isEmpty || modelMode == 'default') return envVars;
    final effectiveAgent = agent ?? 'claude';
    if (effectiveAgent == 'claude') {
      return _bindClaudeModelEnv(envVars, profile, modelMode);
    }
    if (effectiveAgent == 'codex' && _isCustomCodexProfile(profile)) {
      return _bindCodexModelEnv(envVars, modelMode);
    }
    return envVars;
  }

  Map<String, String> _bindClaudeModelEnv(
    Map<String, String> envVars,
    AIBackendProfile profile,
    String modelMode,
  ) {
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

  Map<String, String> _bindCodexModelEnv(
    Map<String, String> envVars,
    String modelMode,
  ) {
    final raw = modelMode.endsWith('[1m]')
        ? modelMode.substring(0, modelMode.length - '[1m]'.length)
        : modelMode;
    if (raw.isEmpty || raw == 'default') return envVars;
    final separator = raw.lastIndexOf(':');
    final hasEffort = separator > 0 && separator < raw.length - 1;
    final model = hasEffort ? raw.substring(0, separator) : raw;
    final effort = hasEffort ? raw.substring(separator + 1) : null;
    if (model.isEmpty || model == 'default') return envVars;

    final bound = <String, String>{...envVars};
    bound['OPENAI_MODEL'] = model;
    if (effort == null || effort.isEmpty) {
      bound.remove('CODEX_MODEL_REASONING_EFFORT');
    } else {
      bound['CODEX_MODEL_REASONING_EFFORT'] = effort;
    }
    logger.info('[spawn] bound Codex model env to selected model=$model');
    return bound;
  }
}
