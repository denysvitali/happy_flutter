part of 'sync_service.dart';

/// Apply pending provider/model intent before choosing a delivery target.
extension SyncSendTargetResolution on Sync {
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
    final health = SyncHealth(
      session: session,
      sessionSpawnedAt: _sessionSpawnedAt,
      lastEphemeralAt: _lastEphemeralAt,
    );

    final recentlySpawned = health.wasRecentlySpawned;

    // When the caller didn't pass a profileId (e.g. ask_user_question
    // fallback), fall back to MMKV. Composer sends use the explicit `default`
    // marker for no profile, so they never depend on an asynchronous MMKV
    // removal completing before target resolution.
    final storedProfileId = profileId == null
        ? await MMKVStorage().getSessionProfile(sessionId)
        : null;
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
    // Spawn tracking is intentionally volatile across app restarts. A
    // resumed/externally launched process has no client-run baseline, so use
    // the process's durable session metadata instead. Without this fallback,
    // changing the picker updates only persisted intent and never reaches the
    // already-running Claude/Codex process.
    final spawnedModel =
        trackedSpawnedModel ??
        _nonDefaultModelMode(session.modelMode ?? session.metadata?.model);
    // Any model change must respawn — including switch TO `default`.
    // Old guard only fired for non-default → non-default, so Qwen →
    // Default (OpenAI) kept the old process (and its sticky model /
    // codexThreadId) alive and remote compact still used qwen.
    final previousModel = spawnedModel ?? 'default';
    final requestedModel = modelMode ?? 'default';
    // Tracked sessions carry a trustworthy client-run baseline: any
    // difference respawns, including switches to/from `default`. For
    // untracked (resumed) sessions the durable metadata cannot tell
    // "process runs this model" apart from "user once picked it", and a
    // plain follow-up send must not kill a healthy process just because
    // the app restarted — so only an explicit non-default selection that
    // differs from the durable baseline counts (mirrors
    // [explicitProfileChange] above).
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
    final configurationChanged =
        profileChanged ||
        modelChanged ||
        codexSpeedChanged ||
        pendingSelection != null;
    // Persist detected changes too, so a failed switch remains retryable
    // after navigation or app restart without trusting volatile spawn maps.
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

    final looksReady = health.looksReady;
    final onlineTrusted = health.isOnlineTrusted;

    final lifecycleState = session.effectiveLifecycleState;
    final lifecycleErrored = session.hasLifecycleError;

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
    } else if (!configurationChanged &&
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
      if (lifecycleErrored || configurationChanged) {
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
      if (lifecycleErrored || configurationChanged) {
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
        if (configurationChanged) {
          throw StateError(
            'Could not apply selected session settings: $errorMsg. '
            'Your message has not been sent. Retry to apply the change.',
          );
        }
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
      checkRuntime();
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
        // Encryption is permanently unavailable for this session — throw so
        // the message goes to outbox for retry, rather than sending to a
        // session we can't encrypt messages for.
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
        // The daemon parked an idle session ("will restart on next user
        // message") and rejects an explicit respawn of it. The message POST
        // that follows restarts it with the message's model, so the send is
        // not failed (GlitchTip 8910/8911 flashed "Failed" on a delivered
        // message).
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
