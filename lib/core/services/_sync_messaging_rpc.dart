part of 'sync_service.dart';

extension SyncMessagingRpc on Sync {
  Future<dynamic> machineRPC(
    String machineId,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final stopwatch = Stopwatch()..start();
    var machineEncryption = encryption.getMachineEncryption(machineId);
    if (machineEncryption == null) {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'machineRPC: encryption null, awaiting machines',
            category: 'sync.machines',
            data: {'machineId': machineId, 'method': method},
          ),
        ),
      );
      // Encryption may not be initialized yet — wait for pending fetch.
      // This can happen after socket reconnect when machinesSync was
      // invalidated but fetch hasn't completed yet.
      await machinesSync.invalidateAndAwait();
      machineEncryption = encryption.getMachineEncryption(machineId);
      if (machineEncryption == null) {
        throw StateError('Machine encryption not found for $machineId');
      }
    }

    final encrypted = await machineEncryption.encryptRaw(params);
    final rpcElapsedBeforeSend = stopwatch.elapsedMilliseconds;
    // emitWithAck now throws SocketNotConnectedException (socket not connected)
    // or SocketAckTimeoutException (ACK timeout) instead of returning null.
    // These propagate as-is so callers can distinguish connection failures from
    // application-level errors.
    final Object? result;
    try {
      result = await socketIoClient.emitWithAck('rpc-call', {
        'method': '$machineId:$method',
        'params': encrypted,
      }, timeout: timeout);
    } catch (error, stack) {
      logger.warning(
        '[machineRPC] FAILED method=$method machine=$machineId '
        'elapsedMs=${stopwatch.elapsedMilliseconds}: $error',
        error,
        stack,
      );
      rethrow;
    }

    if (result is Map && result['ok'] == true) {
      final encryptedResult = result['result'] as String?;
      if (encryptedResult == null) {
        throw StateError('Machine RPC $method returned null result');
      }
      final decrypted = await machineEncryption.decryptRaw(encryptedResult);
      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs >= 2000) {
        logger.info(
          '[machineRPC] SLOW method=$method machine=$machineId '
          'elapsedMs=$elapsedMs preSendMs=$rpcElapsedBeforeSend',
        );
      }
      if (decrypted == null) {
        logger.error('machineRPC $method: decryption returned null');
        unawaited(
          Sentry.captureMessage(
            'machineRPC $method: decryption returned null',
            level: SentryLevel.error,
          ),
        );
      }
      return decrypted;
    }
    // Log the failure reason if available
    final errorMsg = result is Map ? result['error'] : result;
    throw StateError('Machine RPC $method failed: $errorMsg');
  }

  /// Cheap pre-flight liveness probe before long-running spawn RPCs.
  ///
  /// A fresh `activeAt` heartbeat only proves the daemon was alive
  /// recently — a wedged daemon (or dead socket on the server side)
  /// still ACKs nothing and previously burned the full 60 s spawn
  /// timeout before failing. This sends a `ping` RPC with a short
  /// timeout instead: any reply — even `Method not found` from daemons
  /// that predate the `ping` handler — proves the machine is reachable
  /// within seconds.
  ///
  /// Throws [StateError] (`Machine is unreachable`) when the ping ACK
  /// times out. Socket connection errors propagate as-is.
  Future<void> ensureMachineReachable(String machineId) async {
    final override = testEnsureMachineReachableOverride;
    if (override != null) {
      return override(machineId);
    }
    // Unit tests stub the typed RPC layer — the probe would otherwise
    // hit the real socket and fail every createSession test.
    if (testMachineRPCOverride != null) return;
    try {
      await machineRPC(
        machineId,
        'ping',
        const {},
        timeout: const Duration(seconds: 8),
      );
    } on SocketAckTimeoutException {
      throw StateError('Machine is unreachable');
    } on StateError {
      // The daemon replied with an application-level error (older
      // daemons have no `ping` handler and answer `Method not found`).
      // Any reply proves liveness — that is all this probe checks.
    }
  }

  /// RPC call for sessions - uses session-specific encryption.
  Future<dynamic> sessionRPC(
    String sessionId,
    String method,
    Map<String, dynamic> params,
  ) async {
    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message:
                'fetchMessages: encryption null, '
                'awaiting sessions',
            category: 'sync.messages',
            data: {'sessionId': sessionId},
          ),
        ),
      );
      // Encryption may not be initialized yet — wait for pending fetch.
      await sessionsSync.invalidateAndAwait();
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        // Force a full fetch in case changedSince race skipped the session.
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        throw StateError('Session encryption not found for $sessionId');
      }
    }

    final encrypted = await sessionEncryption.encryptRaw(params);
    // emitWithAck now throws SocketNotConnectedException or
    // SocketAckTimeoutException instead of returning null.
    final result = await socketIoClient.emitWithAck('rpc-call', {
      'method': '$sessionId:$method',
      'params': encrypted,
    });

    if (result is Map && result['ok'] == true) {
      final encryptedResult = result['result'] as String?;
      if (encryptedResult == null) return null;
      final decrypted = await sessionEncryption.decryptRaw(encryptedResult);
      return decrypted;
    }
    // Log the failure reason if available
    final errorMsg = result is Map ? result['error'] : result;
    throw StateError('Session RPC $method failed: $errorMsg');
  }

  /// Typed wrapper around [machineRPC] that deserialises the response.
  Future<Resp> _typedMachineRPC<Resp>(
    String machineId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final override = testMachineRPCOverride;
    final raw = override != null
        ? await override(machineId, method, params)
        : await machineRPC(machineId, method, params, timeout: timeout);
    // machineRPC now throws on null — this check is only needed for the
    // test override path which may return null.
    if (raw == null) {
      throw StateError(
        'Machine RPC $method returned null — '
        'test override may be misconfigured',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Machine RPC $method returned unexpected type: ${raw.runtimeType} '
        '(value: $raw)',
      );
    }
    return fromJson(raw);
  }

  /// Typed wrapper around [sessionRPC] that deserialises the response.
  Future<Resp> _typedSessionRPC<Resp>(
    String sessionId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await sessionRPC(sessionId, method, params);
    // Handle null or non-Map responses gracefully
    if (raw == null) {
      throw StateError(
        'Session RPC $method returned null - encryption may have failed',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Session RPC $method returned unexpected type: ${raw.runtimeType} '
        '(value: $raw)',
      );
    }
    return fromJson(raw);
  }

  /// Checks whether the session's CLI process is running.
  ///
  /// If the session is already online or starting/running, returns
  /// `false` (no restore needed).  If the session is offline and has
  /// `machineId`/`path` metadata, sends `spawn-happy-session` to
  /// revive it and returns `true` to signal that a **new** process
  /// was spawned (meaning old in-flight state like pending permissions
  /// is gone).
  ///
  /// Returns `false` when no restore was attempted (session was
  /// already ready, or metadata was missing).
  Future<bool> _ensureSessionProcess(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) return false;

    final lifecycleState = session.effectiveLifecycleState;
    // Guard against stale lifecycleState
    // (same logic as _resolveSendTargetSession).
    final lifecycleStateSince = session.metadata?.lifecycleStateSince;
    final lifecycleRecent =
        lifecycleStateSince != null &&
        DateTime.now().millisecondsSinceEpoch - lifecycleStateSince < 120000;
    final agentIsStartingOrRunning =
        lifecycleState == 'starting' || lifecycleState == 'running';
    final isArchived = lifecycleState == 'archived';
    final looksReady =
        !isArchived &&
        (session.isOnline || (agentIsStartingOrRunning && lifecycleRecent));

    // Grace period for recently-spawned sessions — same threshold as
    // _resolveSendTargetSession. Prevents premature auto-restore for
    // permission actions while the daemon is still booting the agent.
    final recentlySpawned = _sessionSpawnedAt[sessionId] != null &&
        DateTime.now().millisecondsSinceEpoch - _sessionSpawnedAt[sessionId]! <
            120000;

    if (looksReady || recentlySpawned) return false;

    final machineId = session.metadata?.machineId;
    final path = session.metadata?.path;
    if (machineId == null ||
        machineId.isEmpty ||
        path == null ||
        path.isEmpty) {
      return false;
    }

    logger.info(
      '[permission] session=$sessionId appears offline '
      '(presence=${session.presence}, '
      'lifecycleState=$lifecycleState); '
      'attempting auto-restore',
    );

    try {
      // Resolve profile env vars for this session before spawning.
      final spawnResult = await _getSpawnEnvVarsForSession(sessionId);
      final sessionAgent =
          session.metadata?.flavor ??
          _sessionSpawnedAgent[sessionId] ??
          'claude';
      final req = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: path,
        sessionId: sessionId,
        agent: sessionAgent,
        permissionMode: session.permissionMode,
        model: _getModelOverride(profile: spawnResult.profile),
        environmentVariables: spawnResult.envVars,
      );
      final result = await _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson(),
        SpawnSessionResponse.fromJson,
        timeout: const Duration(seconds: 60),
      );
      if (result.type == 'success') {
        logger.info(
          '[permission] auto-restore succeeded '
          'session=$sessionId',
        );
        return true;
      }
      logger.warning(
        '[permission] auto-restore not successful '
        'session=$sessionId type=${result.type ?? 'null'} '
        'error=${result.errorMessage ?? 'unknown'}',
      );
    } catch (error, stack) {
      if (Sync._isTransientRpcError(error) ||
          Sync._isRpcMethodNotAvailable(error)) {
        final reason = Sync._isRpcMethodNotAvailable(error)
            ? 'RPC unavailable'
            : Sync._isRpcReplicaTimeout(error)
            ? 'RPC replica timeout'
            : 'transient';
        logger.info(
          '[permission] auto-restore failed ($reason) '
          'session=$sessionId: $error',
        );
      } else {
        logger.error(
          '[permission] auto-restore failed '
          'session=$sessionId',
          error,
          stack,
        );
      }
    }
    return false;
  }

  /// Fire local notifications for any newly-detected pending
  /// permission requests that the user hasn't seen yet.
  ///
  /// Called after [fetchSessions] merges updated sessions and
  /// after inline socket updates apply new agent state.
  void _checkForNewPermissionRequests(Iterable<Session> sessions) {
    for (final session in sessions) {
      // Don't notify for the session the user is viewing — they
      // can see the permission footer already.
      if (session.id == _visibleSessionId) continue;

      final requests = session.agentState?.requests;
      if (requests == null || requests.isEmpty) continue;

      for (final entry in requests.entries) {
        final permId = entry.key;
        if (_notifiedPermissionIds.contains(permId)) continue;
        // Evict oldest entries when the cap is reached to bound memory.
        if (_notifiedPermissionIds.length >= Sync._maxNotifiedPermissionIds) {
          _notifiedPermissionIds.remove(_notifiedPermissionIds.first);
        }
        _notifiedPermissionIds.add(permId);

        final request = entry.value;
        Map<String, dynamic>? toolInput;
        if (request.arguments is Map) {
          toolInput = Map<String, dynamic>.from(request.arguments as Map);
        }

        final sessionName =
            session.metadata?.summary?.text ??
            session.metadata?.path?.split('/').last;

        unawaited(
          NotificationService.instance.showPermissionNotification(
            sessionId: session.id,
            permissionId: permId,
            toolName: request.tool,
            toolInput: toolInput,
            sessionName: sessionName,
          ),
        );
      }
    }
  }

  /// Locally clear stale permission requests from a session's
  /// [AgentState] so the UI immediately unlocks the input box
  /// and hides the "permission required" banner.
  void _clearStalePermissionRequests(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;
    final hadRequests =
        session.agentState?.requests != null &&
        session.agentState!.requests!.isNotEmpty;
    if (hadRequests) {
      // Cancel any pending permission notifications for this session.
      for (final permId in session.agentState!.requests!.keys) {
        _notifiedPermissionIds.remove(permId);
        unawaited(
          NotificationService.instance.cancelPermissionNotification(permId),
        );
      }
      _sessions[sessionId] = session.copyWith(
        agentState: AgentState(
          controlledByUser: session.agentState?.controlledByUser,
          completedRequests: session.agentState?.completedRequests,
        ),
      );
    }
    // Also cancel any pending permissions on tool-call messages so
    // the UI stops showing Allow/Deny buttons that will always fail.
    final messages = _sessionMessages[sessionId];
    if (messages != null) {
      var changed = false;
      final updated = List<Map<String, dynamic>>.from(messages);
      for (var i = 0; i < updated.length; i++) {
        final msg = updated[i];
        if (msg['kind'] != 'tool-call') continue;
        final perm = WireParsers.asMap(msg['permission']);
        if (perm == null || perm['status'] != 'pending') continue;
        updated[i] = {
          ...msg,
          'permission': {...perm, 'status': 'canceled'},
        };
        changed = true;
      }
      if (changed) {
        _sessionMessages[sessionId] = updated;
        _sessionMessagesCache = null;
        _sessionMessagesViewCache.remove(sessionId);
        _notifySessionMessagesChanged(sessionId);
      }
    }
    if (hadRequests || messages != null) {
      _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
    }
  }

  /// Allow a permission request for a session.
  ///
  /// The server acknowledges with `ok: true` but the response
  /// payload shape varies — the RN app ignores it entirely, so
  /// we just fire-and-forget the RPC without deserialising.
  Future<void> sessionAllow(
    String sessionId,
    String permissionId, {
    String? mode,
    List<String>? allowTools,
    String? decision,
    Map<String, dynamic>? updatedInput,
  }) async {
    final restored = await _ensureSessionProcess(sessionId);
    if (restored) {
      _clearStalePermissionRequests(sessionId);
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
      throw StateError(
        'Session was restarted — this permission has expired. '
        'The agent will re-request it if still needed.',
      );
    }
    try {
      final response = await sessionRPC(
        sessionId,
        'permission',
        PermissionRequest(
          id: permissionId,
          approved: true,
          mode: mode,
          allowTools: allowTools,
          decision: decision,
          updatedInput: updatedInput,
        ).toJson(),
      );
      _throwIfPermissionRpcFailed(response, 'allow');
    } on StateError {
      // Permission was rejected by the server — clear stale local
      // state so the UI unlocks.
      _clearStalePermissionRequests(sessionId);
      rethrow;
    } finally {
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
    }
  }

  /// Deny a permission request for a session.
  ///
  /// See [sessionAllow] — response payload is ignored.
  Future<void> sessionDeny(
    String sessionId,
    String permissionId, {
    String? decision,
  }) async {
    final restored = await _ensureSessionProcess(sessionId);
    if (restored) {
      _clearStalePermissionRequests(sessionId);
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
      throw StateError(
        'Session was restarted — this permission has expired. '
        'The agent will re-request it if still needed.',
      );
    }
    try {
      final response = await sessionRPC(
        sessionId,
        'permission',
        PermissionRequest(
          id: permissionId,
          approved: false,
          decision: decision,
        ).toJson(),
      );
      _throwIfPermissionRpcFailed(response, 'deny');
    } on StateError {
      _clearStalePermissionRequests(sessionId);
      rethrow;
    } finally {
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
    }
  }

  void _throwIfPermissionRpcFailed(dynamic response, String action) {
    if (response is! Map) return;
    final success = response['success'];
    final ok = response['ok'];
    final isFailure = success == false || ok == false;
    if (!isFailure) return;
    final error = response['error'];
    throw StateError(
      'Permission $action failed: ${error?.toString() ?? 'unknown error'}',
    );
  }

  /// Kill a session's agent process.
  Future<KillSessionResponse> killSession(String sessionId) async {
    return _typedSessionRPC(
      sessionId,
      'killSession',
      const {},
      KillSessionResponse.fromJson,
    );
  }

  /// Abort the current agent turn without killing the session.
  Future<AbortResponse> abortSession(
    String sessionId, {
    String reason = '',
  }) async {
    return _typedSessionRPC(sessionId, 'abort', {
      'reason': reason,
    }, AbortResponse.fromJson);
  }

  /// Apply settings delta
  Future<void> applySettings(Map<String, dynamic> delta) async {
    _settingsSnapshot = Settings.fromJson({
      ..._settingsSnapshot.toJson(),
      ...delta,
    });
    pendingSettings = {...pendingSettings, ...delta};
    settingsSync.invalidate();
  }

  /// Refresh purchases data
  Future<void> refreshPurchases() async {
    purchasesSync.invalidate();
  }

  /// Evict stale messagesSync entries that haven't been used recently.
  /// Each InvalidateSync holds Timers, Completer, and closures capturing
  /// the Sync singleton — unbounded growth for 500+ sessions would leak
  /// memory across long-lived app sessions.
  static const int _messagesSyncEvictThresholdMs = 5 * 60 * 1000;
  void _evictStaleMessagesSync() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stale = messagesSync.entries
        .where((e) {
          final entry = e.value;
          final lastRunEnd = entry.lastRunEndMs;
          return lastRunEnd != null &&
              now - lastRunEnd > _messagesSyncEvictThresholdMs;
        })
        .map((e) => e.key)
        .toList();
    for (final id in stale) {
      messagesSync[id]?.dispose();
      messagesSync.remove(id);
    }
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    await profileSync.invalidateAndAwait();
  }

  /// Get authentication credentials
  AuthCredentials getCredentials() {
    return credentials;
  }

  /// On session visible handler
  Future<void> onSessionVisible(String sessionId) async {
    _visibleSessionId = sessionId;
    _sessionUnreadCounts.remove(sessionId);
    _sessionUnreadLastIncrementMs.remove(sessionId);
    // Clear any residual failed Future from the inline queue so that
    // new messages can enter the inline fast path immediately.
    _inlineProcessor.clearSession(sessionId);

    // Populate _sessionSpawnedProfile from MMKV so that profile switches
    // are detected in _resolveSendTargetSession.  Without this, pre-existing
    // sessions (loaded from server, not spawned in this app instance) are
    // not tracked and profile changes are silently ignored — only the model
    // string changes while the session keeps running with the old profile's
    // env vars (API keys, base URLs).
    if (!_sessionSpawnedProfile.containsKey(sessionId)) {
      MMKVStorage().getSessionProfile(sessionId).then((storedProfileId) {
        if (!_sessionSpawnedProfile.containsKey(sessionId)) {
          _sessionSpawnedProfile[sessionId] = storedProfileId;
        }
      });
    }

    final needsVisibleRegroup = _sessionsNeedingVisibleRegroup.remove(
      sessionId,
    );
    // Also run deferred sidechain grouping from cold-start cache restore.
    final needsSidechainRegroup = _sessionsNeedingSidechainRegroup.remove(
      sessionId,
    );
    if (needsVisibleRegroup || needsSidechainRegroup) {
      final messages = _sessionMessages[sessionId];
      if (messages != null &&
          messages.any((message) => message['isSidechain'] == true)) {
        _groupSidechainMessages(sessionId);
        _notifySessionMessagesChanged(sessionId);
        _notifyDataChanged({SyncDomain.messages});
      }
    }

    // Evict stale messagesSync entries that haven't been used in 5 minutes.
    // Each InvalidateSync holds Timers, a Completer, and closures that
    // capture the Sync singleton — unbounded growth for 500+ sessions.
    _evictStaleMessagesSync();
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: 'onSessionVisible',
        category: 'sync.messages',
        data: {
          'sessionId': sessionId,
          'hasPending': _sessionsWithPendingSocketMessages.contains(sessionId),
          'hasMessagesInMemory':
              _sessionMessages[sessionId]?.isNotEmpty ?? false,
          'cursorSeq': _sessionLastSeq[sessionId] ?? 0,
          'serverLastSeq': _sessions[sessionId]?.lastSeq ?? 0,
        },
      ),
    );

    // If this session received socket messages while non-visible, we MUST
    // fetch from the server to get those messages.  Socket messages are NOT
    // stored in _sessionMessages for non-visible sessions (only the seq
    // cursor is advanced), so the cache may be stale even if it has data.
    final hasPendingSocketMessages = _sessionsWithPendingSocketMessages.remove(
      sessionId,
    );
    if (!isInitialized) return;
    if (!messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId] = InvalidateSync(
        () => fetchMessages(sessionId),
        minInterval: Sync._messagesSyncMinInterval,
        name: 'fetchMessages',
        onRunningChanged: _onSyncRunningChanged,
        maxRetries: 0,
      );
    }

    var shouldProbeAfterSessionsRefresh = false;
    try {
      shouldProbeAfterSessionsRefresh = sessionsSync.isPending;
    } on Error {
      // Some widget tests exercise ChatScreen with only in-memory sync state
      // and do not initialize the global network sync queues.
      return;
    }

    // Only tail-refresh when we have no messages in memory for this session
    // (first open or after restart).  When messages are already loaded the
    // incremental delta path (afterSeq = _sessionLastSeq) is sufficient and
    // avoids re-downloading the last 200 messages on every navigation.
    var hasMessages =
        _sessionMessages.containsKey(sessionId) &&
        (_sessionMessages[sessionId]?.isNotEmpty ?? false);

    if (logger.shouldLog(LogLevel.debug)) {
      logger.debug(
        '[onSessionVisible] sessionId=$sessionId '
        'hasPendingSocketMessages=$hasPendingSocketMessages '
        'hasMessagesInMemory=$hasMessages '
        'cursorSeq=${_sessionLastSeq[sessionId] ?? 0} '
        'serverLastSeq=${_sessions[sessionId]?.lastSeq ?? 0}',
      );
    }

    if (!hasMessages) {
      // Restore from MMKV cache so the UI shows messages immediately
      // while the HTTP fetch is in flight.  Even when
      // hasPendingSocketMessages is true, show the (possibly stale)
      // cache as a starting point — the user sees *something* instead
      // of a loading spinner for 5-15s while the server fetch runs.
      // The incremental delta fetch will fill in any missing messages.
      try {
        final cached = await MessageCacheService().getMessagesAsync(sessionId);
        if (logger.shouldLog(LogLevel.debug)) {
          logger.debug(
            '[onSessionVisible] cacheRestore: ${cached.length} '
            'cached messages '
            '(hasPendingSocket=$hasPendingSocketMessages)',
          );
        }
        if (cached.isNotEmpty) {
          _sessionMessages[sessionId] = cached;
          _sessionMessagesCache = null;
          _sessionMessagesViewCache.remove(sessionId);
          hasMessages = true;
          // Re-run the sidechain grouper so cached sidechain messages
          // are correctly re-parented into their parent Task messages.
          if (cached.any((m) => m['isSidechain'] == true)) {
            _groupSidechainMessages(sessionId);
          }
          // Notify UI immediately so it can render cached messages.
          _notifySessionMessagesChanged(sessionId);
          _notifyDataChanged({SyncDomain.messages});
          // Recalculate the older-messages boundary from the cache
          // so hasOlderMessages() returns the correct value even if
          // _restoreAllCachedMessagesAsync hasn't run yet or the
          // session grew since the persisted boundary was saved.
          _ensureFirstLoadedSeq(sessionId);
        }
      } catch (error, stack) {
        logger.warning(
          'Failed to restore cached messages for session $sessionId '
          'in onSessionVisible — falling back to server fetch',
          error,
          stack,
        );
        hasMessages = false;
      }
      // Only request a tail refresh when there are NO messages to show.
      // When cache was restored, the incremental delta path (afterSeq =
      // _sessionLastSeq) is sufficient and avoids a destructive
      // gap-recovery that clears the cached messages the user already
      // sees.  The delta fetch will pick up newer messages and merge
      // them with the cache.
      if (!hasMessages) {
        _requestTailRefresh(sessionId);
        if (logger.shouldLog(LogLevel.debug)) {
          logger.debug(
            '[onSessionVisible] tailRefresh requested '
            '(hasMessages=$hasMessages '
            'hasPendingSocket=$hasPendingSocketMessages)',
          );
        }
      }
    } else {
      // Messages are in memory (from cache or previous load). Check if the
      // server has newer messages that we're missing. This handles the case
      // where the app was closed and new messages arrived — delta sync may
      // not update session.lastSeq if only messages changed (no metadata).
      final cursorSeq = _sessionLastSeq[sessionId] ?? 0;
      final serverLastSeq = _sessions[sessionId]?.lastSeq ?? 0;
      final hadPendingUpdates = _sessionsWithPendingUpdates.remove(sessionId);

      if (logger.shouldLog(LogLevel.debug)) {
        logger.debug(
          '[onSessionVisible] hasMessages path: cursorSeq=$cursorSeq '
          'serverLastSeq=$serverLastSeq hadPendingUpdates=$hadPendingUpdates',
        );
      }

      // Check for gap: server is ahead of our cursor
      if (cursorSeq > 0 && serverLastSeq > cursorSeq) {
        // Server has messages we haven't seen. Let fetchMessages handle it
        // via the normal incremental delta path (or gapTooLarge tail-load).
        if (logger.shouldLog(LogLevel.debug)) {
          logger.debug(
            '[onSessionVisible] gap detected: '
            'server($serverLastSeq) > cursor($cursorSeq) — will fetch delta',
          );
        }
      } else if (hadPendingUpdates) {
        // Socket events arrived while session was non-visible, but cursor
        // appears caught up or ahead.  Only tail-refresh when cursor data
        // is truly invalid (zero/negative).  When cursor >= server, the
        // incremental delta fetch is either a no-op (caught up) or will
        // pick up any remaining messages — a destructive tail-refresh
        // would unnecessarily wipe and re-download messages.
        if (cursorSeq <= 0 || serverLastSeq <= 0) {
          _requestTailRefresh(sessionId);
          if (logger.shouldLog(LogLevel.debug)) {
            logger.debug(
              '[onSessionVisible] tailRefresh '
              '(pending updates, invalid cursor)',
            );
          }
        }
      }
    }
    messagesSync[sessionId]?.invalidate();

    // On cold start the chat can restore cached rows and run fetchMessages()
    // before the startup sessions sync has refreshed Session.lastSeq. If the
    // stale cached cursor equals the stale cached lastSeq, fetchMessages()
    // skips the HTTP request and messages that arrived while the app was
    // closed stay hidden. Probe once after the sessions sync settles so the
    // message API is authoritative for the visible chat.
    if (shouldProbeAfterSessionsRefresh) {
      unawaited(
        sessionsSync.awaitQueue().then((_) {
          if (!isInitialized || _visibleSessionId != sessionId) return;
          _sessionsNeedingFetchProbe.add(sessionId);
          messagesSync[sessionId]?.invalidate();
        }),
      );
    }
  }

  void _requestTailRefresh(String sessionId) {
    _sessionsNeedingTailRefresh.add(sessionId);
  }

  bool _shouldForceTailRefreshForPendingSession(String sessionId) {
    final hasMessages =
        _sessionMessages.containsKey(sessionId) &&
        (_sessionMessages[sessionId]?.isNotEmpty ?? false);
    if (!hasMessages) {
      return true;
    }

    final cursorSeq = _sessionLastSeq[sessionId] ?? 0;
    final serverLastSeq = _sessions[sessionId]?.lastSeq ?? 0;
    return cursorSeq <= 0 || serverLastSeq <= 0;
  }

  int _tailAfterSeqForSession(String sessionId) {
    return _cursorManager.tailAfterSeq(
      sessionId,
      serverLastSeq: _sessions[sessionId]?.lastSeq ?? 0,
      initialLoad: Sync.initialLoad,
    );
  }

  /// Whether a session's agent is connected enough to receive messages.
  /// Checks both ephemeral presence and lifecycle metadata.
  /// Guards against stale lifecycleState by requiring a recent timestamp.
  bool _isSessionReady(Session s) {
    // Cross-check presence with a recent ephemeral event — same logic
    // as _resolveSendTargetSession to avoid trusting stale 'online'
    // presence after a daemon restart.
    final lastEphemeral = _lastEphemeralAt[s.id];
    final recentEphemeral =
        lastEphemeral != null &&
        DateTime.now().millisecondsSinceEpoch - lastEphemeral < 90000;
    if (s.isOnline && recentEphemeral) return true;
    final lc = s.effectiveLifecycleState;
    if (lc != 'running') return false;
    // Only trust "running" if the timestamp is recent (< 2 minutes).
    final since = s.metadata?.lifecycleStateSince;
    if (since == null) return false;
    return DateTime.now().millisecondsSinceEpoch - since < 120000;
  }

  /// Whether the session currently looks reachable for incoming messages.
  ///
  /// This cross-checks ephemeral keep-alives with lifecycle metadata instead
  /// of trusting raw `presence == 'online'` by itself.
  bool isSessionReadyForMessages(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return false;
    return _isSessionReady(session);
  }

  /// Wait for agent to be ready.
  ///
  /// Returns `true` when the session's presence becomes `'online'`
  /// (set by `handleEphemeralUpdate` when the daemon sends
  /// `session-alive` keep-alives — typically within 2 seconds),
  /// or when `lifecycleState` becomes `'running'` (set by the agent
  /// after connecting to Socket.IO — confirms push delivery).
  ///
  /// Note: `agentStateVersion` is intentionally NOT checked here
  /// because it persists across daemon restarts and would cause
  /// stale sessions to appear ready when the daemon is offline.
  Future<bool> waitForAgentReady(
    String sessionId, [
    int timeoutMs = Sync.sessionReadyTimeoutMs,
  ]) async {
    // Fast path: already online or lifecycle running
    final session = _sessions[sessionId];
    if (session != null && _isSessionReady(session)) return true;

    logger.info(
      '[sendMessage] waitForAgentReady waiting '
      'session=$sessionId isOnline=${session?.isOnline} '
      'lifecycleState=${session?.effectiveLifecycleState}',
    );

    // Event-driven: resolve as soon as the sessions domain changes
    // and the target session is ready, or after timeoutMs.  We listen
    // on [onDomainChanged] (filtered to sessions) instead of the
    // global [onDataChanged] firehose because session-state changes
    // are now scoped to SyncDomain.sessions; the firehose only fires
    // for truly-everything notifications.
    final completer = Completer<bool>();
    StreamSubscription<SyncDomain>? sub;
    Timer? timer;

    timer = Timer(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) completer.complete(false);
      sub?.cancel();
    });

    sub = onDomainChanged
        .where((d) => d == SyncDomain.sessions)
        .listen((_) {
          final s = _sessions[sessionId];
          if (s != null && _isSessionReady(s) && !completer.isCompleted) {
            completer.complete(true);
            timer?.cancel();
            sub?.cancel();
          }
        });

    final ready = await completer.future;
    logger.info(
      '[sendMessage] waitForAgentReady done '
      'session=$sessionId ready=$ready',
    );
    return ready;
  }
}
