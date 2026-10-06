part of 'sync_service.dart';

/// Profile, environment-variable and model-mode resolution for session spawn.
///
/// Given a profile and the current settings, these helpers work out which
/// agent, model mode, base URL and env vars a spawned session should get.
/// Split out of `_sync_operations_session.dart` so the spawn request builder
/// can be read without scrolling past a thousand lines of vendor-specific
/// rules.
extension SyncSpawnProfileResolution on Sync {
  /// Resolve a profile by ID: custom profiles first, then built-in.
  AIBackendProfile? _resolveProfile(String id) {
    for (final p in settingsSnapshot.profiles) {
      if (p.id == id) return p;
    }
    return getBuiltInProfile(id);
  }

  /// Mirrors React Native's `getProfileEnvironmentVariables`.
  /// Ensures [profile]'s API keys are populated from secure storage
  /// before they are read for env-var construction.
  ///
  /// On cold start [SettingsStorage.getSettings] returns profiles with
  /// `apiKey: null` so we don't pay N×100ms FlutterSecureStorage round
  /// trips on the startup hot path. The first time a profile is used
  /// to spawn a session, we hydrate its keys here. Hydration is
  /// idempotent: subsequent spawns are a no-op.
  Future<AIBackendProfile> _hydrateProfileForSpawn(
    AIBackendProfile profile,
  ) async {
    // Built-in profiles do not have API keys in secure storage and
    // [hydrateProfileApiKeys] would return null for them. Short-circuit
    // so we always return a usable profile.
    final hydrated = await SettingsStorage().hydrateProfileApiKeys(profile.id);
    return hydrated ?? profile;
  }

  Map<String, String> _profileEnvironmentVariables(AIBackendProfile profile) {
    // Model-selection knobs (ANTHROPIC_DEFAULT_*_MODEL, subagent) are
    // rebound at spawn time by [_spawnEnvForModel] / applyModelSelectionToEnv
    // for non-Claude-alias picks on third-party Anthropic-compatible
    // gateways, so they are intentionally not stored on the profile.
    final envVars = <String, String>{};

    for (final v in profile.environmentVariables) {
      envVars[v.name] = v.value;
    }

    final anthropic = profile.anthropicConfig;
    if (anthropic != null) {
      if (anthropic.baseUrl != null) {
        envVars['ANTHROPIC_BASE_URL'] = anthropic.baseUrl!;
      }
      if (anthropic.authToken != null) {
        envVars['ANTHROPIC_AUTH_TOKEN'] = anthropic.authToken!;
      }
      if (anthropic.model != null) {
        envVars['ANTHROPIC_MODEL'] = anthropic.model!;
      }
    }

    final openai = profile.openaiConfig;
    if (openai != null) {
      if (openai.apiKey != null) {
        envVars['OPENAI_API_KEY'] = openai.apiKey!;
      }
      if (openai.baseUrl != null) {
        envVars['OPENAI_BASE_URL'] = openai.baseUrl!;
      }
      if (openai.model != null) {
        envVars['OPENAI_MODEL'] = openai.model!;
      }
    }

    final azure = profile.azureOpenAIConfig;
    if (azure != null) {
      if (azure.apiKey != null) {
        envVars['AZURE_OPENAI_API_KEY'] = azure.apiKey!;
      }
      if (azure.endpoint != null) {
        envVars['AZURE_OPENAI_ENDPOINT'] = azure.endpoint!;
      }
      if (azure.apiVersion != null) {
        envVars['AZURE_OPENAI_API_VERSION'] = azure.apiVersion!;
      }
      if (azure.deploymentName != null) {
        envVars['AZURE_OPENAI_DEPLOYMENT_NAME'] = azure.deploymentName!;
      }
    }

    final together = profile.togetherAIConfig;
    if (together != null) {
      if (together.apiKey != null) {
        envVars['TOGETHER_API_KEY'] = together.apiKey!;
      }
      if (together.model != null) {
        envVars['TOGETHER_MODEL'] = together.model!;
      }
    }

    final tmux = profile.tmuxConfig;
    if (tmux != null) {
      if (tmux.sessionName != null) {
        envVars['TMUX_SESSION_NAME'] = tmux.sessionName!;
      }
      if (tmux.tmpDir != null) {
        envVars['TMUX_TMPDIR'] = tmux.tmpDir!;
      }
      if (tmux.updateEnvironment != null) {
        envVars['TMUX_UPDATE_ENVIRONMENT'] = tmux.updateEnvironment.toString();
      }
    }

    if (profile.codexProviders.isNotEmpty) {
      envVars[codexProvidersEnvironmentKey] = encodeCodexProviders(
        profile.codexProviders,
      );
      final selectedProvider = profile.codexModelProvider?.trim();
      if (selectedProvider != null && selectedProvider.isNotEmpty) {
        envVars[codexModelProviderEnvironmentKey] = selectedProvider;
      }
    }

    return envVars;
  }

  /// Build daemon spawn environment variables with safe defaults.
  Map<String, String> _spawnEnvironmentVariables(
    Map<String, String>? base, {
    bool? codexFastModeOverride,
  }) {
    final codexFastMode =
        codexFastModeOverride ?? settingsSnapshot.codexFastMode;
    return <String, String>{
      ...?base,
      // Keep the Codex speed choice explicit in every spawn/restore request.
      // The Go launcher maps 1 to Fast/Priority and 0 to Standard. The
      // setting defaults to false so Codex never inherits its account-level
      // Fast default through a Happy invocation.
      'HAPPY_CODEX_FAST_MODE': codexFastMode ? '1' : '0',
    };
  }

  /// Resolve the profile/model pair a spawn should use.
  ///
  /// [explicitModelPick] marks a model selection the user made for THIS
  /// send/session (composer picker), as opposed to ambient state like
  /// `lastUsedModelMode` threaded through createSession. The Codex
  /// profile-pinned model (defaultModelMode → openaiConfig.model →
  /// OPENAI_MODEL env) must beat stale ambient defaults (e0e18dc7) but
  /// must NOT beat an explicit pick: on idle-respawn the pinned model
  /// silently replaced the picker selection, so every respawned Codex
  /// session ran the profile default (llm-proxy `opencode/x-preview-f-free`
  /// → Grok free tier → 402 "Grok Build usage balance exhausted") while
  /// the picker kept showing the user's model (session
  /// c71e354191746dd1a19c8a020, 2026-09-02). A live child adopts the pick
  /// from message meta, so only the respawn path dropped it.
  ({AIBackendProfile? profile, String? modelMode})
  _resolveEffectiveProfileForSpawn({
    required AIBackendProfile? profile,
    required String? modelMode,
    required String? agent,
    bool explicitModelPick = false,
    bool rejectExplicitClaudeModelOnGateway = false,
  }) {
    if (profile == null) {
      return (profile: null, modelMode: modelMode);
    }
    if (!profile.compatibility.supportsAgent(agent ?? 'claude')) {
      logger.warning(
        '[spawn] profile ${profile.id} is not compatible with '
        'agent=$agent; spawning without profile env vars',
      );
      return (profile: null, modelMode: modelMode);
    }
    final baseUrl = _anthropicBaseUrlForProfile(profile);
    if (agent == 'claude' &&
        _isClaudeModelAlias(modelMode ?? '') &&
        _isThirdPartyAnthropicBaseUrl(baseUrl)) {
      if (rejectExplicitClaudeModelOnGateway &&
          _isFullClaudeModelId(modelMode ?? '')) {
        // The user asked for a specific Claude model on a gateway profile.
        // Silently swapping it for the profile default made sessions run on
        // e.g. mimo-v2.6-flash while the picker still showed Claude
        // (session c98cadb9dbd4c12f8e3d1a7d5). Surface it instead.
        throw IncompatibleProviderAndModelError(
          'Claude model $modelMode cannot run on profile "${profile.name}" '
          '($baseUrl) — pick a non-Claude model or use the Anthropic profile',
        );
      }
      // Third-party Anthropic-compatible gateways (Grok proxy, MiniMax, etc.)
      // reject Claude model IDs. Drop the picker override AND any Claude model
      // baked into the profile env (ANTHROPIC_MODEL) so the daemon does not
      // re-assert provider_model_mismatch after we "fixed" modelMode alone.
      logger.warning(
        '[spawn] dropping incompatible Claude model override '
        'profile=${profile.id} modelMode=$modelMode baseUrl=$baseUrl',
      );
      return (
        profile: _stripClaudeModelFromProfile(profile),
        modelMode: 'default',
      );
    }
    if (agent == 'codex' && !explicitModelPick) {
      final profileModelMode = _codexModelModeForProfile(profile);
      if (profileModelMode != null && profileModelMode != modelMode) {
        logger.info(
          '[spawn] using Codex profile model '
          'profile=${profile.id} modelMode=$profileModelMode '
          'instead of $modelMode',
        );
        return (profile: profile, modelMode: profileModelMode);
      }
    }
    return (profile: profile, modelMode: modelMode);
  }

  String? _codexModelModeForProfile(AIBackendProfile profile) {
    final defaultModelMode = _nonDefaultModelMode(profile.defaultModelMode);
    if (defaultModelMode != null) {
      return defaultModelMode;
    }
    final configModel = _nonDefaultModelMode(profile.openaiConfig?.model);
    if (configModel != null) {
      return configModel;
    }
    final envModel = _profileEnvValue(profile, 'OPENAI_MODEL');
    if (envModel == null) {
      return null;
    }
    final effort = _profileEnvValue(profile, 'CODEX_MODEL_REASONING_EFFORT');
    return effort == null ? envModel : '$envModel:$effort';
  }

  String? _profileEnvValue(AIBackendProfile profile, String name) {
    for (final env in profile.environmentVariables) {
      if (env.name != name) continue;
      return _nonDefaultModelMode(env.value);
    }
    return null;
  }

  String? _nonDefaultModelMode(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'default') {
      return null;
    }
    return trimmed;
  }

  String? _normalizeModelModeForAgent(
    String? modelMode,
    String? agent, {
    AIBackendProfile? profile,
  }) {
    if (modelMode == null || modelMode == 'default') {
      return modelMode;
    }
    if (agent != 'claude' && _isClaudeModelAlias(modelMode)) {
      _logDroppedModelMode(
        modelMode,
        agent,
        profile,
        'Claude alias on a non-Claude session',
      );
      return 'default';
    }
    if (agent == 'codex' &&
        !_isCustomCodexProfile(profile) &&
        !_isKnownCodexModelMode(modelMode)) {
      _logDroppedModelMode(
        modelMode,
        agent,
        profile,
        'not a known Codex model and the profile is not a custom '
        'Codex provider',
      );
      return 'default';
    }
    // The reverse direction: non-Claude model names from a previous
    // session must not leak into Claude spawns — Claude CLI rejects them
    // with "There's an issue with the selected model ... Run --model to
    // pick a different model." `lastUsedModelMode` is a global preference,
    // not per-agent, so the stale value survives a profile switch.
    // Vendor/model strings like inclusionai/ling-3.0-flash:free use a
    // slash in the provider prefix and are never valid Claude models.
    final configuredClaudeGatewayModel =
        agent == 'claude' &&
        profile != null &&
        _isThirdPartyAnthropicBaseUrl(_anthropicBaseUrlForProfile(profile)) &&
        _profileOwnsModel(profile, modelMode);
    if (agent == 'claude' &&
        _isNonClaudeModelMode(modelMode) &&
        !configuredClaudeGatewayModel) {
      _logDroppedModelMode(
        modelMode,
        agent,
        profile,
        agent == 'claude' &&
                profile != null &&
                _isThirdPartyAnthropicBaseUrl(
                  _anthropicBaseUrlForProfile(profile),
                )
            ? 'the selected third-party gateway profile does not list it '
                  '(profile.models is stale or the pick came from another '
                  'profile); the profile default model will spawn instead'
            : 'non-Claude model on a Claude session without an owning '
                  'third-party gateway profile',
      );
      return 'default';
    }
    return modelMode;
  }

  /// Resolve the profile saved for a session (per-session draft in MMKV)
  /// without hydrating credentials — enough for model-mode normalization
  /// gates when the caller has no explicit profile id. SendMessage uses this
  /// so a provider-owned pick is not silently downgraded to 'default' (and
  /// replaced by the profile's default model) just because the send call
  /// carried no profileId.
  Future<AIBackendProfile?> _sessionProfileForNormalization(
    String sessionId,
  ) async {
    final savedId = await MMKVStorage().getSessionProfile(sessionId);
    if (savedId == null) return null;
    return _resolveProfile(savedId);
  }

  /// A dropped pick is otherwise invisible: the session silently spawns with
  /// the profile's default model (production case: llm-proxy default
  /// `opencode/x-preview-f-free` spawning after the user picked
  /// `grok/grok-4.6`, session cddc18c35de421108622d20da). Log every
  /// downgrade so prod logs answer "why did my model pick not apply".
  void _logDroppedModelMode(
    String modelMode,
    String? agent,
    AIBackendProfile? profile,
    String reason,
  ) {
    logger.warning(
      '[spawn] dropping model pick "$modelMode" for agent=$agent '
      'profile=${profile?.id ?? 'none'}: $reason',
    );
  }

  bool _profileOwnsModel(AIBackendProfile profile, String modelMode) {
    // `[1m]` is a Claude Code context-window modifier appended by the app.
    // Provider profiles advertise the base model id, so compare ownership
    // without the modifier while preserving it for the eventual --model arg.
    final providerModelMode = modelMode.endsWith('[1m]')
        ? modelMode.substring(0, modelMode.length - '[1m]'.length)
        : modelMode;
    final configuredModels = <String>{
      for (final entry in profile.models) parseModelContextChoice(entry).model,
      profile.defaultModelMode ?? '',
      profile.anthropicConfig?.model ?? '',
      profile.openaiConfig?.model ?? '',
      profile.azureOpenAIConfig?.deploymentName ?? '',
    };
    for (final env in profile.environmentVariables) {
      if (_isModelEnvironmentVariable(env.name)) {
        configuredModels.add(_extractDefaultEnvValue(env.value));
      }
    }
    for (final configured in configuredModels) {
      if (configured.isEmpty || configured.startsWith(r'${')) continue;
      if (providerModelMode == configured ||
          providerModelMode.startsWith('$configured:')) {
        return true;
      }
    }
    return false;
  }

  bool _isModelEnvironmentVariable(String name) {
    return name == 'OPENAI_MODEL' ||
        name == 'AZURE_OPENAI_DEPLOYMENT_NAME' ||
        name == 'ANTHROPIC_MODEL' ||
        name == 'ANTHROPIC_SMALL_FAST_MODEL' ||
        name == 'ANTHROPIC_DEFAULT_OPUS_MODEL' ||
        name == 'ANTHROPIC_DEFAULT_SONNET_MODEL' ||
        name == 'ANTHROPIC_DEFAULT_HAIKU_MODEL' ||
        name == 'CLAUDE_CODE_SUBAGENT_MODEL';
  }

  bool _isKnownCodexModelMode(String modelMode) {
    final slug = modelMode.contains(':')
        ? modelMode.substring(0, modelMode.indexOf(':'))
        : modelMode;
    return slug.startsWith('gpt-') ||
        RegExp(r'^o\d').hasMatch(slug) ||
        isTokenPlanCodexModelSlug(slug);
  }

  /// True for a concrete Claude model id (`claude-sonnet-5-5`), as opposed to
  /// a tier alias (`sonnet`) that a gateway profile may legitimately remap
  /// through `ANTHROPIC_DEFAULT_{TIER}_MODEL`.
  bool _isFullClaudeModelId(String modelMode) {
    final separator = modelMode.lastIndexOf(':');
    final slug = separator > 0 ? modelMode.substring(0, separator) : modelMode;
    return slug.startsWith('claude-') || slug.contains('/claude-');
  }

  bool _isClaudeModelAlias(String modelMode) {
    final separator = modelMode.lastIndexOf(':');
    final slug = separator > 0 ? modelMode.substring(0, separator) : modelMode;
    return slug == 'opus' ||
        slug == 'sonnet' ||
        slug == 'haiku' ||
        slug == 'fable' ||
        slug.startsWith('claude-') ||
        slug.contains('/claude-');
  }

  bool _isThirdPartyAnthropicBaseUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    return !_isOfficialAnthropicBaseUrl(raw);
  }

  bool _isOfficialAnthropicBaseUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (uri.host.toLowerCase() != 'api.anthropic.com') return false;
    final normalizedPath = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return normalizedPath.isEmpty || normalizedPath == '/v1';
  }

  bool _isCustomCodexProfile(AIBackendProfile? profile) {
    if (profile == null) return false;
    if (profile.codexProviders.isNotEmpty || profile.models.isNotEmpty) {
      return true;
    }
    if (profile.azureOpenAIConfig != null) return true;
    if (_profileEnvValue(profile, 'AZURE_OPENAI_ENDPOINT') != null ||
        _profileEnvValue(profile, 'AZURE_OPENAI_DEPLOYMENT_NAME') != null) {
      return true;
    }
    final baseUrl =
        profile.openaiConfig?.baseUrl ??
        _profileEnvValue(profile, 'OPENAI_BASE_URL');
    return baseUrl != null && !_isOfficialOpenAIBaseUrl(baseUrl);
  }

  bool _isOfficialOpenAIBaseUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (uri.host.toLowerCase() != 'api.openai.com') return false;
    final normalizedPath = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return normalizedPath.isEmpty || normalizedPath == '/v1';
  }

  String? _anthropicBaseUrlForProfile(AIBackendProfile profile) {
    final configBaseUrl = profile.anthropicConfig?.baseUrl;
    if (configBaseUrl != null && configBaseUrl.isNotEmpty) {
      return _extractDefaultEnvValue(configBaseUrl);
    }
    for (final env in profile.environmentVariables) {
      if (env.name == 'ANTHROPIC_BASE_URL' && env.value.isNotEmpty) {
        return _extractDefaultEnvValue(env.value);
      }
    }
    return null;
  }

  /// Drop Claude model IDs from a third-party Anthropic-compatible profile
  /// so spawn env no longer carries `ANTHROPIC_MODEL=claude-*` alongside a
  /// non-Anthropic base URL. Profile metadata (id/name) is preserved.
  ///
  /// Rebuilds rather than [AIBackendProfile.copyWith] because that helper
  /// cannot clear nullable fields to null.
  AIBackendProfile _stripClaudeModelFromProfile(AIBackendProfile profile) {
    final filteredEnv = profile.environmentVariables
        .where((env) {
          if (env.name != 'ANTHROPIC_MODEL') return true;
          return !_isClaudeModelAlias(env.value);
        })
        .toList(growable: false);
    final anthropic = profile.anthropicConfig;
    final filteredAnthropic =
        anthropic != null &&
            anthropic.model != null &&
            _isClaudeModelAlias(anthropic.model!)
        ? AnthropicConfig(
            baseUrl: anthropic.baseUrl,
            authToken: anthropic.authToken,
          )
        : anthropic;
    final defaultMode = profile.defaultModelMode;
    final filteredDefault =
        defaultMode != null && _isClaudeModelAlias(defaultMode)
        ? null
        : defaultMode;
    if (identical(filteredEnv, profile.environmentVariables) &&
        identical(filteredAnthropic, anthropic) &&
        filteredDefault == defaultMode) {
      return profile;
    }
    return AIBackendProfile(
      id: profile.id,
      name: profile.name,
      description: profile.description,
      anthropicConfig: filteredAnthropic,
      openaiConfig: profile.openaiConfig,
      azureOpenAIConfig: profile.azureOpenAIConfig,
      togetherAIConfig: profile.togetherAIConfig,
      tmuxConfig: profile.tmuxConfig,
      startupBashScript: profile.startupBashScript,
      environmentVariables: filteredEnv,
      defaultSessionType: profile.defaultSessionType,
      defaultPermissionMode: profile.defaultPermissionMode,
      defaultModelMode: filteredDefault,
      compatibility: profile.compatibility,
      isBuiltIn: profile.isBuiltIn,
      createdAt: profile.createdAt,
      updatedAt: profile.updatedAt,
      version: profile.version,
    );
  }

  String _extractDefaultEnvValue(String value) {
    final match = RegExp(r'^\$\{[^:}]+:-(.*)\}$').firstMatch(value);
    return match?.group(1) ?? value;
  }

  /// Recognize non-Claude model identifiers so they can be stripped
  /// from Claude spawns. Claude CLI rejects foreign model names
  /// with "There's an issue with the selected model ... Run --model
  /// to pick a different model." `lastUsedModelMode` is a global
  /// preference, not per-agent, so the stale value survives a
  /// profile switch.
  ///
  /// Known non-Claude patterns:
  /// - OpenAI/Codex models: `gpt-*`, `o<digit>*` token plan slugs.
  /// - Gemini models: `gemini-*`.
  /// - Unconfigured vendor/model strings such as
  ///   `inclusionai/ling-3.0-flash:free`. Explicit models owned by the
  ///   selected third-party Claude-compatible profile are handled by
  ///   [_normalizeModelModeForAgent] and must pass through unchanged.
  /// - Codex selections use `<slug>:<reasoning-effort>` wire format.
  /// Custom Claude models also use `:` for effort, so check the slug.
  bool _isNonClaudeModelMode(String modelMode) {
    // Vendor/model strings with a '/' prefix (e.g. 'inclusionai/…')
    // carry a provider name that Claude CLI cannot resolve. Only
    // reject them when the full string is not a known Claude alias
    // so that 'anthropic/claude-opus-4-6' third-party endpoints
    // still pass through.
    if (modelMode.contains('/') && !_isClaudeModelAlias(modelMode)) {
      return true;
    }
    if (modelMode.startsWith('gpt-')) return true;
    if (modelMode.startsWith('gemini-')) return true;
    // Codex selections use `<slug>:<reasoning-effort>` wire format.
    // Custom Claude models also use `:` for effort, so check the slug.
    if (modelMode.contains(':')) {
      final slug = modelMode.substring(0, modelMode.indexOf(':'));
      if (slug.startsWith('gpt-') || slug.startsWith('gemini-')) return true;
      // Custom Claude models with effort — pass through
      return false;
    }
    return false;
  }

  String? _agentForProfile(AIBackendProfile? profile) {
    if (profile == null) return null;
    final compatibility = profile.compatibility;
    if (compatibility.codex && !compatibility.claude) return 'codex';
    if (compatibility.agy && !compatibility.claude) return 'agy';
    if (compatibility.pi && !compatibility.claude) return 'pi';
    return 'claude';
  }

  /// Return the model override string to pass to --model when spawning
  /// sessions, or null when the caller has no preference.
  ///
  /// Explicit `'default'` is preserved (not collapsed to null) so the
  /// daemon can clear sticky third-party models / `codexThreadId` when
  /// the user switches from e.g. Qwen Token Plan back to ChatGPT/Default.
  /// When [modelMode] is a non-default selection, pass it so the daemon
  /// writes it into session metadata for tracking.
  String? _getModelOverride({
    String? agent,
    AIBackendProfile? profile,
    String? modelMode,
  }) {
    final effectiveAgent = agent ?? _agentForProfile(profile);
    final normalized =
        effectiveAgent == 'codex' && _isCustomCodexProfile(profile)
        ? _nonDefaultModelMode(modelMode)
        : _normalizeModelModeForAgent(
            modelMode,
            effectiveAgent,
            profile: profile,
          );
    if (normalized != null && normalized != 'default') {
      // A provider-owned model override whose profile could not be
      // resolved spawns without its routing env: with no ANTHROPIC_BASE_URL
      // the daemon rewrites unknown slugs to claude-sonnet-4-6 and the
      // session silently runs the wrong model. Official tier aliases work
      // without env; everything else drops to an explicit default.
      if (effectiveAgent == 'claude' &&
          profile == null &&
          !_isClaudeModelAlias(normalized)) {
        logger.warning(
          '[spawn] dropping model override "$normalized" without a '
          'resolved profile — it cannot reach its provider',
        );
        return 'default';
      }
      return normalized;
    }
    // Keep an explicit default selection on the wire. Collapsing it to
    // null made restore re-apply the previous session metadata model
    // (e.g. qwen3.8-max-preview) against a ChatGPT account.
    if (modelMode == 'default' || normalized == 'default') {
      return 'default';
    }
    return null;
  }

  /// Get environment variables and profile for spawning a session, using
  /// the profile associated with the session if available. Does NOT fall
  /// back to [lastUsedProfile] — if no profile is saved for the session,
  /// returns empty env vars and null profile to avoid using a wrong profile
  /// after profile switches.
  Future<({Map<String, String> envVars, AIBackendProfile? profile})>
  _getSpawnEnvVarsForSession(
    String sessionId, {
    String? profileIdOverride,
    bool? codexFastModeOverride,
  }) async {
    final override = testGetSpawnEnvVarsOverride;
    if (override != null) return override(sessionId);
    final codexFastMode =
        codexFastModeOverride ??
        CodexSpeedSelection().read(sessionId) ??
        _sessions[sessionId]?.metadata?.codexFastMode ??
        settingsSnapshot.codexFastMode;
    // Prefer the in-memory override (from sendMessage) over MMKV,
    // which may not have flushed a recent debounced write yet.
    final profileId =
        profileIdOverride ?? await MMKVStorage().getSessionProfile(sessionId);
    if (profileId != null) {
      final profile = _resolveProfile(profileId);
      if (profile != null) {
        final hydrated = await _hydrateProfileForSpawn(profile);
        return (
          envVars: _spawnEnvironmentVariables(
            _profileEnvironmentVariables(hydrated),
            codexFastModeOverride: codexFastMode,
          ),
          profile: hydrated,
        );
      }
    }
    if (profileIdOverride != null && profileIdOverride != 'default') {
      throw StateError(
        'Selected provider profile is unavailable. '
        'Wait for settings to sync or select another profile.',
      );
    }
    // No profile saved for this session — return empty env vars rather
    // than falling back to lastUsedProfile which may have changed since
    // creation.
    return (
      envVars: _spawnEnvironmentVariables(
        null,
        codexFastModeOverride: codexFastMode,
      ),
      profile: null,
    );
  }

  /// Send `spawn-happy-session`, tolerating daemons that predate the
  /// `isRestore` request field: their strict protobuf JSON unmarshal
  /// rejects the whole request with an "unknown field" error. Retry once
  /// without the field instead of failing the restore.
  Future<SpawnSessionResponse> _spawnHappySessionRPC(
    String machineId,
    SpawnSessionRequest req, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson(),
        SpawnSessionResponse.fromJson,
        timeout: timeout,
      );
    } on RpcException catch (error) {
      final rejectedIsRestore =
          error.message.contains('unknown field') &&
          error.message.contains('isRestore');
      if (!req.isRestore || !rejectedIsRestore) rethrow;
      logger.info(
        '[spawn] daemon on machine=$machineId rejected the isRestore '
        'field (pre-field daemon); retrying spawn without it',
      );
      return _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson()..remove('isRestore'),
        SpawnSessionResponse.fromJson,
        timeout: timeout,
      );
    }
  }
}
