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
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Sync suspend',
          category: 'sync.lifecycle',
          level: SentryLevel.info,
          data: <String, dynamic>{
            'visibleSessionId': _visibleSessionId,
            'pendingSocketSessions': _sessionsWithPendingSocketMessages.length,
            'messageSyncCount': messagesSync.length,
          },
        ),
      ),
    );

    // Cancel deferred resume invalidation — if the app is backgrounding
    // before the 1.5s timer fired, no HTTP requests should be started.
    _deferredResumeInvalidationTimer?.cancel();
    _deferredResumeInvalidationTimer = null;
    _reconnectWatchdogTimer?.cancel();
    _reconnectWatchdogTimer = null;
    _resumeBatchTimer?.cancel();
    _resumeBatchTimer = null;

    // Set backgrounded flag FIRST — this prevents any in-flight
    // InvalidateSync operations from performing network I/O while
    // backgrounded.  Checked in InvalidateSync._run() before the
    // await _action() call.
    InvalidateSync.isBackgrounded = true;
    _lastSuspendedAtMs = DateTime.now().millisecondsSinceEpoch;
    // Quiesce all InvalidateSync retry/cooldown timers without disposing the
    // instances. Backgrounding is temporary; disposing here causes foreground
    // refresh callers to race a teardown-only state and can surface as
    // "InvalidateSync disposed" when the app resumes.
    sessionsSync.suspend();
    settingsSync.suspend();
    profileSync.suspend();
    purchasesSync.suspend();
    machinesSync.suspend();
    pushTokenSync.suspend();
    nativeUpdateSync.suspend();
    artifactsSync.suspend();
    friendsSync.suspend();
    friendRequestsSync.suspend();
    feedSync.suspend();
    todosSync.suspend();
    sessionGitStatusSync.suspend();
    for (final sync in messagesSync.values) {
      sync.suspend();
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
    socketIoClient.disconnect(preserveConnectionHistory: true);
  }

  /// Resume the sync engine when the app returns to the foreground.
  ///
  /// Reconnects the socket and invalidates all syncs so any server-side
  /// changes that happened while the app was backgrounded are fetched.
  void resume() {
    if (!isInitialized) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastResumeGapMs = _lastResumeAtMs != null
        ? nowMs - _lastResumeAtMs!
        : null;
    final isRapidResume =
        lastResumeGapMs != null &&
        lastResumeGapMs < Sync._resumeDebounceWindowMs;
    _lastResumeAtMs = nowMs;

    // Clear backgrounded flag BEFORE reconnecting so that any
    // InvalidateSync operations kicked off by the invalidations below
    // are allowed to run.
    // The isBackgrounded check is in InvalidateSync._run() before
    // await _action().
    InvalidateSync.isBackgrounded = false;

    if (isRapidResume) {
      logger.debug(
        '[Sync] rapid resume — previous resume ${lastResumeGapMs}ms ago',
      );
    }
    logger.info('[Sync] resuming — reconnecting socket');
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Sync resume',
          category: 'sync.lifecycle',
          level: SentryLevel.info,
          data: <String, dynamic>{
            'rapidResume': isRapidResume,
            'lastResumeGapMs': lastResumeGapMs,
            'visibleSessionId': _visibleSessionId,
            'pendingSocketSessions': _sessionsWithPendingSocketMessages.length,
            'messageSyncCount': messagesSync.length,
            'socketStatus': socketIoClient.connectionStatus.name,
          },
        ),
      ),
    );
    socketIoClient.reconnect();

    // Resume lightweight services immediately.
    messageOutbox.resume();
    NetworkMonitorService().resume();

    // Start a reconnection watchdog that fires if the socket hasn't
    // connected within a reasonable window. This covers the case where
    // Socket.IO's internal reconnection attempts are exhausted (e.g.
    // flaky network on resume) and no connectivity change event fires
    // to trigger a fresh reconnect. The watchdog is cancelled on
    // suspend() and on successful socket connect.
    _scheduleReconnectWatchdog();

    // Defer network-heavy invalidations so that foreground/background
    // cycling (e.g. Android 16 aggressive background management) does not
    // fire HTTP requests that get aborted when the app backgrounds again
    // within ~1 second.
    // suspend() cancels this timer.
    //
    // The socket reconnected handler (in _sync_socket_events.dart)
    // fires immediately on connect and triggers _invalidateAllSyncs,
    // so this timer is a secondary fallback for:
    //  - sessions with pending socket messages
    //  - the visible session's message sync
    //  - the case where the socket takes longer to connect
    _deferredResumeInvalidationTimer?.cancel();
    _deferredResumeInvalidationTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        _deferredResumeInvalidationTimer = null;
        if (!isInitialized || InvalidateSync.isBackgrounded) {
          return;
        }

        final suspendDuration = _lastSuspendedAtMs != null
            ? DateTime.now().millisecondsSinceEpoch - _lastSuspendedAtMs!
            : 0;
        final shouldRunGlobalInvalidation = suspendDuration > 30 * 1000;
        final socketNeedsHttpFallback =
            socketIoClient.connectionStatus != ConnectionStatus.connected;
        final shouldRefreshSessions =
            shouldRunGlobalInvalidation || socketNeedsHttpFallback;
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: 'Sync resume invalidation fired',
              category: 'sync.lifecycle',
              level: SentryLevel.info,
              data: <String, dynamic>{
                'rapidResume': isRapidResume,
                'suspendDurationMs': suspendDuration,
                'shouldRunGlobalInvalidation': shouldRunGlobalInvalidation,
                'socketNeedsHttpFallback': socketNeedsHttpFallback,
                'visibleSessionId': _visibleSessionId,
                'pendingSocketSessions':
                    _sessionsWithPendingSocketMessages.length,
              },
            ),
          ),
        );

        // Keep the session delta cursor on resume, even after long
        // background periods. Resetting it forces a full sessions fetch
        // and decrypt of the entire catalog, which makes foreground
        // reconnects scale with total session count instead of recent
        // activity. The visible session and any sessions with pending
        // socket messages are refreshed separately below.
        if (shouldRunGlobalInvalidation) {
          _invalidateAllSyncs();
        } else if (socketNeedsHttpFallback) {
          logger.info(
            '[Sync] resume: socket not connected yet '
            '(${socketIoClient.connectionStatus.name}) — '
            'refreshing sessions via HTTP fallback',
          );
        } else {
          logger.debug(
            '[Sync] resume: skipping broad invalidation '
            'after short suspend (${suspendDuration}ms)',
          );
        }

        final sessionsToRefresh = <String>{};

        // Invalidate sessions that had pending socket messages before
        // suspend.  Process in staggered batches to avoid launching
        // dozens of parallel HTTP requests on resume — each failed fetch
        // retries 3× with a 15 s timeout, so uncapped sessions could
        // mean N × 54 s of combined network time.  The first batch runs
        // immediately (chained after sessions fetch); remaining sessions
        // are processed every 2 seconds until all are fetched.
        if (_sessionsWithPendingSocketMessages.isNotEmpty) {
          // Remove the visible session — it's added unconditionally
          // below, so it doesn't count against the batch.
          _sessionsWithPendingSocketMessages.remove(_visibleSessionId);
          final batch = _sessionsWithPendingSocketMessages
              .take(Sync._maxResumeMessageSyncs)
              .toList();
          for (final sessionId in batch) {
            _sessionsWithPendingSocketMessages.remove(sessionId);
            if (_shouldForceTailRefreshForPendingSession(sessionId)) {
              _sessionsNeedingTailRefresh.add(sessionId);
            }
            sessionsToRefresh.add(sessionId);
          }
          logger.info(
            '[Sync] resume: processing ${batch.length} pending sessions '
            '(${_sessionsWithPendingSocketMessages.length} remaining in queue)',
          );
          // Schedule staggered processing for remaining sessions.
          if (_sessionsWithPendingSocketMessages.isNotEmpty) {
            _scheduleResumeMessageBatch();
          }
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
                name: 'fetchMessages',
              );
            }
          }

          // Ensure sessions are fresh, then refresh messages.
          // Use invalidate() + awaitQueue() instead of a second
          // invalidateAndAwait() — the socket reconnection handler
          // already kicked off a sessions fetch via
          // _invalidateAllSyncs().  Starting another cycle would
          // cause a redundant HTTP fetch.
          //
          // Set forceProbe INSIDE the .then() callback so the flag
          // isn't consumed by an earlier chained fetch (e.g. the
          // socket reconnect handler's callback which shares the
          // same sessionsSync queue).
          sessionsSync.invalidate();
          unawaited(
            sessionsSync.awaitQueue().then((_) {
              for (final sessionId in sessionsToRefresh) {
                _sessionsNeedingFetchProbe.add(sessionId);
                messagesSync[sessionId]?.invalidate();
              }
            }),
          );
        } else if (shouldRefreshSessions) {
          sessionsSync.invalidate();
        }
      },
    );
  }

  /// Process the next batch of sessions from
  /// [_sessionsWithPendingSocketMessages] that were deferred during resume.
  ///
  /// Called by a repeating timer (every 2 s) until the set is empty.
  /// Each batch fetches at most [_maxResumeMessageSyncs] sessions, limiting
  /// parallel HTTP requests while ensuring every session is eventually
  /// refreshed — unlike the previous hard-cap that silently dropped
  /// sessions beyond the cap.
  void _scheduleResumeMessageBatch() {
    _resumeBatchTimer?.cancel();
    _resumeBatchTimer = Timer(
      const Duration(seconds: 2),
      () {
        _resumeBatchTimer = null;
        if (!isInitialized || InvalidateSync.isBackgrounded) return;
        if (_sessionsWithPendingSocketMessages.isEmpty) return;

        final batch = _sessionsWithPendingSocketMessages
            .take(Sync._maxResumeMessageSyncs)
            .toList();
        for (final sessionId in batch) {
          _sessionsWithPendingSocketMessages.remove(sessionId);
          if (_shouldForceTailRefreshForPendingSession(sessionId)) {
            _sessionsNeedingTailRefresh.add(sessionId);
          }
          if (!messagesSync.containsKey(sessionId)) {
            messagesSync[sessionId] = InvalidateSync(
              () => fetchMessages(sessionId),
              minInterval: Sync._messagesSyncMinInterval,
              name: 'fetchMessages',
            );
          }
          _sessionsNeedingFetchProbe.add(sessionId);
          messagesSync[sessionId]?.invalidate();
        }

        logger.info(
          '[Sync] resume batch: fetched ${batch.length} sessions, '
          '${_sessionsWithPendingSocketMessages.length} remaining',
        );

        if (_sessionsWithPendingSocketMessages.isNotEmpty) {
          _scheduleResumeMessageBatch();
        }
      },
    );
  }

  /// Schedule (or reschedule) a reconnection watchdog timer.
  ///
  /// If the socket is not connected when the timer fires, a fresh
  /// [socketIoClient.reconnect] cycle is started and syncs are
  /// force-invalidated.  This recovers from:
  ///   - Socket.IO exhausting its internal reconnection attempts
  ///   - Transient network flakiness during foreground transition
  ///   - Server restarts that outlast the initial reconnect window
  ///
  /// The timer is cancelled by [suspend] and reset by each call so
  /// that reconnect-exhausted events and resume() don't stack timers.
  void _scheduleReconnectWatchdog() {
    _reconnectWatchdogTimer?.cancel();
    // If already connected, no watchdog needed.
    if (socketIoClient.connectionStatus == ConnectionStatus.connected) {
      _reconnectWatchdogTimer = null;
      return;
    }
    _reconnectWatchdogTimer = Timer(
      const Duration(milliseconds: Sync._reconnectWatchdogDelayMs),
      () {
        _reconnectWatchdogTimer = null;
        if (!isInitialized || InvalidateSync.isBackgrounded) return;

        if (socketIoClient.connectionStatus ==
            ConnectionStatus.connected) {
          return;
        }

        logger.warning(
          '[Sync] reconnect watchdog fired — socket still '
          'disconnected, forcing fresh reconnect',
        );
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: 'Sync reconnect watchdog triggered',
              category: 'sync.lifecycle',
              level: SentryLevel.warning,
              data: <String, dynamic>{
                'socketStatus':
                    socketIoClient.connectionStatus.name,
                'visibleSessionId': _visibleSessionId,
              },
            ),
          ),
        );

        socketIoClient.reconnect();
        // Force-invalidate all syncs since the deferred timer may
        // have already fired and been dropped by the cooldown.
        _invalidateAllSyncs(force: true);

        // If the visible session has a message sync, kick it too.
        if (_visibleSessionId != null) {
          unawaited(
            sessionsSync.awaitQueue().then((_) {
              if (_visibleSessionId != null) {
                messagesSync[_visibleSessionId]?.invalidate();
              }
            }),
          );
        }
      },
    );
  }

  /// Shutdown sync engine and clear volatile state.
  Future<void> shutdown() async {
    _reconnectWatchdogTimer?.cancel();
    _reconnectWatchdogTimer = null;
    _resumeBatchTimer?.cancel();
    _resumeBatchTimer = null;
    _reconnectCursorSnapshot = null;
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

    _unsubscribeSocketUpdate?.call();
    _unsubscribeSocketUpdate = null;
    _unsubscribeSocketEphemeral?.call();
    _unsubscribeSocketEphemeral = null;
    _unsubscribeSocketError?.call();
    _unsubscribeSocketError = null;
    _unsubscribeSocketReconnected?.call();
    _unsubscribeSocketReconnected = null;
    _unsubscribeSocketReconnectExhausted?.call();
    _unsubscribeSocketReconnectExhausted = null;
    _unsubscribeSocketStatus?.call();
    _unsubscribeSocketStatus = null;
    socketIoClient.disconnect();

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
    _previewCache.clear();
    _previewCacheVersion.clear();
    _sessionMessagesCache = null;
    _sessionMessagesViewCache.clear();
    _optimisticallyArchivedSessions.clear();
    _sessions.clear();
    _lastSessionsFetchedAt = null;
    SessionsCacheStorage.instance.clearSessionsCache();
    _machines.clear();
    _sessionGitStatus.clear();
    _sessionSpawnedAt.clear();
    _sessionSpawnedProfile.clear();
    _machineOfflineWarnedAtMs.clear();
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
