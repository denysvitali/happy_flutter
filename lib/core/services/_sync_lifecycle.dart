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
    powerDiagnostics.recordLifecycle('sync.suspend');
    logger.info('[Sync] suspending');
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
    _resumeConversationProgressSafetyTimer?.cancel();
    _resumeConversationProgressSafetyTimer = null;
    _resumeConversationRefreshTotal = 0;
    _resumeConversationRefreshCompleted = 0;

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

    // Cancel deferred + background syncs timers (non-critical data
    // syncs). Both are restarted by the next _invalidateAllSyncs.
    _deferredSyncsTimer?.cancel();
    _deferredSyncsTimer = null;
    _backgroundSyncsTimer?.cancel();
    _backgroundSyncsTimer = null;

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
    _saveMsgsFirstScheduledAtMs.clear();

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

    // Always disconnect the socket when the app is backgrounded.
    // On physical devices the OS may keep a cached connection alive across
    // rapid lifecycle cycles, causing Socket.IO to accumulate reconnection
    // attempts and orphan messages.  Disconnecting on every background
    // ensures no traffic flows while the app is not visible.
    socketIoClient.disconnect(preserveConnectionHistory: true);
  }

  /// Resume the sync engine when the app returns to the foreground.
  ///
  /// Reconnects the socket and invalidates all syncs so any server-side
  /// changes that happened while the app was backgrounded are fetched.
  void resume() {
    if (!isInitialized) return;
    powerDiagnostics.recordLifecycle('sync.resume');

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

    // Reconnect the socket on every resume.  The socket was disconnected on
    // suspend, so a fresh connect is always needed.
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
        // Lowered from 30 s to 5 s: a daemon can come online (and
        // start heartbeating) within seconds, and the user's mental
        // model is that foregrounding the app should show fresh
        // machine state. The 5 s gate still absorbs the rapid-toggle
        // case (push-notification peek, accidental swipe) without
        // firing a broad invalidation. The 500 ms
        // _deferredResumeInvalidationTimer plus suspend-cancel
        // protection still guards the Android-16 background-abort
        // race for sub-second cycles.
        final shouldRunGlobalInvalidation = suspendDuration > 5 * 1000;
        final socketNeedsHttpFallback =
            socketIoClient.connectionStatus != ConnectionStatus.connected;
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
          _lastResumeHttpFallbackAtMs = DateTime.now().millisecondsSinceEpoch;
        } else {
          logger.debug(
            '[Sync] resume: skipping broad invalidation '
            'after short suspend (${suspendDuration}ms)',
          );
        }

        final sessionsToRefresh = <String>{};
        final resumeConversationIds = <String>{
          ..._sessionsWithPendingSocketMessages,
        };
        final visibleSessionId = _visibleSessionId;
        if (visibleSessionId != null) {
          resumeConversationIds.add(visibleSessionId);
        }
        _startResumeConversationProgress(resumeConversationIds.length);

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
          _sessionsWithPendingSocketMessages.remove(visibleSessionId);
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

        // Always invalidate the visible session — use the snapshot we
        // captured above so a concurrent delete-session / sign-out path
        // that clears `_visibleSessionId` between the null-check and the
        // deref cannot trip a "null check operator" crash.
        if (visibleSessionId != null) {
          sessionsToRefresh.add(visibleSessionId);
        }

        if (sessionsToRefresh.isNotEmpty) {
          for (final sessionId in sessionsToRefresh) {
            if (!messagesSync.containsKey(sessionId)) {
              messagesSync[sessionId] = InvalidateSync(
                () => fetchMessages(sessionId),
                minInterval: Sync._messagesSyncMinInterval,
                name: 'fetchMessages',
                onRunningChanged: _onSyncRunningChanged,
                maxRetries: 0,
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
          if (!sessionsSync.isPending) {
            sessionsSync.invalidate();
          }
          unawaited(
            sessionsSync
                .awaitQueue()
                .timeout(
                  Sync._resumeSessionsAwaitTimeout,
                  onTimeout: () {
                    throw TimeoutException(
                      'resume sessions sync did not settle',
                      Sync._resumeSessionsAwaitTimeout,
                    );
                  },
                )
                .then((_) {
                  for (final sessionId in sessionsToRefresh) {
                    _sessionsNeedingFetchProbe.add(sessionId);
                    try {
                      messagesSync[sessionId]?.invalidate();
                    } on Object catch (e, st) {
                      logger.warning(
                        '[Sync] resume: messagesSync[$sessionId].invalidate() '
                        'threw — continuing to advance progress: $e',
                      );
                      unawaited(
                        Sentry.captureException(
                          e,
                          stackTrace: st,
                          hint: Hint.withMap(<String, dynamic>{
                            'where': 'resume.advance.messagesSync.invalidate',
                            'sessionId': sessionId,
                          }),
                        ),
                      );
                    }
                  }
                })
                .catchError((Object e, StackTrace st) {
                  // A TimeoutException here just means sessionsSync did not
                  // settle within [_resumeSessionsAwaitTimeout]. The
                  // underlying invalidate() is still in flight and will
                  // emit onDataChanged when it eventually resolves — so we
                  // demote this to an info log and DO NOT report it to
                  // Sentry. Capturing was generating noisy "resume sessions
                  // sync did not settle" issues on slow cellular/VPN
                  // networks where the sync was actually working fine.
                  if (e is TimeoutException) {
                    logger.info(
                      '[Sync] resume: sessionsSync.awaitQueue() did not '
                      'settle within '
                      '${Sync._resumeSessionsAwaitTimeout.inSeconds}s — '
                      'continuing in background',
                    );
                    return;
                  }
                  logger.warning(
                    '[Sync] resume: sessionsSync.awaitQueue() failed — '
                    'forcing resume conversation progress to clear: $e',
                  );
                  unawaited(
                    Sentry.captureException(
                      e,
                      stackTrace: st,
                      hint: Hint.withMap(<String, dynamic>{
                        'where': 'resume.awaitQueue',
                        'pendingSessions': sessionsToRefresh.length,
                      }),
                    ),
                  );
                })
                .whenComplete(() {
                  // ALWAYS advance — even on failure — so the
                  // "Fetching conversations" bar never hangs at
                  // "0 of N complete".
                  _advanceResumeConversationProgress(sessionsToRefresh.length);
                }),
          );
        } else if (socketNeedsHttpFallback && !shouldRunGlobalInvalidation) {
          // _invalidateAllSyncs() above already invalidated sessionsSync;
          // re-invalidating here would start a second fetch cycle.
          sessionsSync.invalidate();
        }
      },
    );
  }

  void _startResumeConversationProgress(int total) {
    // Always cancel any in-flight safety timer first — even if `total`
    // is 0 or negative — so we never leak a timer from a previous
    // resume cycle.
    _resumeConversationProgressSafetyTimer?.cancel();
    _resumeConversationProgressSafetyTimer = null;
    if (total <= 0) {
      // A new resume cycle that needs no conversations should also
      // clear any stale totals from a previous cycle. Otherwise a
      // subsequent advance() call could re-show a "Fetching
      // conversations" bar against the prior cycle's count.
      _resumeConversationRefreshTotal = 0;
      _resumeConversationRefreshCompleted = 0;
      return;
    }
    _resumeConversationRefreshTotal = total;
    _resumeConversationRefreshCompleted = 0;
    _setSyncProgress(
      SyncProgress(
        label: 'Fetching conversations',
        completed: _resumeConversationRefreshCompleted,
        total: _resumeConversationRefreshTotal,
      ),
    );
    _resumeConversationProgressSafetyTimer = Timer(
      const Duration(milliseconds: Sync._resumeConversationProgressTimeoutMs),
      _onResumeConversationProgressTimeout,
    );
  }

  void _advanceResumeConversationProgress(int count) {
    if (_resumeConversationRefreshTotal <= 0 || count <= 0) return;
    _resumeConversationRefreshCompleted = min(
      _resumeConversationRefreshCompleted + count,
      _resumeConversationRefreshTotal,
    );
    _setSyncProgress(
      SyncProgress(
        label: 'Fetching conversations',
        completed: _resumeConversationRefreshCompleted,
        total: _resumeConversationRefreshTotal,
      ),
    );
    if (_resumeConversationRefreshCompleted >=
        _resumeConversationRefreshTotal) {
      _clearResumeConversationProgress();
    }
  }

  /// Force-clears the resume conversation progress indicator and any
  /// pending safety timer. Safe to call repeatedly; idempotent.
  void _clearResumeConversationProgress() {
    _resumeConversationProgressSafetyTimer?.cancel();
    _resumeConversationProgressSafetyTimer = null;
    _resumeConversationRefreshTotal = 0;
    _resumeConversationRefreshCompleted = 0;
    _setSyncProgress(null);
  }

  void _onResumeConversationProgressTimeout() {
    _resumeConversationProgressSafetyTimer = null;
    if (_resumeConversationRefreshTotal <= 0) return;
    final completed = _resumeConversationRefreshCompleted;
    final total = _resumeConversationRefreshTotal;
    // This is informational: the underlying invalidations may still be
    // running and will emit onDataChanged when they finish. The only
    // user-visible effect is that the "Fetching conversations" progress
    // bar is being force-cleared so it does not hang. Previously we
    // reported this to Sentry as a warning, which created noisy
    // "Sync resume conversation progress timeout (completed 0 of N)"
    // issues on slow networks.
    logger.info(
      '[Sync] resume conversation progress timed out after '
      '${Sync._resumeConversationProgressTimeoutMs}ms — '
      'completed $completed of $total; forcing UI clear '
      '(invalidations may still complete in background)',
    );
    _clearResumeConversationProgress();
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
    _resumeBatchTimer = Timer(const Duration(seconds: 2), () {
      _resumeBatchTimer = null;
      if (!isInitialized || InvalidateSync.isBackgrounded) return;
      if (_sessionsWithPendingSocketMessages.isEmpty) return;

      final batch = _sessionsWithPendingSocketMessages
          .take(Sync._maxResumeMessageSyncs)
          .toList();
      for (final sessionId in batch) {
        _sessionsWithPendingSocketMessages.remove(sessionId);
        try {
          if (_shouldForceTailRefreshForPendingSession(sessionId)) {
            _sessionsNeedingTailRefresh.add(sessionId);
          }
          if (!messagesSync.containsKey(sessionId)) {
            messagesSync[sessionId] = InvalidateSync(
              () => fetchMessages(sessionId),
              minInterval: Sync._messagesSyncMinInterval,
              name: 'fetchMessages',
              onRunningChanged: _onSyncRunningChanged,
              maxRetries: 0,
            );
          }
          _sessionsNeedingFetchProbe.add(sessionId);
          messagesSync[sessionId]?.invalidate();
        } on Object catch (e, st) {
          logger.warning(
            '[Sync] resume batch: failed to schedule fetch for '
            '$sessionId — continuing: $e',
          );
          unawaited(
            Sentry.captureException(
              e,
              stackTrace: st,
              hint: Hint.withMap(<String, dynamic>{
                'where': 'resumeBatch.invalidate',
                'sessionId': sessionId,
              }),
            ),
          );
        }
      }
      // ALWAYS advance — even if one or more sessions in the batch
      // threw — so the "Fetching conversations" bar never hangs.
      _advanceResumeConversationProgress(batch.length);

      logger.info(
        '[Sync] resume batch: fetched ${batch.length} sessions, '
        '${_sessionsWithPendingSocketMessages.length} remaining',
      );

      if (_sessionsWithPendingSocketMessages.isNotEmpty) {
        _scheduleResumeMessageBatch();
      }
    });
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

        if (socketIoClient.connectionStatus == ConnectionStatus.connected) {
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
                'socketStatus': socketIoClient.connectionStatus.name,
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
        // Snapshot inside the awaited callback to avoid a null-deref
        // if the visible session was cleared while waiting on the
        // queue.
        if (_visibleSessionId != null) {
          unawaited(
            sessionsSync.awaitQueue().then((_) {
              final vid = _visibleSessionId;
              if (vid != null) {
                messagesSync[vid]?.invalidate();
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
    _resumeConversationProgressSafetyTimer?.cancel();
    _resumeConversationProgressSafetyTimer = null;
    _resumeConversationRefreshTotal = 0;
    _resumeConversationRefreshCompleted = 0;
    _setSyncProgress(null);
    _reconnectCursorSnapshot = null;
    _sessionsRefreshDebounceTimer?.cancel();
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
    _lastMachineRpcWarnMs.clear();
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
    sessionGitStatusSync.dispose();

    for (final timer in _presenceTimers.values) {
      timer.cancel();
    }
    _presenceTimers.clear();

    _sessionDataKeys.clear();
    _sessionEncryptedDataKeys.clear();
    _machineDataKeys.clear();
    artifactManager?.clear();
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
    _sessionSpawnedModel.clear();
    _sessionSpawnedAgent.clear();
    _machineOfflineWarnedAtMs.clear();
    _autoRestoreInFlight.clear();
    _autoRestoreCompleters.clear();
    _autoRestoreProfileIds.clear();
    _lastEphemeralAt.clear();
    _pendingNewSessionIds.clear();
    _sessionUsage.clear();
    settingsManager?.clear();
    _isReady = false;
    _sessionListRefreshInFlight = null;
    _connectionStatus = ConnectionStatus.disconnected;
    isInitialized = false;
    _encryptionInitialized = false;
    // Dispose the outbox so retry timers don't fire after logout.
    messageOutbox.dispose();
  }
}
