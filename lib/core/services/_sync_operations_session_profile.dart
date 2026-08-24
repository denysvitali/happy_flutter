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
    // Older profiles may have only ANTHROPIC_MODEL. Normalize here as well
    // as during settings load because profiles can arrive from sync after
    // startup, and Claude's aliases/defaults/subagents otherwise fall back
    // to first-party model IDs that the gateway does not serve.
    profile = normalizeModelSelectionEnv(profile);
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
  Map<String, String> _spawnEnvironmentVariables(Map<String, String>? base) {
    return <String, String>{...?base};
  }

  ({AIBackendProfile? profile, String? modelMode})
  _resolveEffectiveProfileForSpawn({
    required AIBackendProfile? profile,
    required String? modelMode,
    required String? agent,
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
    if (agent == 'codex') {
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
      return 'default';
    }
    if (agent == 'codex' &&
        !_isCustomCodexProfile(profile) &&
        !_isKnownCodexModelMode(modelMode)) {
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
      return 'default';
    }
    return modelMode;
  }

  bool _profileOwnsModel(AIBackendProfile profile, String modelMode) {
    final configuredModels = <String>{
      ...profile.models,
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
      if (modelMode == configured || modelMode.startsWith('$configured:')) {
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
    if (compatibility.gemini && !compatibility.claude) return 'gemini';
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
  }) async {
    final override = testGetSpawnEnvVarsOverride;
    if (override != null) return override(sessionId);
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
          ),
          profile: hydrated,
        );
      }
    }
    // No profile saved for this session — return empty env vars rather
    // than falling back to lastUsedProfile which may have changed since
    // creation.
    return (envVars: _spawnEnvironmentVariables(null), profile: null);
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
      logger.warning(
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

  Future<
    ({String sessionId, Session session, SessionEncryption sessionEncryption})
  >
  _resolveSendTargetSession({
    required String sessionId,
    required Session session,
    required SessionEncryption sessionEncryption,
    required String effectivePermissionMode,
    String? profileId,
    String? modelMode,
  }) async {
    final health = SyncHealth(
      session: session,
      sessionSpawnedAt: _sessionSpawnedAt,
      lastEphemeralAt: _lastEphemeralAt,
    );

    final recentlySpawned = health.wasRecentlySpawned;

    // When the caller didn't pass a profileId (e.g. ask_user_question
    // fallback), fall back to MMKV — the persisted session profile reflects
    // the user's last explicit choice. This mirrors _getSpawnEnvVarsForSession
    // and lets us detect "user switched to Default" (MMKV cleared) as a real
    // change, while still ignoring no-op sends from callers that don't care.
    final mmkvProfileId = await MMKVStorage().getSessionProfile(sessionId);
    final effectiveProfileIdForChange = profileId ?? mmkvProfileId;
    final spawnedProfileKnown = _sessionSpawnedProfile.containsKey(sessionId);
    // For just-spawned sessions, MMKV may not have been written yet even
    // though _sessionSpawnedProfile was registered. Treat absence-of-MMKV +
    // recently-spawned as "no information" rather than "user wants Default",
    // otherwise we kill freshly-created sessions on their first send.
    final spawnedProfileId = _sessionSpawnedProfile[sessionId];
    final mmkvUnknownForFreshSpawn =
        recentlySpawned && profileId == null && mmkvProfileId == null;
    // For sessions not tracked by this app run, only treat an explicit
    // (non-default) profile argument as a real change. Falling back to MMKV on
    // unknown sessions can be stale and would otherwise cause unnecessary kill +
    // respawn cycles.
    final explicitProfileChange = profileId != null && profileId != 'default';
    final profileChanged = spawnedProfileKnown
        ? (mmkvUnknownForFreshSpawn
              ? false
              : spawnedProfileId != effectiveProfileIdForChange)
        : explicitProfileChange;

    final spawnedModel = _sessionSpawnedModel[sessionId];
    // Any model change must respawn — including switch TO `default`.
    // Old guard only fired for non-default → non-default, so Qwen →
    // Default (OpenAI) kept the old process (and its sticky model /
    // codexThreadId) alive and remote compact still used qwen.
    final previousModel = spawnedModel ?? 'default';
    final requestedModel = modelMode ?? 'default';
    final modelChanged =
        _sessionSpawnedModel.containsKey(sessionId) &&
        previousModel != requestedModel;

    final looksReady = health.looksReady;
    final onlineTrusted = health.isOnlineTrusted;

    final lifecycleState = session.effectiveLifecycleState;
    final lifecycleErrored = lifecycleState == 'errored';

    // Snapshot of the spawn tracking cleared for a profile/model respawn.
    // If the respawn fails, this is put back so the next send re-detects
    // the change and retries — otherwise the change is forgotten and every
    // later send silently keeps the old process (and its old model) alive.
    ({
      int? at,
      bool hadProfile,
      String? profile,
      bool hadModel,
      String? model,
      String? agent,
    })?
    clearedSpawnTracking;
    void restoreClearedSpawnTracking() {
      final cleared = clearedSpawnTracking;
      if (cleared == null) return;
      clearedSpawnTracking = null;
      // A successful spawn re-registered fresh tracking — keep it.
      if (_sessionSpawnedAt.containsKey(sessionId)) return;
      if (cleared.at case final at?) _sessionSpawnedAt[sessionId] = at;
      if (cleared.hadProfile) {
        _sessionSpawnedProfile[sessionId] = cleared.profile;
      }
      if (cleared.hadModel) _sessionSpawnedModel[sessionId] = cleared.model;
      if (cleared.agent case final agent?) {
        _sessionSpawnedAgent[sessionId] = agent;
      }
    }

    logger.info(
      '[sendMessage] _resolveSendTargetSession '
      'session=$sessionId looksReady=$looksReady '
      'profileChanged=$profileChanged modelChanged=$modelChanged '
      '(isOnline=${session.isOnline} onlineTrusted=$onlineTrusted '
      'lifecycleState=$lifecycleState lcRecent=${health.lcRecent})',
    );

    if (looksReady && (profileChanged || modelChanged)) {
      final machineId = session.metadata?.machineId;
      if (machineId != null && machineId.isNotEmpty) {
        if (_profileModelKillInFlight.contains(sessionId)) {
          logger.info(
            '[sendMessage] profile/model kill already in-flight for '
            'session=$sessionId; skipping duplicate kill',
          );
        } else {
          final spawnedChange = _spawnedValueChange(
            profileChanged: profileChanged,
            sessionId: sessionId,
            profileId: profileId,
            modelMode: modelMode,
          );
          logger.info(
            '[sendMessage] ${profileChanged ? "profile" : "model"} changed '
            'for session=$sessionId '
            '$spawnedChange; '
            'respawning session',
          );
          _profileModelKillInFlight.add(sessionId);
          // Clear spawned data before the respawn so auto-restore picks up the
          // new profile/model instead of re-using the old one. The machine
          // replacement RPC owns the process boundary: it kills the old
          // process and starts a new one with the replacement environment.
          clearedSpawnTracking = (
            at: _sessionSpawnedAt.remove(sessionId),
            hadProfile: _sessionSpawnedProfile.containsKey(sessionId),
            profile: _sessionSpawnedProfile.remove(sessionId),
            hadModel: _sessionSpawnedModel.containsKey(sessionId),
            model: _sessionSpawnedModel.remove(sessionId),
            agent: _sessionSpawnedAgent.remove(sessionId),
          );
        }
      }
    } else if (looksReady || recentlySpawned) {
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }

    final machineId = session.metadata?.machineId;
    final path = session.metadata?.path;
    if (machineId == null ||
        machineId.isEmpty ||
        path == null ||
        path.isEmpty) {
      restoreClearedSpawnTracking();
      if (lifecycleErrored) {
        throw StateError(
          'Could not restore stopped session $sessionId: '
          'missing machineId/path',
        );
      }
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }

    // Fail fast if the machine is offline — don't wait 60 s for a timeout.
    final machine = _machines[machineId];
    if (machine != null && !machine.isOnline) {
      restoreClearedSpawnTracking();
      logger.info(
        '[sendMessage] machine=$machineId is offline, '
        'skipping auto-restore',
      );
      if (lifecycleErrored) {
        throw StateError(
          'Could not restore stopped session $sessionId: '
          'machine $machineId is offline',
        );
      }
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }

    logger.info(
      '[sendMessage] session=$sessionId appears offline '
      '(presence=${session.presence}, '
      'lifecycleState=${session.effectiveLifecycleState}); '
      'attempting auto-restore',
    );

    if (_autoRestoreInFlight.contains(sessionId)) {
      final inFlightProfileId = _autoRestoreProfileIds[sessionId];
      // Only share the in-flight auto-restore if the profileId matches.
      // If profileId differs, fall through to start our own auto-restore
      // to avoid using the wrong profile's env vars.
      if (inFlightProfileId == profileId) {
        logger.info(
          '[sendMessage] auto-restore already in-flight for '
          'session=$sessionId with same profileId=$profileId, awaiting result',
        );
        final pendingCompleter = _autoRestoreCompleters[sessionId];
        if (pendingCompleter != null) {
          final pending = await pendingCompleter.future;
          if (lifecycleErrored && pending.session.hasLifecycleError) {
            throw StateError(
              'Could not restore stopped session $sessionId: '
              'restore failed',
            );
          }
          return pending;
        }
      } else {
        logger.info(
          '[sendMessage] auto-restore already in-flight for '
          'session=$sessionId but profileId differs '
          '($inFlightProfileId vs $profileId); starting own auto-restore',
        );
      }
      // If profiles don't match (or inFlightProfileId is null but we have
      // a profileId), fall through to start our own auto-restore.
    }
    _autoRestoreInFlight.add(sessionId);
    final fallback = (
      sessionId: sessionId,
      session: session,
      sessionEncryption: sessionEncryption,
    );
    final completer =
        Completer<
          ({
            String sessionId,
            Session session,
            SessionEncryption sessionEncryption,
          })
        >();
    _autoRestoreCompleters[sessionId] = completer;
    _autoRestoreProfileIds[sessionId] = profileId;
    try {
      // Resolve profile env vars for this session before spawning.
      // Pass profileId from the sendMessage caller so we don't rely
      // on a debounced MMKV write that may not have flushed yet.
      final spawnResult = await _getSpawnEnvVarsForSession(
        sessionId,
        profileIdOverride: profileId,
      );
      final sessionAgent =
          session.metadata?.flavor ??
          _sessionSpawnedAgent[sessionId] ??
          'claude';
      // Drop incompatible model overrides (e.g. a Claude model alias paired
      // with a third-party Anthropic-compatible base URL). The daemon rejects
      // that combination with `provider_model_mismatch`, so mirror the
      // createSession guard here to keep auto-restore from failing.
      final spawnProfileResolution = _resolveEffectiveProfileForSpawn(
        profile: spawnResult.profile,
        modelMode: modelMode,
        agent: sessionAgent,
      );
      final effectiveModelMode = spawnProfileResolution.modelMode;
      final effectiveEnvVars = spawnProfileResolution.profile != null
          ? spawnResult.envVars
          : <String, String>{};
      final req = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: path,
        sessionId: sessionId,
        isRestore: true,
        agent: sessionAgent,
        permissionMode: effectivePermissionMode,
        spawnBackend: _spawnBackendForExistingSession(session),
        repoUrl: session.metadata?.repoUrl,
        repoRef: session.metadata?.repoRef,
        repoCommit: session.metadata?.repoCommit,
        model: _getModelOverride(
          agent: sessionAgent,
          profile: spawnProfileResolution.profile,
          modelMode: effectiveModelMode,
        ),
        environmentVariables: effectiveEnvVars,
      );
      final result = await _spawnHappySessionRPC(
        machineId,
        req,
        timeout: const Duration(seconds: 60),
      );
      if (result.type != 'success') {
        restoreClearedSpawnTracking();
        final errorMsg = result.errorMessage ?? '';
        // If the error indicates the session/machine doesn't exist, treat it
        // as permanent — don't return fallback which would cause _completeSend
        // to POST to a non-existent session and lose the message.
        final isPermanent =
            errorMsg.contains('not found') ||
            errorMsg.contains('does not exist') ||
            errorMsg.contains('not exist');
        // HAPPY_FLUTTER-3EP/3EN: the killSession ACK can legitimately
        // lag the in-flight `lifecycleState=exited` write (server
        // forwards through Redis).  When auto-restore arrives before
        // the server has cleared the terminal flag, the daemon
        // responds "is in terminal state; refusing stale spawn".
        // This is NOT permanent — the next send (after the server
        // eventually reconciles) will succeed. Throw here and we
        // lose the message AND strand the user. Treat as
        // recoverable: return the fallback, drop the lifecycleState
        // so the next _resolveSendTargetSession sees the local
        // session as restartable, and let the user retry.
        final isTerminalStateRace =
            errorMsg.contains('terminal state') ||
            errorMsg.contains('refusing stale spawn');
        logger.warning(
          '[sendMessage] auto-restore not successful '
          'session=$sessionId type=${result.type ?? 'null'} '
          'error=$errorMsg '
          'isPermanent=$isPermanent isTerminalStateRace=$isTerminalStateRace',
        );
        if (isTerminalStateRace) {
          // Strip the terminal flag locally so the very next send
          // doesn't re-hit the same race.  We don't change the
          // server's view — that's controlled by the kill
          // reconciliation — but we stop pretending the session is
          // un-restartable from the client.
          if (session.metadata != null) {
            _sessions[sessionId] = session.copyWith(
              metadata: session.metadata!.copyWith(
                lifecycleState: 'starting',
                lifecycleStateError: null,
                lifecycleStateSince: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }
          completer.complete(fallback);
          return fallback;
        }
        if (isPermanent) {
          final reason = errorMsg.isEmpty
              ? result.type ?? 'unknown restore failure'
              : errorMsg;
          throw StateError('Session not found: $sessionId — $reason');
        }
        if (lifecycleErrored) {
          // The session is in an errored state but the failure is not
          // permanent (e.g. missing repo.url for kubernetes sessions).
          // Return fallback so _completeSend can create a failed/pending
          // optimistic message that the user can retry, instead of throwing
          // before any message is persisted.
          logger.info(
            '[sendMessage] auto-restore failed for errored '
            'session=$sessionId error=$errorMsg; '
            'returning fallback so send can fail gracefully',
          );
          completer.complete(fallback);
          return fallback;
        }
        completer.complete(fallback);
        return fallback;
      }

      final restoredSessionId = result.sessionId;
      if (restoredSessionId == null || restoredSessionId.isEmpty) {
        logger.warning(
          '[sendMessage] auto-restore returned empty session id '
          'for requested=$sessionId',
        );
        throw StateError('Session not found: $sessionId — empty session id');
      }

      await _primeSessionFromSpawnResult(
        requestedSessionId: sessionId,
        restoredSessionId: restoredSessionId,
        seedSession: session,
        result: result,
      );
      if (lifecycleErrored && restoredSessionId == sessionId) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final restoredInPlace = _sessions[restoredSessionId];
        if (restoredInPlace != null) {
          final metadata = restoredInPlace.metadata;
          _sessions[restoredSessionId] = restoredInPlace.copyWith(
            metadata: (metadata ?? const Metadata(host: '')).copyWith(
              lifecycleState: 'starting',
              lifecycleStateError: null,
              lifecycleStateSince: now,
            ),
          );
        }
      }
      // Fall back to the requested profileId when the profile object couldn't
      // be resolved locally (e.g. profile sync hasn't completed yet). Storing
      // null here causes a null != profileId mismatch on the very next send,
      // which triggers an infinite kill-restore loop.
      // Register the spawn timestamp + metadata via the funnel helper so
      // wasRecentlySpawned returns true for the restored session. Without
      // this, the restored session has no grace period and is immediately
      // eligible for another profile/model kill.
      _registerSpawn(
        restoredSessionId,
        profileId: spawnResult.profile?.id ?? profileId,
        modelMode: effectiveModelMode,
        agent: sessionAgent,
      );
      if (restoredSessionId != sessionId) {
        // Migrate conversation history from the old session to the new
        // one so the user doesn't lose context after an auto-restore
        // redirect (e.g. after abort + respawn).
        final oldMessages = _sessionMessages[sessionId];
        if (oldMessages != null && oldMessages.isNotEmpty) {
          logger.info(
            '[sendMessage] migrating ${oldMessages.length} messages '
            'from $sessionId -> $restoredSessionId',
          );
          _sessionMessages[restoredSessionId] = List<Map<String, dynamic>>.from(
            oldMessages,
          );
          _rebuildSessionContentSignatures(restoredSessionId);
          _sessionMessagesViewCache.remove(restoredSessionId);
          if (_sessionsNeedingSidechainRegroup.contains(sessionId)) {
            _sessionsNeedingSidechainRegroup.add(restoredSessionId);
          }
          _sessionMessagesCache = null;
        }
        logger.info(
          '[sendMessage] auto-restore redirected session '
          '$sessionId -> $restoredSessionId',
        );
        // Keep the list fresh, but do not force a full /v2/sessions reload.
        sessionsSync.invalidate();
      }

      var restoredSession = _sessions[restoredSessionId];
      if (restoredSession == null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        restoredSession = Session(
          id: restoredSessionId,
          seq: 0,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadata: Metadata(
            host: session.metadata?.host ?? '',
            machineId: machineId,
            path: path,
            flavor: session.metadata?.flavor,
            lifecycleState: 'starting',
          ),
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
        );
        _sessions[restoredSessionId] = restoredSession;
        _notifyDataChanged({SyncDomain.sessions});
      }

      var restoredSessionEncryption = encryption.getSessionEncryption(
        restoredSessionId,
      );
      if (restoredSessionEncryption == null && restoredSessionId == sessionId) {
        restoredSessionEncryption = sessionEncryption;
      }
      if (restoredSessionEncryption == null) {
        await sessionsSync.invalidateAndAwait();
        restoredSessionEncryption = encryption.getSessionEncryption(
          restoredSessionId,
        );
      }
      if (restoredSessionEncryption == null) {
        // Encryption is permanently unavailable for this session — throw so
        // the message goes to outbox for retry, rather than sending to a
        // session we can't encrypt messages for.
        throw StateError('Session encryption not found: $restoredSessionId');
      }

      final restored = (
        sessionId: restoredSessionId,
        session: restoredSession,
        sessionEncryption: restoredSessionEncryption,
      );
      completer.complete(restored);
      return restored;
    } catch (error, stack) {
      restoreClearedSpawnTracking();
      // Transient network errors and unsupported RPC methods during
      // auto-restore are expected — log at info to avoid Sentry noise.
      if (Sync._isTransientRpcError(error) ||
          Sync._isRpcMethodNotAvailable(error)) {
        final reason = Sync._isRpcMethodNotAvailable(error)
            ? 'RPC unavailable'
            : Sync._isRpcReplicaTimeout(error)
            ? 'RPC replica timeout'
            : 'transient';
        logger.info(
          '[sendMessage] auto-restore failed ($reason) '
          'session=$sessionId: $error',
        );
      } else if (lifecycleErrored) {
        logger.warning(
          '[sendMessage] auto-restore failed for stopped '
          'session=$sessionId',
          error,
          stack,
        );
      } else if (error is StateError &&
          (error.message.contains('Session not found:') ||
              error.message.contains('Session encryption not found:') ||
              error.message.contains('empty session id'))) {
        // Session was permanently deleted on the server — an expected
        // user-facing condition, not a code defect.  Log at warning so
        // it doesn't mint a Sentry error event.
        logger.warning(
          '[sendMessage] auto-restore permanent session gone '
          'session=$sessionId',
          error,
          stack,
        );
      } else {
        logger.warning(
          '[sendMessage] auto-restore failed for '
          'session=$sessionId: $error',
        );
        // ROADMAP P0: this catch-all branch used to be invisible to
        // both Sentry and the user — the message was POSTed to a
        // broken session and the optimistic row vanished.  Capture
        // to Sentry, bump the app-level counter, and emit a
        // structured event so ChatScreen can show a snackbar and
        // flip the optimistic message's `sendStatus` to `'failed'`
        // (preserving `localId` for retry, per the core messaging
        // invariant).
        // `.catchError` swallows any async rejection from the Sentry SDK
        // (uninitialized SDK, dropped event, transport error) so the
        // catch-all branch can never leak an uncaught async error into
        // the host caller. Without this, tests that throw a StateError
        // from `testMachineRPCOverride` see the StateError re-emerge
        // from `unawaited(...)` even after the catch block completes.
        unawaited(
          Sentry.captureException(
            error,
            stackTrace: stack,
            hint: Hint.withMap({
              'context': 'sendMessage.autoRestore',
              'sessionId': sessionId,
            }),
          ).catchError((_) {
            // Test sinks + DSN-less environments must never propagate.
            return SentryId.empty();
          }),
        );
        // `_safeRecordAppError` returns void (counter bump is sync); do
        // not wrap in `unawaited(...)` — that requires a `Future`.
        _safeRecordAppError('app.auto_restore.failed');
        _safeEmitAutoRestoreFailure(
          AutoRestoreFailure(
            sessionId: sessionId,
            error: error,
            stack: stack,
            reason: 'unknown',
          ),
        );
      }
      if (lifecycleErrored) {
        final restoreError =
            error is StateError &&
                error.message.startsWith('Could not restore stopped session')
            ? error
            : StateError(
                'Could not restore stopped session $sessionId: $error',
              );
        if (!completer.isCompleted) {
          completer.complete(fallback);
        }
        Error.throwWithStackTrace(restoreError, stack);
      }
      if (!completer.isCompleted) {
        completer.complete(fallback);
      }
      return fallback;
    } finally {
      _profileModelKillInFlight.remove(sessionId);
      _autoRestoreInFlight.remove(sessionId);
      _autoRestoreCompleters.remove(sessionId);
      _autoRestoreProfileIds.remove(sessionId);
    }
  }
}
