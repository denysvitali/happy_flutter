part of 'sync_service.dart';

/// Reconstructs the backend for sessions created before backend metadata was
/// persisted. Explicit runtime metadata is authoritative. For legacy
/// repository-backed sessions, the checkout must also live under the
/// machine's advertised Kubernetes root; a repo URL alone is not proof that
/// the process ran in Kubernetes.
String _spawnBackendForExistingSession(Session session, Machine? machine) {
  final runtimeType = session.metadata?.runtimeKind?.trim().toLowerCase();
  if (runtimeType == 'kubernetes') return 'kubernetes';
  if (runtimeType == 'local' || runtimeType == 'process') return 'local';

  final repoUrl = session.metadata?.repoUrl?.trim();
  if (repoUrl == null || repoUrl.isEmpty) return 'local';
  final advertisedBackends = machine?.metadata?.spawnBackends;
  if (advertisedBackends != null &&
      advertisedBackends.isNotEmpty &&
      !advertisedBackends.contains('kubernetes')) {
    return 'local';
  }

  final advertisedRoot = machine?.metadata?.kubernetesCheckoutBaseDir?.trim();
  final checkoutRoot = advertisedRoot != null && advertisedRoot.isNotEmpty
      ? advertisedRoot
      : '/workspace';
  return _isPathWithinDirectory(session.metadata?.path, checkoutRoot)
      ? 'kubernetes'
      : 'local';
}

bool _isPathWithinDirectory(String? candidate, String root) {
  final normalizedCandidate = _normalizeAbsolutePosixPath(candidate);
  final normalizedRoot = _normalizeAbsolutePosixPath(root);
  if (normalizedCandidate == null || normalizedRoot == null) return false;
  if (normalizedRoot == '/') return true;
  return normalizedCandidate == normalizedRoot ||
      normalizedCandidate.startsWith('$normalizedRoot/');
}

String? _normalizeAbsolutePosixPath(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty || !value.startsWith('/')) return null;
  final segments = <String>[];
  for (final segment in value.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isEmpty) return null;
      segments.removeLast();
      continue;
    }
    segments.add(segment);
  }
  return segments.isEmpty ? '/' : '/${segments.join('/')}';
}

Metadata _metadataWithSpawnResult(
  Metadata metadata,
  SpawnSessionResponse result,
) {
  final hasSandboxState =
      result.sandboxRequested != null ||
      result.sandboxRequired != null ||
      result.sandboxEnforced != null ||
      result.sandboxBackend != null;
  return metadata.copyWith(
    runtimeKind:
        result.runtimeKind ??
        (result.sandboxBackend == 'kubernetes'
            ? 'kubernetes'
            : metadata.runtimeKind),
    podName: result.podName ?? metadata.podName,
    namespace: result.namespace ?? metadata.namespace,
    podPhase: result.phase ?? metadata.podPhase,
    podReady: result.phase?.toLowerCase() == 'running'
        ? true
        : metadata.podReady,
    lifecycleState: result.phase?.toLowerCase() == 'running'
        ? 'running'
        : metadata.lifecycleState,
    sandboxRequested: result.sandboxRequested ?? metadata.sandboxRequested,
    sandboxRequired: result.sandboxRequired ?? metadata.sandboxRequired,
    sandboxEnforced: result.sandboxEnforced ?? metadata.sandboxEnforced,
    sandboxBackend: result.sandboxBackend ?? metadata.sandboxBackend,
    sandboxReason: hasSandboxState
        ? result.sandboxReason
        : metadata.sandboxReason,
  );
}

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

    /// Repository clone target for container-backed runtimes.
    String? repoUrl,
    String? repoRef,
    String? repoCommit,
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
    final normalizedModelMode = _normalizeModelModeForAgent(
      modelMode,
      agent,
      profile: selectedProfile,
    );
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
    final envVars = _spawnEnvForModel(
      _spawnEnvironmentVariables(profileEnvVars),
      agent: agent,
      profile: spawnProfileResolution.profile,
      modelMode: effectiveModelMode,
    );
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
      repoUrl: repoUrl,
      repoRef: repoRef,
      repoCommit: repoCommit,
      environmentVariables: envVars,
    );

    logger.info(
      '[createSession] START machine=$machineId '
      'session=$requestedSessionId '
      'agent=$agent model=$effectiveModelMode '
      'path=$resolvedPath hasRepo=${repoUrl?.isNotEmpty ?? false} '
      'hasInitialMessage=${message?.isNotEmpty ?? false}',
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
    } on SocketNotConnectedException catch (error, stack) {
      // Socket can drop between the pre-check wait and the long spawn RPC
      // (esp. after worktree creation). Wait once more then retry.
      logger.warning(
        '[createSession] socket dropped before spawn RPC; '
        'reconnecting and retrying once: $error',
        error,
        stack,
      );
      final reconnected = await socketIoClient.waitForConnection(
        timeout: const Duration(seconds: 8),
      );
      if (!reconnected) {
        throw StateError('Not connected to server');
      }
      result = await _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson(),
        SpawnSessionResponse.fromJson,
        timeout: const Duration(seconds: 60),
      );
      logger.info(
        '[createSession] RPC END (retry) type=${result.type} '
        'elapsedMs=${rpcStopwatch.elapsedMilliseconds}',
      );
    } catch (error, stack) {
      final elapsedMs = rpcStopwatch.elapsedMilliseconds;
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'createSession spawn RPC failed',
            category: 'session.create',
            level: SentryLevel.warning,
            data: {
              'machineId': machineId,
              'sessionId': requestedSessionId,
              'spawnBackend': spawnBackend ?? 'default',
              'elapsedMs': elapsedMs,
              'error': error.toString(),
            },
          ),
        ),
      );
      // The dialog boundary emits the one GlitchTip warning after it has
      // converted the failure to user-visible state. Keep the detailed RPC
      // line local; the breadcrumb above carries this context into that event.
      logger.info('[createSession] spawn RPC failed', error, stack);
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

      final hydratedSession = _sessions[sessionId];
      final hydratedMetadata = hydratedSession?.metadata;
      if (hydratedSession != null && hydratedMetadata != null) {
        _sessions[sessionId] = hydratedSession.copyWith(
          metadata: _metadataWithSpawnResult(hydratedMetadata, result),
        );
      }

      if (!_sessions.containsKey(sessionId)) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _sessions[sessionId] = Session(
          id: sessionId,
          seq: 0,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadata: _metadataWithSpawnResult(
            Metadata(
              host: '',
              machineId: machineId,
              path: resolvedPath,
              flavor: agent,
              lifecycleState: 'starting',
              runtimeKind: spawnBackend,
              repoUrl: repoUrl,
              repoRef: repoRef,
              repoCommit: repoCommit,
              podName: result.podName,
              namespace: result.namespace,
              podPhase: result.phase,
            ),
            result,
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
        repoUrl: repoUrl,
        repoRef: repoRef,
        repoCommit: repoCommit,
      );
    }

    final errorMsg = result.errorMessage ?? 'unknown error';

    // The daemon waits 15 s for the agent's startup webhook before returning
    // an error.  The agent often connects to the server ~2 s after that
    // deadline, so the session IS created even though the RPC returned an
    // error. Retry once: wait briefly, force a full session refresh, then
    // recover only the exact client-generated ID sent in the spawn request.
    // A path is not an identity: another user or concurrent request can
    // legitimately create a newer session in the same directory.
    if (errorMsg.contains('webhook timeout')) {
      logger.info(
        '[createSession] spawn webhook timeout for '
        'machine=$machineId path=$resolvedPath — waiting for late session',
      );
      await Future<void>.delayed(
        Sync.testWebhookTimeoutRecoveryDelayOverride ??
            const Duration(seconds: 5),
      );
      _forceFullFetchNext = true;
      await refreshSessions();

      final found = _sessions[requestedSessionId];
      if (found != null) {
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
        '[createSession] requested session not found after webhook timeout '
        'retry session=$requestedSessionId machine=$machineId '
        'path=$resolvedPath',
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
    final retryDelays =
        Sync.testSpawnHydrateRetryDelaysOverride ??
        const <Duration>[
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
