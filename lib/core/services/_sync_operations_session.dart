part of 'sync_service.dart';

extension SyncSessionOperations on Sync {
  /// Create a session on a target machine/path and return the new session ID.
  /// Sends a `spawn-happy-session` RPC to the machine daemon, which starts a
  /// new Claude Code agent in [path].  If the directory does not yet exist the
  /// daemon returns a `requestToApproveDirectoryCreation` result; passing
  /// [approvedNewDirectoryCreation] = true tells it to create the directory.
  /// The active profile's environment variables (API keys, model config, etc.)
  /// and the last-used agent type are automatically read from settings and
  /// forwarded to the daemon so it can configure the agent correctly.
  /// Throws a [StateError] with a human-readable message on failure.
  Future<String> createSession({
    required String machineId,
    required String path,

    /// Explicit agent type for this session. Takes precedence over
    /// [settingsSnapshot.lastUsedAgent]. Should always be passed when creating
    /// a session so the correct agent is used, rather than relying on
    /// [lastUsedAgent] which can change between applySettings and createSession
    /// due to async settings sync reloads.
    required String agent,
    bool approvedNewDirectoryCreation = false,
    String? sessionId,

    /// Explicit profile ID for this session. Takes precedence over
    /// [settingsSnapshot.lastUsedProfile]. Should be passed when creating a
    /// session so the correct profile env vars are used, rather than relying
    /// on [lastUsedProfile] which can change over time.
    String? profileId,

    /// Optional initial message to pipe directly to the agent's stdin
    /// on startup via the HAPPY_INITIAL_PROMPT env var.  Bypasses the
    /// WebSocket message chain which is unreliable for the very first
    /// message on freshly-spawned sessions.
    String? message,

    /// Explicit model mode for this session. When not 'default', passed to
    /// the daemon via --model so it writes the model into session metadata.
    /// Used to detect model changes and respawn the session automatically.
    String? modelMode,

    /// Optional daemon spawn backend. When omitted, the daemon uses its
    /// configured default.
    String? spawnBackend,
  }) async {
    final createStopwatch = Stopwatch()..start();
    if (!isInitialized) {
      throw StateError('Sync is not initialized');
    }
    if (InvalidateSync.isBackgrounded) {
      throw StateError('Not connected to server');
    }
    final requestedSessionId = sessionId ?? _createClientSessionId();
    // Check socket connectivity.  When the test override is set, use it
    // directly (supports true/false).  Otherwise, wait for the socket to
    // connect instead of failing immediately — during brief disconnects
    // the socket may be reconnecting and will be available within seconds.
    final socketOverride = testSocketConnectedOverride;
    if (socketOverride != null) {
      if (!socketOverride) {
        throw StateError('Not connected to server');
      }
    } else {
      final connected = await socketIoClient.waitForConnection(
        timeout: const Duration(seconds: 5),
      );
      if (!connected) {
        throw StateError('Not connected to server');
      }
    }
    if (InvalidateSync.isBackgrounded) {
      throw StateError('Not connected to server');
    }

    // Fail fast if the machine is offline — don't wait 60 s for a timeout.
    //
    // The server marks machines inactive after 10 min without a heartbeat.
    // We use a 2 min activeAt threshold so that clock skew and the server's
    // 30 s activity-cache throttle don't cause false positives (the old 60 s
    // threshold matched the daemon HTTP heartbeat exactly).  When the server
    // has explicitly set active=false we reject immediately regardless of
    // activeAt.
    final machine = _machines[machineId];
    if (machine != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!machine.isOnlineAt(now)) {
        // Rate-limit the warning to once per machine per 60 seconds.
        if (machine.isStaleAt(now)) {
          final lastWarnedAt = _machineOfflineWarnedAtMs[machineId] ?? 0;
          if (now - lastWarnedAt > 60000) {
            _machineOfflineWarnedAtMs[machineId] = now;
            // Keep absolute timestamps out of the primary message so
            // GlitchTip groups all offline machines under one issue
            // rather than minting a new issue for every (activeAt, now)
            // pair.
            final deltaSec = ((now - machine.activeAt) / 1000).round();
            logger.warning(
              'Machine appears offline '
              '(machineId=$machineId, delta=${deltaSec}s)',
            );
          }
        }
        throw StateError('Machine is offline');
      }
    }

    // A fresh heartbeat doesn't guarantee the daemon will answer RPCs —
    // probe with a short ping so a wedged daemon fails in seconds
    // instead of eating the full 60 s spawn timeout.
    await ensureMachineReachable(machineId);

    final resolvedPath = (machine != null && machine.metadata?.homeDir != null)
        ? resolveAbsolutePath(path, homeDir: machine.metadata!.homeDir)
        : path;

    // Agent is explicitly passed as a parameter to avoid race conditions with
    // async settings sync reloads overwriting settingsSnapshot.lastUsedAgent.
    // Use explicit profileId if provided, otherwise fall back to the
    // profile last used for this agent.
    final selectedProfileId =
        profileId ?? resolveSelectedProfileIdForAgent(settingsSnapshot, agent);
    final selectedProfile = selectedProfileId != null
        ? _resolveProfile(selectedProfileId)
        : null;
    final normalizedModelMode = _normalizeModelModeForAgent(modelMode, agent);
    final spawnProfileResolution = _resolveEffectiveProfileForSpawn(
      profile: selectedProfile,
      modelMode: normalizedModelMode,
      agent: agent,
    );
    final effectiveProfileId = spawnProfileResolution.profile != null
        ? selectedProfileId
        : null;
    final effectiveModelMode = spawnProfileResolution.modelMode;
    // Cold-start optimization: API keys live in secure storage and are
    // hydrated on demand. Hydrate the selected profile now so its
    // `apiKey` fields are populated before we build the env vars.
    final hydratedProfile = spawnProfileResolution.profile != null
        ? await _hydrateProfileForSpawn(spawnProfileResolution.profile!)
        : null;
    final profileEnvVars = hydratedProfile != null
        ? _profileEnvironmentVariables(hydratedProfile)
        : null;
    final permMode =
        spawnProfileResolution.profile?.defaultPermissionMode ??
        settingsSnapshot.lastUsedPermissionMode;
    final envVars = _spawnEnvironmentVariables(profileEnvVars);
    if (message != null && message.isNotEmpty) {
      envVars['HAPPY_INITIAL_PROMPT'] = message;
    }
    final req = SpawnSessionRequest(
      type: 'spawn-in-directory',
      directory: resolvedPath,
      sessionId: requestedSessionId,
      approvedNewDirectoryCreation: true, // Always approve like React Native
      agent: agent,
      permissionMode: permMode,
      model: _getModelOverride(
        agent: agent,
        profile: spawnProfileResolution.profile,
        modelMode: effectiveModelMode,
      ),
      spawnBackend: spawnBackend,
      environmentVariables: envVars,
    );

    logger.info(
      '[createSession] START machine=$machineId '
      'session=$requestedSessionId '
      'agent=$agent model=$effectiveModelMode '
      'path=$resolvedPath hasInitialMessage=${message?.isNotEmpty ?? false}',
    );

    late final SpawnSessionResponse result;
    final rpcStopwatch = Stopwatch()..start();
    try {
      result = await _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson(),
        SpawnSessionResponse.fromJson,
        timeout: const Duration(seconds: 60),
      );
      logger.info(
        '[createSession] RPC END type=${result.type} '
        'elapsedMs=${rpcStopwatch.elapsedMilliseconds}',
      );
    } catch (error, stack) {
      logger.warning(
        '[createSession] RPC FAILED '
        'elapsedMs=${rpcStopwatch.elapsedMilliseconds}: $error',
        error,
        stack,
      );
      rethrow;
    }

    if (result.type == 'success') {
      final sessionId = result.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        throw StateError('Machine returned empty session ID');
      }

      // Initialize encryption from the DEK included in the spawn response,
      // avoiding the sync race condition where delta fetches miss the new
      // session's dataEncryptionKey.
      final dek = result.dataEncryptionKey;
      if (dek != null && dek.isNotEmpty) {
        final decryptedKey = await encryption.decryptEncryptionKey(dek);
        if (decryptedKey != null) {
          await _ensureSessionEncryptionInitialized(sessionId, decryptedKey);
        }
      }
      _registerSpawn(
        sessionId,
        profileId: effectiveProfileId,
        modelMode: effectiveModelMode,
        agent: agent,
      );
      logger.info(
        '[createSession] Registered session $sessionId '
        'in _sessionSpawnedAt '
        '(profile=$effectiveProfileId, '
        'model=$effectiveModelMode, agent=$agent)',
      );

      await _hydrateSpawnedSession(
        sessionId,
        machineId: machineId,
        path: resolvedPath,
      );

      if (!_sessions.containsKey(sessionId)) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _sessions[sessionId] = Session(
          id: sessionId,
          seq: 0,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadata: Metadata(
            host: '',
            machineId: machineId,
            path: resolvedPath,
            flavor: agent,
            lifecycleState: 'starting',
          ),
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
        );
      }
      _flushDataChanged();

      if (!messagesSync.containsKey(sessionId)) {
        unawaited(onSessionVisible(sessionId));
      }

      if (message != null && message.isNotEmpty) {
        _upsertSessionMessages(sessionId, [
          <String, dynamic>{
            'id': 'initial-${DateTime.now().millisecondsSinceEpoch}',
            'seq': 0,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'role': 'user',
            'kind': 'text',
            'content': message,
            'sendStatus': 'sending',
          },
        ]);
        _notifySessionMessagesChanged(sessionId);
      }

      logger.info(
        '[createSession] END session=$sessionId '
        'elapsedMs=${createStopwatch.elapsedMilliseconds}',
      );
      return sessionId;
    }

    if (result.type == 'requestToApproveDirectoryCreation') {
      return createSession(
        machineId: machineId,
        path: resolvedPath,
        approvedNewDirectoryCreation: true,
        sessionId: requestedSessionId,
        agent: agent,
        profileId: profileId,
        message: message,
        modelMode: modelMode,
        spawnBackend: spawnBackend,
      );
    }

    final errorMsg = result.errorMessage ?? 'unknown error';

    // The daemon waits 15 s for the agent's startup webhook before returning
    // an error.  The agent often connects to the server ~2 s after that
    // deadline, so the session IS created even though the RPC returned an
    // error.  Retry once: wait briefly, force a full session refresh, then
    // look for a recently-created session on this machine + path.
    if (errorMsg.contains('webhook timeout')) {
      logger.info(
        '[createSession] spawn webhook timeout for '
        'machine=$machineId path=$resolvedPath — waiting for late session',
      );
      await Future<void>.delayed(const Duration(seconds: 5));
      _forceFullFetchNext = true;
      await refreshSessions();

      final now = DateTime.now().millisecondsSinceEpoch;
      final candidates = _sessions.values.where((s) {
        final ageMs = now - s.createdAt;
        final matchesMachineId = s.metadata?.machineId == machineId;
        final matchesPath = s.metadata?.path == resolvedPath;
        final recent = ageMs < 90000;
        final isMatch = matchesMachineId && matchesPath && recent;
        if (matchesPath && ageMs < 120000) {
          logger.info(
            '[createSession] checking session ${s.id}: '
            'machineId=${s.metadata?.machineId} '
            '(matches=$matchesMachineId) '
            'path=${s.metadata?.path} '
            '(matches=$matchesPath) '
            'age=${(ageMs / 1000).toStringAsFixed(1)}s '
            '(recent=$recent) '
            'isMatch=$isMatch',
          );
        }
        return isMatch;
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      logger.info(
        '[createSession] found ${candidates.length} candidate sessions '
        'matching machine=$machineId path=$resolvedPath',
      );

      if (candidates.isNotEmpty) {
        final found = candidates.first;
        logger.info(
          '[createSession] recovered session ${found.id} '
          'after webhook timeout',
        );
        // Anchor on the server-reported createdAt so the recently-spawned
        // window aligns with the actual spawn moment rather than the local
        // clock at recovery time.
        _registerSpawn(
          found.id,
          profileId: effectiveProfileId,
          at: DateTime.fromMillisecondsSinceEpoch(found.createdAt),
        );
        _notifyDataChanged({SyncDomain.sessions});
        return found.id;
      }

      logger.warning(
        '[createSession] session not found after webhook timeout '
        'retry machine=$machineId path=$resolvedPath',
      );
    }

    throw StateError(errorMsg);
  }

  String _createClientSessionId() {
    final random = Random.secure();
    const alphabet = '0123456789abcdef';
    final chars = StringBuffer('c');
    for (var i = 0; i < 24; i++) {
      chars.write(alphabet[random.nextInt(alphabet.length)]);
    }
    return chars.toString();
  }

  Future<void> _hydrateSpawnedSession(
    String sessionId, {
    required String machineId,
    required String path,
  }) async {
    const retryDelays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 250),
      Duration(milliseconds: 750),
    ];

    for (final delay in retryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      final session = await fetchSingleSession(sessionId);
      if (session != null) {
        logger.info(
          '[createSession] hydrated spawned session $sessionId '
          'via fetchSingleSession',
        );
        return;
      }
    }

    logger.info(
      '[createSession] session $sessionId not yet visible via '
      'fetchSingleSession; keeping optimistic placeholder '
      '(machine=$machineId path=$path)',
    );

    // Kick a delta refresh in the background so the list reconciles shortly
    // after the optimistic insert without blocking the create flow.
    sessionsSync.invalidate();
  }

  /// Execute a bash command on a machine.
  Future<BashResponse> machineBash({
    required String machineId,
    required String command,
    required String cwd,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'bash',
        BashRequest(command: command, cwd: cwd).toJson(),
        BashResponse.fromJson,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineBash: socket not connected');
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('machineBash: transient RPC failure — $error');
      } else {
        logger.error('machineBash error', error, stackTrace);
      }
    }
    return const BashResponse(success: false, stderr: 'RPC call failed');
  }

  /// Read a file from a machine via encrypted RPC.
  Future<ReadFileResponse> machineReadFile({
    required String machineId,
    required String filePath,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'readFile',
        ReadFileRequest(path: filePath).toJson(),
        ReadFileResponse.fromJson,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineReadFile: socket not connected');
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineReadFile: RPC method not available '
          '(daemon too old) — $error',
        );
        return const ReadFileResponse(
          success: false,
          error: 'File viewing requires a newer machine agent',
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('machineReadFile: transient RPC failure — $error');
      } else {
        logger.error('machineReadFile error', error, stackTrace);
      }
    }
    return const ReadFileResponse(success: false, error: 'RPC call failed');
  }

  /// Fetch Claude Code usage limits from a machine via encrypted RPC.
  /// The machine daemon reads `~/.claude/.credentials.json` and calls the
  /// Anthropic OAuth usage API, returning the raw JSON payload.
  Future<ClaudeUsageLimitsResponse> machineGetClaudeUsageLimits({
    required String machineId,
  }) async {
    try {
      // HAPPY_FLUTTER-3D5: usage limits is a UI-blocking call from
      // claude_limits_screen. The 30s default machineRPC timeout
      // burned the user out of patience 10× in 2 days — every
      // failure pinned the screen on a spinner for 30s. 15s is
      // well over the 3.2s p99 we see for healthy daemons (the
      // SLOW get-codex-models breadcrumb for this same user) and
      // bounded enough that a stuck daemon doesn't lock the user
      // out of the screen.
      return await _typedMachineRPC(
        machineId,
        'get-claude-usage-limits',
        <String, dynamic>{},
        ClaudeUsageLimitsResponse.fromJson,
        timeout: const Duration(seconds: 15),
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetClaudeUsageLimits: machine offline');
        return const ClaudeUsageLimitsResponse(
          success: false,
          error: 'machine offline',
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetClaudeUsageLimits: RPC method not available '
          '(daemon too old)',
        );
        return const ClaudeUsageLimitsResponse(
          success: false,
          error: 'RPC method not available',
        );
      } else if (Sync._isTransientRpcError(error)) {
        // Daemon flakiness, not a client bug — log at info so we
        // still get the breadcrumb without inflating the warning
        // count. The screen handles the error in its UI.
        logger.info(
          'machineGetClaudeUsageLimits: transient RPC failure — $error',
        );
      } else {
        logger.error('machineGetClaudeUsageLimits error', error, stackTrace);
      }
    }
    return const ClaudeUsageLimitsResponse(
      success: false,
      error: 'RPC call failed',
    );
  }

  /// Fetch aggregated local Claude Code token usage (lifetime + per-day
  /// per-model) scraped from `~/.claude/stats-cache.json` on the machine.
  /// Distinct from [machineGetClaudeUsageLimits] which is the OAuth
  /// rate-limit response (5-hour/7-day windows as percentages).
  Future<ClaudeLocalUsageResponse> machineGetClaudeLocalUsage({
    required String machineId,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'get-claude-local-usage',
        <String, dynamic>{},
        ClaudeLocalUsageResponse.fromJson,
        timeout: const Duration(seconds: 15),
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetClaudeLocalUsage: machine offline');
        return const ClaudeLocalUsageResponse(
          success: false,
          error: 'machine offline',
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetClaudeLocalUsage: RPC method not available '
          '(daemon too old)',
        );
        return const ClaudeLocalUsageResponse(
          success: false,
          error: 'RPC method not available',
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info(
          'machineGetClaudeLocalUsage: transient RPC failure — $error',
        );
      } else {
        logger.error('machineGetClaudeLocalUsage error', error, stackTrace);
      }
    }
    return const ClaudeLocalUsageResponse(
      success: false,
      error: 'RPC call failed',
    );
  }

  /// Fetch the Codex model catalog from the machine's installed Codex CLI.
  Future<CodexModelsResponse> machineGetCodexModels({
    required String machineId,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'get-codex-models',
        <String, dynamic>{},
        CodexModelsResponse.fromJson,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetCodexModels: machine offline');
        return const CodexModelsResponse(
          success: false,
          models: [],
          error: 'machine offline',
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetCodexModels: RPC method not available '
          '(daemon too old)',
        );
        return const CodexModelsResponse(
          success: false,
          models: [],
          error: 'RPC method not available',
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('machineGetCodexModels: transient RPC failure — $error');
      } else {
        logger.error('machineGetCodexModels error', error, stackTrace);
      }
    }
    return const CodexModelsResponse(
      success: false,
      models: [],
      error: 'RPC call failed',
    );
  }

  /// Fetch Codex usage data from the machine's local Codex auth state.
  Future<CodexUsageSummaryResponse> machineGetCodexUsage({
    required String machineId,
  }) async {
    final machine = _machines[machineId];
    final cwd = machine?.metadata?.homeDir ?? '/';
    const codexUsageBashScript = r"""
python3 <<'PY'
import json
import os
import urllib.error
import urllib.request


def fail(message):
    print(json.dumps({'success': False, 'error': message}))
    raise SystemExit(0)


try:
    with open(os.path.expanduser('~/.codex/auth.json'), 'r',
              encoding='utf-8') as auth_file:
        auth = json.load(auth_file)
except Exception as exc:
    fail(f'Failed to read Codex auth.json: {exc}')

def find_access_token(value):
    if isinstance(value, dict):
        preferred_keys = (
            'accessToken',
            'access_token',
            'token',
            'idToken',
            'id_token',
        )
        for key in preferred_keys:
            token = value.get(key)
            if isinstance(token, str) and token:
                return token
        for nested in value.values():
            token = find_access_token(nested)
            if token:
                return token
    elif isinstance(value, list):
        for nested in value:
            token = find_access_token(nested)
            if token:
                return token
    return None


access_token = find_access_token(auth)
if not access_token:
    fail('No Codex access token found in auth.json')

request = urllib.request.Request(
    'https://chatgpt.com/backend-api/wham/usage',
    headers={
        'Authorization': f'Bearer {access_token}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'codex-cli',
    },
)

try:
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.loads(response.read().decode('utf-8'))
except urllib.error.HTTPError as exc:
    body = exc.read().decode('utf-8', errors='replace')
    fail(f'Codex usage request failed ({exc.code}): {body}')
except Exception as exc:
    fail(f'Failed to fetch Codex usage: {exc}')

if isinstance(payload, dict) and isinstance(payload.get('data'), dict):
    payload = payload['data']

if not isinstance(payload, dict):
    fail('Codex usage response was not an object')

print(json.dumps({'success': True, 'data': payload}))
PY
""";

    CodexUsageSummaryResponse parseRpcResponse(Map<String, dynamic> raw) {
      final data = raw.containsKey('data') ? raw['data'] : raw;
      final summary = data is Map<String, dynamic>
          ? CodexUsageSummary.fromJson(data)
          : data is Map
          ? CodexUsageSummary.fromJson(Map<String, dynamic>.from(data))
          : null;
      final hasSummary = summary?.hasUsageData ?? false;
      return CodexUsageSummaryResponse(
        success: raw['success'] == true || hasSummary,
        data: hasSummary ? summary : null,
        error: raw['error'] as String?,
      );
    }

    Future<CodexUsageSummaryResponse> fetchFromBash() async {
      final response = await machineBash(
        machineId: machineId,
        command: codexUsageBashScript,
        cwd: cwd,
      );

      if (!response.success) {
        return CodexUsageSummaryResponse(
          success: false,
          error: response.stderr.isNotEmpty ? response.stderr : response.error,
        );
      }

      try {
        final raw = jsonDecode(response.stdout) as Map<String, dynamic>;
        final success = raw['success'] == true;
        final data = raw['data'] ?? raw;
        final summary = data is Map<String, dynamic>
            ? CodexUsageSummary.fromJson(data)
            : data is Map
            ? CodexUsageSummary.fromJson(Map<String, dynamic>.from(data))
            : null;
        final hasSummary = summary?.hasUsageData ?? false;
        if (!success) {
          return CodexUsageSummaryResponse(
            success: false,
            error: raw['error'] as String?,
          );
        }
        return CodexUsageSummaryResponse(
          success: true,
          data: hasSummary ? summary : null,
          error: raw['error'] as String?,
        );
      } catch (error, stackTrace) {
        logger.error('machineGetCodexUsage parse error', error, stackTrace);
        return const CodexUsageSummaryResponse(
          success: false,
          error: 'Failed to parse Codex usage response',
        );
      }
    }

    try {
      final response = await _typedMachineRPC(
        machineId,
        'get-codex-usage',
        <String, dynamic>{},
        parseRpcResponse,
        timeout: const Duration(seconds: 20),
      );
      if (!response.success) {
        return response;
      }
      if (response.data == null) {
        return const CodexUsageSummaryResponse(
          success: false,
          error: 'Codex usage data missing',
        );
      }
      return response;
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetCodexUsage: machine offline');
        return const CodexUsageSummaryResponse(
          success: false,
          error: 'machine offline',
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetCodexUsage: RPC method not available '
          '(daemon too old); falling back to machineBash',
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('machineGetCodexUsage: transient RPC failure — $error');
      } else {
        logger.error('machineGetCodexUsage RPC error', error, stackTrace);
      }
    }

    return fetchFromBash();
  }

  /// Create a git worktree on a machine under `.dev/worktree/<name>`
  /// relative to [basePath] and return the absolute path to the new
  /// worktree.  Mirrors React Native's `createWorktree` utility.
  /// Throws [StateError] if [basePath] is not a git repository or the
  /// worktree creation fails after retries.
  Future<String> createWorktree({
    required String machineId,
    required String basePath,
  }) async {
    final machine = _machines[machineId];
    final resolvedBasePath = (machine?.metadata?.homeDir != null)
        ? resolveAbsolutePath(basePath, homeDir: machine!.metadata!.homeDir)
        : basePath;

    final gitCheck = await machineBash(
      machineId: machineId,
      command: 'git rev-parse --git-dir',
      cwd: resolvedBasePath,
    );
    if (!gitCheck.success) {
      throw StateError('Not a Git repository');
    }

    final name = _generateWorktreeName();
    final worktreePath = '.dev/worktree/$name';
    var result = await machineBash(
      machineId: machineId,
      command: 'git worktree add -b $name $worktreePath',
      cwd: resolvedBasePath,
    );
    if (result.success) {
      return '$resolvedBasePath/$worktreePath';
    }

    if (result.stderr.contains('already exists')) {
      for (var i = 2; i <= 4; i++) {
        final newName = '$name-$i';
        final newPath = '.dev/worktree/$newName';
        result = await machineBash(
          machineId: machineId,
          command: 'git worktree add -b $newName $newPath',
          cwd: resolvedBasePath,
        );
        if (result.success) {
          return '$resolvedBasePath/$newPath';
        }
      }
    }

    throw StateError(
      result.stderr.isNotEmpty ? result.stderr : 'Failed to create worktree',
    );
  }

  String _generateWorktreeName() {
    final rand = Random();
    final adjs = Sync._worktreeAdjectives;
    final nouns = Sync._worktreeNouns;
    final adj = adjs[rand.nextInt(adjs.length)];
    final noun = nouns[rand.nextInt(nouns.length)];
    return '$adj-$noun';
  }

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
        '[createSession] profile ${profile.id} is not compatible with '
        'agent=$agent; spawning without profile env vars',
      );
      return (profile: null, modelMode: modelMode);
    }
    final baseUrl = _anthropicBaseUrlForProfile(profile);
    if (agent == 'claude' &&
        _isClaudeModelAlias(modelMode ?? '') &&
        _isThirdPartyAnthropicBaseUrl(baseUrl)) {
      logger.warning(
        '[createSession] dropping incompatible Claude model override '
        'profile=${profile.id} modelMode=$modelMode baseUrl=$baseUrl',
      );
      return (profile: profile, modelMode: 'default');
    }
    if (agent == 'codex') {
      final profileModelMode = _codexModelModeForProfile(profile);
      if (profileModelMode != null && profileModelMode != modelMode) {
        logger.info(
          '[createSession] using Codex profile model '
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

  String? _normalizeModelModeForAgent(String? modelMode, String? agent) {
    if (modelMode == null || modelMode == 'default') {
      return modelMode;
    }
    if (agent != 'claude' && _isClaudeModelAlias(modelMode)) {
      return 'default';
    }
    // The reverse direction: Codex/Gemini-style names from a previous
    // session must not leak into Claude spawns — Claude CLI rejects them
    // with "There's an issue with the selected model ... Run --model to
    // pick a different model." `lastUsedModelMode` is a global preference,
    // not per-agent, so the stale value survives a profile switch.
    if (agent == 'claude' && _isNonClaudeModelMode(modelMode)) {
      return 'default';
    }
    return modelMode;
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

  String _extractDefaultEnvValue(String value) {
    final match = RegExp(r'^\$\{[^:}]+:-(.*)\}$').firstMatch(value);
    return match?.group(1) ?? value;
  }

  /// Recognize known non-Claude model identifiers so they can be stripped
  /// from Claude spawns. Conservative on purpose: Claude-compatible
  /// providers (e.g. GLM, MiniMax) use arbitrary model names that we want
  /// to preserve, so we only match patterns that are definitely Codex or
  /// Gemini.
  bool _isNonClaudeModelMode(String modelMode) {
    // OpenAI / Azure OpenAI models from Codex profiles.
    if (modelMode.startsWith('gpt-')) return true;
    // Gemini models.
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
  /// sessions, or null to let the daemon/profile default apply.
  /// When [modelMode] is explicitly set (not null and not 'default'),
  /// pass it so the daemon writes it into session metadata for tracking.
  String? _getModelOverride({
    String? agent,
    AIBackendProfile? profile,
    String? modelMode,
  }) {
    final effectiveAgent = agent ?? _agentForProfile(profile);
    final normalized = _normalizeModelModeForAgent(modelMode, effectiveAgent);
    if (normalized != null && normalized != 'default') {
      return normalized;
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
    final modelChanged =
        modelMode != null &&
        modelMode != 'default' &&
        _sessionSpawnedModel.containsKey(sessionId) &&
        spawnedModel != null &&
        spawnedModel != 'default' &&
        spawnedModel != modelMode;

    final looksReady = health.looksReady;
    final onlineTrusted = health.isOnlineTrusted;

    final lifecycleState = session.effectiveLifecycleState;
    final lifecycleErrored = lifecycleState == 'errored';
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
          // new profile/model instead of re-using the old one. Do not call the
          // session-level killSession RPC here: that marks the stop deliberate
          // and can strand the message if the kill races the new send. The
          // machine spawn RPC owns replacement and kills the old process before
          // starting the new one.
          _sessionSpawnedAt.remove(sessionId);
          _sessionSpawnedProfile.remove(sessionId);
          _sessionSpawnedModel.remove(sessionId);
          _sessionSpawnedAgent.remove(sessionId);
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
      final req = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: path,
        sessionId: sessionId,
        agent: sessionAgent,
        permissionMode: effectivePermissionMode,
        model: _getModelOverride(
          agent: sessionAgent,
          profile: spawnResult.profile,
          modelMode: modelMode,
        ),
        environmentVariables: spawnResult.envVars,
      );
      final result = await _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson(),
        SpawnSessionResponse.fromJson,
        timeout: const Duration(seconds: 60),
      );
      if (result.type != 'success') {
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
        modelMode: modelMode,
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
        logger.error(
          '[sendMessage] auto-restore failed for '
          'session=$sessionId',
          error,
          stack,
        );
        // ROADMAP P0: this catch-all branch used to be invisible to
        // both Sentry and the user — the message was POSTed to a
        // broken session and the optimistic row vanished.  Capture
        // to Sentry, bump the app-level counter, and emit a
        // structured event so ChatScreen can show a snackbar and
        // flip the optimistic message's `sendStatus` to `'failed'`
        // (preserving `localId` for retry, per the core messaging
        // invariant).
        unawaited(
          Sentry.captureException(
            error,
            stackTrace: stack,
            hint: Hint.withMap({
              'context': 'sendMessage.autoRestore',
              'sessionId': sessionId,
            }),
          ),
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

  String _spawnedValueChange({
    required bool profileChanged,
    required String sessionId,
    required String? profileId,
    required String? modelMode,
  }) {
    if (profileChanged) {
      return '(${_sessionSpawnedProfile[sessionId]} -> $profileId)';
    }
    return '(${_sessionSpawnedModel[sessionId]} -> $modelMode)';
  }
}
