part of 'sync_service.dart';

/// Apply pending provider/model intent before choosing a delivery target.
extension SyncSendTargetResolution on Sync {
  bool _processScopedSessionStopped(String sessionId, Session session) {
    final health = SyncHealth(
      session: session,
      sessionSpawnedAt: _sessionSpawnedAt,
      lastEphemeralAt: _lastEphemeralAt,
    );
    return session.archived ||
        session.hasLifecycleError ||
        const {
          'exited',
          'stopped',
          'failed',
          'error',
          'archived',
        }.contains(session.effectiveLifecycleState) ||
        !(health.looksReady || health.wasRecentlySpawned);
  }

  /// Permission and background delivery must never revive an old process.
  /// Only explicit sends/retries may restore a saved Prime conversation.
  void _checkProcessScopedSendTarget(
    String sessionId,
    Session session, {
    bool allowPrimeRestore = false,
  }) {
    final flavor = session.metadata?.flavor ?? _sessionSpawnedAgent[sessionId];
    if (flavor != 'prime-agent' && flavor != 'har') return;
    if (!_processScopedSessionStopped(sessionId, session)) return;
    if (allowPrimeRestore &&
        flavor == 'prime-agent' &&
        session.canRestorePrimeAgent) {
      return;
    }
    if (allowPrimeRestore &&
        flavor == 'prime-agent' &&
        (session.metadata?.hasPrimeAgentSessionFile ?? false)) {
      throw StateError(
        'Could not resume Prime Agent: missing machineId/path. '
        'Check the machine details; your message has not been sent.',
      );
    }
    final agent = flavor == 'prime-agent' ? 'Prime Agent' : 'Har';
    throw StateError(
      '$agent cannot resume a stopped conversation. '
      'Start a new $agent session; your message has not been sent.',
    );
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
    String? localId,
  }) async {
    final runtimeGeneration = _runtimeGeneration;
    void checkRuntime() {
      if (!isInitialized || runtimeGeneration != _runtimeGeneration) {
        throw StateError('Session configuration cancelled by runtime reset');
      }
    }

    final configurations = PendingSessionConfiguration();
    final pendingSelection = configurations.read(sessionId);
    // Omitted profiles use storage; explicit Default never inherits it.
    final storedProfileId = profileId == null
        ? await MMKVStorage().getSessionProfile(sessionId)
        : null;
    checkRuntime();
    // A concurrent restore may have completed during send preparation.
    session = _sessions[sessionId] ?? session;
    final health = SyncHealth(
      session: session,
      sessionSpawnedAt: _sessionSpawnedAt,
      lastEphemeralAt: _lastEphemeralAt,
    );
    final recentlySpawned = health.wasRecentlySpawned;
    final mmkvProfileId = storedProfileId == 'default' ? null : storedProfileId;
    // `default` is the wire-level marker for an explicit no-profile choice.
    // Keep it distinct from an omitted profile while resolving intent, then
    // normalize it to null before comparing with spawn tracking. Otherwise a
    // just-cleared (but not yet flushed) MMKV entry can resurrect the previous
    // profile, while comparing the literal marker would make Default ->
    // Default restart on every send.
    final hasExplicitProfileSelection = profileId != null;
    final explicitProfileId = profileId == 'default' ? null : profileId;
    final effectiveProfileIdForChange = hasExplicitProfileSelection
        ? explicitProfileId
        : mmkvProfileId;
    final spawnedProfileKnown = _sessionSpawnedProfile.containsKey(sessionId);
    // For just-spawned sessions, MMKV may not have been written yet even
    // though _sessionSpawnedProfile was registered. Treat absence-of-MMKV +
    // recently-spawned as "no information" rather than "user wants Default",
    // otherwise we kill freshly-created sessions on their first send.
    final storedSpawnedProfileId = _sessionSpawnedProfile[sessionId];
    final spawnedProfileId = storedSpawnedProfileId == 'default'
        ? null
        : storedSpawnedProfileId;
    final mmkvUnknownForFreshSpawn =
        recentlySpawned && profileId == null && mmkvProfileId == null;
    // For sessions not tracked by this app run, only treat an explicit
    // (non-default) profile argument as a real change. Falling back to MMKV
    // on unknown sessions can be stale and would otherwise cause unnecessary
    // kill + respawn cycles.
    final explicitProfileChange = profileId != null && profileId != 'default';
    final profileChanged = spawnedProfileKnown
        ? (mmkvUnknownForFreshSpawn
              ? false
              : spawnedProfileId != effectiveProfileIdForChange)
        : explicitProfileChange;

    final trackedSpawnedModel = _sessionSpawnedModel[sessionId];
    // Use durable metadata when client-run spawn tracking was lost.
    final spawnedModel =
        trackedSpawnedModel ??
        _nonDefaultModelMode(session.modelMode ?? session.metadata?.model);
    // Legacy providers restart even when switching back to Default.
    final previousModel = spawnedModel ?? 'default';
    final requestedModel = modelMode ?? 'default';
    // Untracked sessions need an explicit pick that differs from metadata.
    final modelChanged = trackedSpawnedModel != null
        ? previousModel != requestedModel
        : (modelMode != null &&
              modelMode != 'default' &&
              previousModel != requestedModel);

    final isCodexSession =
        (session.metadata?.flavor ?? _sessionSpawnedAgent[sessionId]) ==
        'codex';
    final savedCodexFastMode = CodexSpeedSelection().read(sessionId);
    final pendingCodexSpeed = pendingSelection?.codexSpeed;
    final requestedCodexFastMode = pendingCodexSpeed == 'fast'
        ? true
        : pendingCodexSpeed == 'standard'
        ? false
        : savedCodexFastMode ??
              session.metadata?.codexFastMode ??
              settingsSnapshot.codexFastMode;
    final runningCodexFastMode =
        session.metadata?.codexFastMode ??
        savedCodexFastMode ??
        settingsSnapshot.codexFastMode;
    final codexSpeedChanged =
        isCodexSession && requestedCodexFastMode != runningCodexFastMode;

    checkRuntime();
    final isHarSession =
        (session.metadata?.flavor ?? _sessionSpawnedAgent[sessionId]) == 'har';
    final isPrimeAgentSession =
        (session.metadata?.flavor ?? _sessionSpawnedAgent[sessionId]) ==
        'prime-agent';
    final restorePrime =
        isPrimeAgentSession && _processScopedSessionStopped(sessionId, session);
    final configurationChanged =
        !isPrimeAgentSession &&
        (profileChanged ||
            modelChanged ||
            codexSpeedChanged ||
            pendingSelection != null);
    // Running Prime applies model changes through meta.model, never respawn.
    // A stopped process must confirm transcript restore before any delivery.
    if (isPrimeAgentSession) {
      _checkProcessScopedSendTarget(
        sessionId,
        session,
        allowPrimeRestore: true,
      );
      if (!restorePrime) {
        return (
          sessionId: sessionId,
          session: session,
          sessionEncryption: sessionEncryption,
        );
      }
    }
    if (isHarSession) {
      final harProfileChanged = spawnedProfileKnown
          ? profileChanged
          : hasExplicitProfileSelection && explicitProfileId != mmkvProfileId;
      // Har can switch in place. Launch tracking and saved composer intent
      // can lag behind a switch made by another client; metadata is the
      // running process's authoritative baseline.
      final harRunningModel = session.metadata?.model ?? previousModel;
      final harModelChanged =
          modelMode != null &&
          modelMode != 'default' &&
          harRunningModel != modelMode;
      if (harProfileChanged || harModelChanged || pendingSelection != null) {
        throw StateError(
          'Har provider is fixed for this conversation and model changes '
          'must be confirmed by the running Har session before sending; '
          'your message has not been sent.',
        );
      }
      _checkProcessScopedSendTarget(sessionId, session);
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }
    // Persist failed configuration changes for later retry.
    SessionConfigurationSelection? requestedSelection = pendingSelection;

    // Serialize replacement preparation, including different model picks.
    // A shared failed restore must never hand another sender the old process.
    final inFlight = _autoRestoreCompleters[sessionId];
    if (inFlight != null) {
      final restored = await inFlight.future;
      checkRuntime();
      return _resolveSendTargetSession(
        sessionId: restored.sessionId,
        session: _sessions[restored.sessionId] ?? restored.session,
        sessionEncryption: restored.sessionEncryption,
        effectivePermissionMode: effectivePermissionMode,
        profileId: profileId,
        modelMode: modelMode,
        localId: localId,
      );
    }
    if (configurationChanged && requestedSelection == null) {
      requestedSelection = configurations.save(
        sessionId,
        profileId: effectiveProfileIdForChange ?? 'default',
        modelMode: requestedModel,
        codexSpeed: codexSpeedChanged
            ? (requestedCodexFastMode ? 'fast' : 'standard')
            : null,
      );
    }

    final looksReady = !restorePrime && health.looksReady;
    final onlineTrusted = health.isOnlineTrusted;

    final lifecycleState = session.effectiveLifecycleState;
    final lifecycleErrored = session.hasLifecycleError;

    // Retain prior tracking if a legacy configuration replacement fails.
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

    if (looksReady && configurationChanged) {
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
    } else if (!restorePrime &&
        !configurationChanged &&
        (looksReady || (recentlySpawned && !lifecycleErrored))) {
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
      _profileModelKillInFlight.remove(sessionId);
      if (restorePrime || lifecycleErrored || configurationChanged) {
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
      _profileModelKillInFlight.remove(sessionId);
      if (restorePrime || lifecycleErrored || configurationChanged) {
        throw StateError(
          'Could not apply session configuration $sessionId: '
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
    if (localId != null) {
      messageInvariantMonitor.markSendPath(localId, SendPath.restore);
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
    // Observe errors even when no other send is awaiting this replacement.
    unawaited(
      completer.future.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      ),
    );
    _autoRestoreProfileIds[sessionId] = profileId;
    try {
      // Resolve profile env vars for this session before spawning.
      // Pass profileId from the sendMessage caller so we don't rely
      // on a debounced MMKV write that may not have flushed yet.
      final spawnResult = await _getSpawnEnvVarsForSession(
        sessionId,
        profileIdOverride: profileId,
        codexFastModeOverride: isCodexSession ? requestedCodexFastMode : null,
      );
      checkRuntime();
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
        // The send path carries the composer's current picker selection;
        // it must survive the respawn instead of the profile default.
        explicitModelPick: modelMode != null && modelMode != 'default',
        rejectExplicitClaudeModelOnGateway: true,
      );
      final effectiveModelMode = spawnProfileResolution.modelMode;
      final effectiveEnvVars = spawnProfileResolution.profile != null
          ? _spawnEnvForModel(
              spawnResult.envVars,
              agent: sessionAgent,
              profile: spawnProfileResolution.profile,
              modelMode: effectiveModelMode,
            )
          : <String, String>{
              'HAPPY_CODEX_FAST_MODE':
                  spawnResult.envVars['HAPPY_CODEX_FAST_MODE'] ??
                  (requestedCodexFastMode ? '1' : '0'),
            };
      final req = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: path,
        sessionId: sessionId,
        isRestore: true,
        agent: sessionAgent,
        permissionMode: effectivePermissionMode,
        spawnBackend: _spawnBackendForExistingSession(session, machine),
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
      checkRuntime();
      if (result.type != 'success') {
        restoreClearedSpawnTracking();
        final errorMsg = result.errorMessage ?? '';
        if (restorePrime) {
          throw StateError('Could not resume Prime Agent: $errorMsg');
        }
        if (configurationChanged) {
          throw StateError(
            'Could not apply selected session settings: $errorMsg. '
            'Your message has not been sent. Retry to apply the change.',
          );
        }
        // Do not post to a deleted legacy session.
        final isPermanent =
            errorMsg.contains('not found') ||
            errorMsg.contains('does not exist') ||
            errorMsg.contains('not exist');
        // Legacy agents may restart when a message reaches their parked
        // session. Prime must never take this unconfirmed fallback.
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
          // Let a later legacy send retry the terminal-state race.
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
          // Legacy delivery keeps its existing fallback for retry recovery.
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

      if (restorePrime && restoredSessionId != sessionId) {
        throw StateError('Prime Agent resume returned a different session');
      }

      await _primeSessionFromSpawnResult(
        requestedSessionId: sessionId,
        restoredSessionId: restoredSessionId,
        seedSession: session,
        result: result,
      );
      checkRuntime();
      if ((restorePrime || lifecycleErrored) &&
          restoredSessionId == sessionId) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final restoredInPlace = _sessions[restoredSessionId];
        if (restoredInPlace != null) {
          final metadata = restoredInPlace.metadata;
          _sessions[restoredSessionId] = restoredInPlace.copyWith(
            archived: restorePrime ? false : restoredInPlace.archived,
            lifecycleStateCleartext: restorePrime
                ? 'starting'
                : restoredInPlace.lifecycleStateCleartext,
            metadata: (metadata ?? const Metadata(host: '')).copyWith(
              lifecycleState: 'starting',
              lifecycleStateError: null,
              lifecycleStateSince: now,
            ),
          );
        }
      }
      // Track the confirmed selection and grant the restored process its
      // startup grace period before the next send.
      _registerSpawn(
        restoredSessionId,
        profileId:
            spawnResult.profile?.id ??
            profileId ??
            effectiveProfileIdForChange ??
            'default',
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
        checkRuntime();
        restoredSessionEncryption = encryption.getSessionEncryption(
          restoredSessionId,
        );
      }
      if (restoredSessionEncryption == null) {
        // Never deliver without encryption for the confirmed target.
        throw StateError('Session encryption not found: $restoredSessionId');
      }

      if (isCodexSession &&
          (configurationChanged || pendingCodexSpeed != null)) {
        final updatedMetadata =
            (restoredSession.metadata ?? const Metadata(host: '')).copyWith(
              codexFastMode: requestedCodexFastMode,
            );
        restoredSession = restoredSession.copyWith(metadata: updatedMetadata);
        _sessions[restoredSessionId] = restoredSession;
      }

      final restored = (
        sessionId: restoredSessionId,
        session: restoredSession,
        sessionEncryption: restoredSessionEncryption,
      );
      checkRuntime();
      if (requestedSelection != null) {
        configurations.clearIfCurrent(sessionId, requestedSelection);
      }
      if (restoredSessionId != sessionId) {
        CodexSpeedSelection().move(sessionId, restoredSessionId);
        configurations.moveCurrent(sessionId, restoredSessionId);
      }
      completer.complete(restored);
      return restored;
    } catch (error, stack) {
      if (!isInitialized || runtimeGeneration != _runtimeGeneration) {
        if (!completer.isCompleted) completer.completeError(error, stack);
        rethrow;
      }
      restoreClearedSpawnTracking();
      if (restorePrime) {
        final failure = StateError(
          'Could not resume Prime Agent. Your message has not been sent. '
          'Retry to resume the saved conversation. $error',
        );
        if (!completer.isCompleted) completer.completeError(failure, stack);
        Error.throwWithStackTrace(failure, stack);
      }
      if (configurationChanged) {
        final failure = StateError(
          'Could not apply selected session settings. '
          'Your message has not been sent. Retry to apply the change. $error',
        );
        logger.warning(
          '[sendMessage] session settings replacement failed '
          'session=$sessionId',
          error,
          stack,
        );
        if (!completer.isCompleted) completer.completeError(failure, stack);
        Error.throwWithStackTrace(failure, stack);
      }
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
      } else if (error is RpcException &&
          error.message.contains('refusing stale spawn')) {
        // Legacy parked sessions restart on their next message.
        logger.info(
          '[sendMessage] daemon refused stale respawn; delivering to the '
          'parked session so it restarts session=$sessionId',
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
        // A deleted session is an expected user-facing failure.
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
        // Preserve observability for unexpected legacy restore failures.
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
      if (runtimeGeneration == _runtimeGeneration &&
          identical(_autoRestoreCompleters[sessionId], completer)) {
        _profileModelKillInFlight.remove(sessionId);
        _autoRestoreInFlight.remove(sessionId);
        _autoRestoreCompleters.remove(sessionId);
        _autoRestoreProfileIds.remove(sessionId);
      }
    }
  }
}
