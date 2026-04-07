part of 'sync_service.dart';

extension SyncLifecycle on Sync {
  /// Suspend the sync engine when the app goes to the background.
  ///
  /// Disconnects the socket so the OS does not keep reporting connection
  /// errors while the app is backgrounded (which previously caused a
  /// reconnect loop that saturated the main thread on resume). Pending
  /// debounce writes are flushed to MMKV so no cursor data is lost.
  ///
  /// ALL timers are cancelled to ensure zero network traffic and battery
  /// drain while the app is backgrounded.
  void suspend() {
    if (!isInitialized) return;
    logger.info('[Sync] suspending — disconnecting socket');

    // Cancel deferred resume invalidation — if the app is backgrounding
    // before the 1.5s timer fired, no HTTP requests should be started.
    _deferredResumeInvalidationTimer?.cancel();
    _deferredResumeInvalidationTimer = null;

    // Set backgrounded flag FIRST — this prevents any in-flight
    // InvalidateSync operations from performing network I/O while
    // backgrounded.  Checked in InvalidateSync._run() before the
    // await _action() call.
    InvalidateSync.isBackgrounded = true;
    _suspendedAtMs = DateTime.now().millisecondsSinceEpoch;

    // Cancel all InvalidateSync retry/cooldown timers.  This stops any
    // exponential-backoff network retries that would otherwise fire while
    // backgrounded (e.g. a settings fetch retry scheduled 1-5s out).
    sessionsSync.dispose();
    settingsSync.dispose();
    profileSync.dispose();
    purchasesSync.dispose();
    machinesSync.dispose();
    pushTokenSync.dispose();
    nativeUpdateSync.dispose();
    artifactsSync.dispose();
    friendsSync.dispose();
    friendRequestsSync.dispose();
    feedSync.dispose();
    todosSync.dispose();
    sessionGitStatusSync.dispose();
    for (final sync in messagesSync.values) {
      sync.dispose();
    }

    _dataChangeDebounceTimer?.cancel();
    for (final timer in _domainChangeDebounceTimers.values) {
      timer.cancel();
    }
    _domainChangeDebounceTimers.clear();
    _domainChangePendingTrailing.clear();
    for (final timer in _sessionMessageDebounceTimers.values) {
      timer.cancel();
    }
    _sessionMessageDebounceTimers.clear();
    for (final timer in _sidechainRegroupTimers.values) {
      timer.cancel();
    }
    _sidechainRegroupTimers.clear();
    _sidechainRegroupFirstRequestMs.clear();
    _inlineProcessor.clear();
    _sessionsRefreshDebounceTimer?.cancel();
    _socialSyncsDebounceTimer?.cancel();
    _artifactsSyncDebounceTimer?.cancel();
    _saveSeqDebounceTimer?.cancel();
    _saveSessionsCacheDebounceTimer?.cancel();
    for (final timer in _postSendCatchUpTimers.values) {
      timer.cancel();
    }
    _postSendCatchUpTimers.clear();
    _sessionsNeedingTailRefresh.clear();
    _sessionsWithPendingUpdates.clear();
    // DON'T clear _sessionsWithPendingSocketMessages — preserve it so
    // resume()
    // can invalidate those sessions and fetch any messages that arrived while
    // backgrounded. Clearing this set causes message loss for non-visible
    // sessions.
    // _sessionsWithPendingSocketMessages.clear();
    _sessionUnreadCounts.clear();
    _sessionUnreadLastIncrementMs.clear();

    // Cancel deferred syncs timer (non-critical data syncs)
    _deferredSyncsTimer?.cancel();
    _deferredSyncsTimer = null;

    // Cancel all presence timers (per-session 60s timers)
    for (final timer in _presenceTimers.values) {
      timer.cancel();
    }
    _presenceTimers.clear();

    // Cancel all message save debounce timers
    for (final timer in _saveMsgsDebounceTimers.values) {
      timer.cancel();
    }
    _saveMsgsDebounceTimers.clear();

    // Suspend message outbox to stop retry timers
    messageOutbox.suspend();
    NetworkMonitorService().suspend();

    // Flush pending message saves so the MMKV cache is up-to-date when the
    // OS kills the app while backgrounded.  Without this, an in-flight
    // deferred sidechain regroup can reset the save timer, and the cache
    // retains stale messages with isSidechain == true that become invisible
    // on the next cold start.
    _flushPendingMessageSaves();
    _flushSessionMessageNotifications();
    MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
    _persistSessionsCache();
    socketIoClient.disconnect();
  }

  /// Resume the sync engine when the app returns to the foreground.
  ///
  /// Reconnects the socket and invalidates all syncs so any server-side
  /// changes that happened while the app was backgrounded are fetched.
  void resume() {
    if (!isInitialized) return;

    // Debounce: if the app is fluttering between paused/resumed states (e.g.
    // rapid screen lock/unlock), skip redundant resume calls.  Each resume
    // reconnects the socket and kicks off a full sync invalidation — we don't
    // want to do that more than once per _resumeDebounceWindowMs.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastResumeAtMs != null &&
        nowMs - _lastResumeAtMs! < Sync._resumeDebounceWindowMs) {
      logger.debug(
        '[Sync] resume debounced — '
        'last resume ${nowMs - _lastResumeAtMs!}ms ago',
      );
      // Still clear the backgrounded flag so any pending operations
      // can run.
      InvalidateSync.isBackgrounded = false;
      return;
    }
    _lastResumeAtMs = nowMs;

    // Clear backgrounded flag BEFORE reconnecting so that any
    // InvalidateSync operations kicked off by the invalidations below
    // are allowed to run.
    // The isBackgrounded check is in InvalidateSync._run() before
    // await _action().
    InvalidateSync.isBackgrounded = false;

    logger.info('[Sync] resuming — reconnecting socket');
    socketIoClient.reconnect();

    // Resume lightweight services immediately.
    messageOutbox.resume();
    NetworkMonitorService().resume();

    // Defer network-heavy invalidations so that rapid
    // foreground/background cycling (e.g. Android 16 aggressive
    // background management) does not fire HTTP requests that get
    // aborted when the app backgrounds again within ~1 second.
    // suspend() cancels this timer.
    _deferredResumeInvalidationTimer?.cancel();
    _deferredResumeInvalidationTimer = Timer(
      const Duration(milliseconds: 1500),
      () {
        _deferredResumeInvalidationTimer = null;
        if (!isInitialized || InvalidateSync.isBackgrounded) {
          return;
        }

        // Only force a full session fetch when the app was suspended
        // long enough for delta results to be unreliable (>5 min).
        // Short suspends (screen-off, quick app-switch) keep the delta
        // cursor so we avoid re-fetching all sessions.
        final suspendDuration = _suspendedAtMs != null
            ? DateTime.now().millisecondsSinceEpoch - _suspendedAtMs!
            : 0;
        final needsFullFetch = suspendDuration > 5 * 60 * 1000;
        _invalidateAllSyncs(
          force: true,
          resetSessionDeltaCursor: needsFullFetch,
        );

        final sessionsToRefresh = <String>{};

        // Invalidate sessions that had pending socket messages before suspend.
        if (_sessionsWithPendingSocketMessages.isNotEmpty) {
          final pendingSessionIds = _sessionsWithPendingSocketMessages.toList();
          for (final sessionId in pendingSessionIds) {
            _sessionsNeedingTailRefresh.add(sessionId);
            sessionsToRefresh.add(sessionId);
          }
          logger.info(
            '[Sync] resuming — invalidating '
            '${pendingSessionIds.length} sessions with '
            'pending socket messages',
          );
          _sessionsWithPendingSocketMessages.clear();
        }

        // Always invalidate the visible session.
        if (_visibleSessionId != null) {
          sessionsToRefresh.add(_visibleSessionId!);
        }

        if (sessionsToRefresh.isNotEmpty) {
          for (final sessionId in sessionsToRefresh) {
            if (!messagesSync.containsKey(sessionId)) {
              messagesSync[sessionId] = InvalidateSync(
                () => fetchMessages(sessionId),
                minInterval: Sync._messagesSyncMinInterval,
                name: 'fetchMessages:$sessionId',
              );
            }
          }

          unawaited(
            sessionsSync.invalidateAndAwait().then((_) {
              for (final sessionId in sessionsToRefresh) {
                messagesSync[sessionId]?.invalidate();
              }
            }),
          );
        }
      },
    );
  }

  /// Shutdown sync engine and clear volatile state.
  Future<void> shutdown() async {
    _sessionsRefreshDebounceTimer?.cancel();
    _socialSyncsDebounceTimer?.cancel();
    _artifactsSyncDebounceTimer?.cancel();
    _saveSessionsCacheDebounceTimer?.cancel();
    for (final timer in _postSendCatchUpTimers.values) {
      timer.cancel();
    }
    _postSendCatchUpTimers.clear();
    _sessionsNeedingTailRefresh.clear();
    _sessionsWithPendingUpdates.clear();
    _sessionsWithPendingSocketMessages.clear();
    _notifiedPermissionIds.clear();
    _pendingUpdateSessionIds.clear();
    _pendingToolResults.clear();
    _sessionUnreadCounts.clear();
    _sessionUnreadLastIncrementMs.clear();

    socketIoClient
      ..offMessage('update')
      ..offMessage('ephemeral')
      ..disconnect();

    _dataChangeDebounceTimer?.cancel();
    _dataChangeDebounceTimer = null;
    for (final timer in _domainChangeDebounceTimers.values) {
      timer.cancel();
    }
    _domainChangeDebounceTimers.clear();
    _domainChangePendingTrailing.clear();
    for (final timer in _sessionMessageDebounceTimers.values) {
      timer.cancel();
    }
    _sessionMessageDebounceTimers.clear();
    for (final timer in _sidechainRegroupTimers.values) {
      timer.cancel();
    }
    _sidechainRegroupTimers.clear();
    _sidechainRegroupFirstRequestMs.clear();
    _inlineProcessor.clear();
    // Flush any pending seq write before shutdown so cursors aren't lost.
    _saveSeqDebounceTimer?.cancel();
    _saveSeqDebounceTimer = null;
    MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
    _persistSessionsCache();

    // Do NOT close these broadcast controllers — the Sync singleton is
    // reused after logout+login, and closing a final StreamController is
    // permanent. Listeners (screens that subscribe to onDataChanged) would
    // never receive events again, silently breaking all real-time updates.

    for (final sync in messagesSync.values) {
      sync.dispose();
    }
    messagesSync.clear();
    _sessionLastSeq.clear();
    MMKVStorage().clearSessionLastSeq();
    _sessionFirstLoadedSeq.clear();
    MMKVStorage().clearSessionFirstLoadedSeq();
    _loadingOlderMessages.clear();
    _recentInlineMessageKeys.clear();
    _recentInlineMessageKeyOrder.clear();
    _pendingInlineMessageKeys.clear();
    _lastNoEmbedEventMs.clear();
    _sessionsWithPendingSocketMessages.clear();
    _notifiedPermissionIds.clear();

    sessionsSync.dispose();
    settingsSync.dispose();
    profileSync.dispose();
    purchasesSync.dispose();
    machinesSync.dispose();
    pushTokenSync.dispose();
    nativeUpdateSync.dispose();
    artifactsSync.dispose();
    friendsSync.dispose();
    friendRequestsSync.dispose();
    feedSync.dispose();
    todosSync.dispose();
    sessionGitStatusSync.dispose();

    for (final timer in _presenceTimers.values) {
      timer.cancel();
    }
    _presenceTimers.clear();

    _sessionDataKeys.clear();
    _sessionEncryptedDataKeys.clear();
    _machineDataKeys.clear();
    _artifactDataKeys.clear();
    _todoLists.clear();
    _friends.clear();
    _friendRequests.clear();
    _feedItems.clear();
    _artifacts.clear();
    for (final timer in _saveMsgsDebounceTimers.values) {
      timer.cancel();
    }
    _saveMsgsDebounceTimers.clear();
    _sessionMessages.clear();
    _sessionMessagesCache = null;
    _sessionMessagesViewCache.clear();
    _optimisticallyArchivedSessions.clear();
    _sessions.clear();
    _lastSessionsFetchedAt = null;
    MMKVStorage().clearSessionsCache();
    _machines.clear();
    _sessionGitStatus.clear();
    _sessionSpawnedAt.clear();
    _sessionSpawnedProfile.clear();
    _autoRestoreInFlight.clear();
    _autoRestoreCompleters.clear();
    _autoRestoreProfileIds.clear();
    _lastEphemeralAt.clear();
    _pendingNewSessionIds.clear();
    _sessionUsage.clear();
    _profile = null;
    _settingsSnapshot = Settings();
    _settingsVersion = 0;
    _purchases = Purchases.defaults;
    pendingSettings.clear();
    _registeredPushToken = null;
    _nativeUpdateUrl = null;
    _isReady = false;
    _connectionStatus = ConnectionStatus.disconnected;
    isInitialized = false;
    _encryptionInitialized = false;
    // Dispose the outbox so retry timers don't fire after logout.
    messageOutbox.dispose();
  }
}
