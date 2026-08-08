part of 'sync_service.dart';

/// Upper bound for the reconnect-watchdog backoff.
///
/// The watchdog used to re-arm on a FIXED
/// [Sync._reconnectWatchdogDelayMs] period with no growth and no jitter,
/// forever, while disconnected. Every fire builds a brand-new Socket.IO
/// Manager whose own backoff counter restarts at zero, so the library's
/// exponential curve never got past its first few steps and the
/// steady-state cost of a sustained outage was ~2 dials every 15s — per
/// device, in lockstep across the fleet after a server restart.
const int _reconnectWatchdogMaxDelayMs = 120 * 1000;

/// Fraction of the base delay added as random jitter, so devices that
/// dropped together (server restart, carrier blip) do not redial in
/// lockstep.
const double _reconnectWatchdogJitterRatio = 0.25;

final Random _reconnectWatchdogRandom = Random();

/// Un-jittered watchdog delay for a 0-based [attempt]:
/// 15s, 30s, 60s, 120s, 120s…
int _reconnectWatchdogBaseDelayMs(int attempt) {
  var delay = Sync._reconnectWatchdogDelayMs;
  for (var i = 0; i < attempt; i++) {
    if (delay >= _reconnectWatchdogMaxDelayMs) break;
    delay *= 2;
  }
  return delay > _reconnectWatchdogMaxDelayMs
      ? _reconnectWatchdogMaxDelayMs
      : delay;
}

/// [_reconnectWatchdogBaseDelayMs] plus up to
/// [_reconnectWatchdogJitterRatio] of extra delay.
int _reconnectWatchdogDelayWithJitterMs(int attempt) {
  final base = _reconnectWatchdogBaseDelayMs(attempt);
  final spread = (base * _reconnectWatchdogJitterRatio).round();
  if (spread <= 0) return base;
  return base + _reconnectWatchdogRandom.nextInt(spread + 1);
}

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
    _deferredSocketDisconnectTimer?.cancel();
    _deferredSocketDisconnectTimer = null;
    _reconnectWatchdogTimer?.cancel();
    _reconnectWatchdogTimer = null;
    _reconnectWatchdogAttempt = 0;
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

    // NOTE: message-save debounce timers are deliberately NOT cancelled
    // here. _flushPendingMessageSaves() below iterates exactly that map
    // to write the pending tails; clearing it first turned the flush
    // into a silent no-op and dropped every un-persisted message tail on
    // background. The flush cancels and clears the timers itself.

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

    // Disconnect the socket only after a short grace period. Android can emit
    // hidden/inactive/resumed lifecycle bounces in tens of milliseconds; an
    // immediate disconnect turns those into websocket reconnect storms.
    _deferredSocketDisconnectTimer = Timer(
      const Duration(milliseconds: Sync._suspendSocketDisconnectDelayMs),
      () {
        _deferredSocketDisconnectTimer = null;
        if (!isInitialized || !InvalidateSync.isBackgrounded) {
          return;
        }
        socketIoClient.disconnect(
          preserveConnectionHistory: true,
          reason: DisconnectReason.lifecycleSuspend,
        );
      },
    );
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

    final socketDisconnectWasDeferred = _deferredSocketDisconnectTimer != null;
    _deferredSocketDisconnectTimer?.cancel();
    _deferredSocketDisconnectTimer = null;

    if (isRapidResume) {
      logger.debug(
        '[Sync] rapid resume — previous resume ${lastResumeGapMs}ms ago',
      );
    }
    final socketStatusAtResume = socketIoClient.connectionStatus;
    // A socket that still reports "connected" after a long background stay
    // is a zombie: the server-side session dies ~45s after the client stops
    // heartbeating, and the client cannot notice while the isolate is
    // suspended. When the OS suspends the app faster than the deferred
    // disconnect timer fires (common on iOS), resume() would otherwise trust
    // the stale status and skip both the reconnect and the watchdog, leaving
    // the app without live updates until the next ping timeout.
    //
    // The timestamp is consumed HERE and cleared immediately: nothing
    // else ever reset it, so after a single background stay it stayed
    // hours stale. NetworkMonitorService calls resume() on ANY
    // connectivity change including in the foreground, so every
    // wifi<->cellular handoff, tunnel, or VPN toggle re-read that stale
    // value, declared a perfectly healthy socket a zombie, tore it down,
    // and fired the full sync cascade (the `suspendDuration > 5s` gate
    // below was permanently true for the same reason).
    final suspendedAtMs = _lastSuspendedAtMs;
    _lastSuspendedAtMs = null;
    final backgroundedForMs = suspendedAtMs != null ? nowMs - suspendedAtMs : 0;
    final zombieSocket =
        socketStatusAtResume == ConnectionStatus.connected &&
        backgroundedForMs > Sync._zombieSocketMaxIdleMs;
    final socketNeedsReconnect =
        socketStatusAtResume != ConnectionStatus.connected || zombieSocket;
    logger.info(
      socketNeedsReconnect
          ? '[Sync] resuming — reconnecting socket'
                '${zombieSocket ? ' (zombie connection detected)' : ''}'
          : '[Sync] resuming — socket already connected',
    );
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Sync resume',
          category: 'sync.lifecycle',
          level: SentryLevel.info,
          data: <String, dynamic>{
            'rapidResume': isRapidResume,
            'lastResumeGapMs': lastResumeGapMs,
            'backgroundedForMs': backgroundedForMs,
            'visibleSessionId': _visibleSessionId,
            'pendingSocketSessions': _sessionsWithPendingSocketMessages.length,
            'messageSyncCount': messagesSync.length,
            'socketDisconnectWasDeferred': socketDisconnectWasDeferred,
            'zombieSocket': zombieSocket,
            'socketStatus': socketStatusAtResume.name,
          },
        ),
      ),
    );

    if (socketNeedsReconnect) {
      socketIoClient.reconnect(
        reason: zombieSocket
            ? DialReason.zombieDetected
            : DialReason.lifecycleResume,
        // A zombie socket's status is stale by definition, so never let
        // the in-flight guard trust it.
        force: zombieSocket,
      );
    }

    // Resume lightweight services immediately.
    messageOutbox.resume();
    NetworkMonitorService().resume();

    if (socketNeedsReconnect) {
      // Start a reconnection watchdog that fires if the socket hasn't
      // connected within a reasonable window. This covers the case where
      // Socket.IO's internal reconnection attempts are exhausted (e.g.
      // flaky network on resume) and no connectivity change event fires
      // to trigger a fresh reconnect. The watchdog is cancelled on
      // suspend() and on successful socket connect.
      //
      // The zombie path passes assumeDisconnected: its status still
      // claims "connected" (that is what makes it a zombie), so the
      // watchdog's usual connected-status short-circuit would skip
      // arming and leave the forced fresh dial without a safety net.
      _scheduleReconnectWatchdog(
        assumeDisconnected: zombieSocket,
        resetBackoff: true,
      );
    }

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

        // Use the snapshot captured (and cleared) at the top of resume()
        // — reading the field here would see either the value this
        // resume already consumed or, worse, a value left over from a
        // background stay many foreground events ago.
        final suspendDuration = suspendedAtMs != null
            ? DateTime.now().millisecondsSinceEpoch - suspendedAtMs
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
        //
        // isRapidResume also gates this: it was previously computed
        // (above) and only logged, so a resume that landed within
        // [Sync._resumeDebounceWindowMs] of the *previous* resume — an
        // OS-level pause/resume bounce, not a real backgrounding — still
        // replayed the full critical/deferred/background sync cascade
        // (~10 invalidations) every time. That was the single largest
        // contributor to battery drain from foreground/background
        // churn: 60 resumes in one session each re-fetched sessions,
        // machines, settings, profile, purchases, push token, native
        // update, and git status.
        final shouldRunGlobalInvalidation =
            suspendDuration > 5 * 1000 && !isRapidResume;
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
          _invalidateAllSyncs(phase: Sync._criticalSyncPhase);
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
              _requestTailRefresh(sessionId);
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
              messagesSync[sessionId] = _createMessagesSync(sessionId);
            }
          }
          final probeIntents = <String, ({int order, int requiredAfterSeq})>{
            for (final sessionId in sessionsToRefresh)
              sessionId: _captureMessageFetchProbeIntent(sessionId),
          };

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
          if (!sessionsSync.isPending &&
              !_resumeSessionsSyncSatisfiedByRecentRecovery()) {
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
                    _requestMessageFetchProbe(
                      sessionId,
                      intent: probeIntents[sessionId],
                    );
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
                  if (shouldRunGlobalInvalidation) {
                    _schedulePostResumeNonCriticalSyncs();
                  }
                }),
          );
        } else if (socketNeedsHttpFallback && !shouldRunGlobalInvalidation) {
          // Short resumes skip the broad invalidation above; use a sessions
          // HTTP fallback only when the socket has not reconnected yet.
          sessionsSync.invalidate();
        } else if (shouldRunGlobalInvalidation) {
          unawaited(
            sessionsSync.awaitQueue().whenComplete(
              _schedulePostResumeNonCriticalSyncs,
            ),
          );
        }
      },
    );
  }

  void _schedulePostResumeNonCriticalSyncs() {
    _invalidateAllSyncs(force: true, phase: Sync._deferredSyncPhase);
    _invalidateAllSyncs(force: true, phase: Sync._backgroundSyncPhase);
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
            _requestTailRefresh(sessionId);
          }
          if (!messagesSync.containsKey(sessionId)) {
            messagesSync[sessionId] = _createMessagesSync(sessionId);
          }
          _requestMessageFetchProbe(sessionId);
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
  /// The watchdog re-arms itself after each fire while the socket is
  /// still disconnected, so recovery is bounded instead of waiting out
  /// full Socket.IO backoff cycles between retry rounds.  Re-arming stops
  /// as soon as the socket connects (the reconnected handler cancels the
  /// timer), and the timer is cancelled by [suspend] and [shutdown].
  /// Each call resets the timer so reconnect-exhausted events and
  /// resume() don't stack timers.
  ///
  /// The re-arm period BACKS OFF (15s, 30s, 60s, 120s cap) with jitter.
  /// A flat period meant a sustained outage cost ~8 dials/minute forever,
  /// each one resetting the Socket.IO Manager's own backoff to zero, and
  /// the lack of jitter synchronised every device on the fleet after a
  /// server restart.  [resetBackoff] restarts the curve for deliberate
  /// user/lifecycle-driven reconnects, where a fast first probe is worth
  /// it.
  ///
  /// [assumeDisconnected] arms the watchdog even when the socket still
  /// reports [ConnectionStatus.connected]. The zombie path in [resume]
  /// passes true: that status is stale by definition there, and the
  /// fresh dial forced alongside it may still fail — recovery must
  /// stay watchdog-bounded either way.
  void _scheduleReconnectWatchdog({
    bool assumeDisconnected = false,
    bool resetBackoff = false,
  }) {
    _reconnectWatchdogTimer?.cancel();
    if (resetBackoff) {
      _reconnectWatchdogAttempt = 0;
    }
    // If already connected, no watchdog needed. Zombie detection proves
    // the reported status can be stale, so callers that forced a dial
    // on a zombie pass assumeDisconnected to arm anyway.
    if (!assumeDisconnected &&
        socketIoClient.connectionStatus == ConnectionStatus.connected) {
      _reconnectWatchdogTimer = null;
      _reconnectWatchdogAttempt = 0;
      return;
    }
    final attempt = _reconnectWatchdogAttempt;
    _reconnectWatchdogTimer = Timer(
      Duration(milliseconds: _reconnectWatchdogDelayWithJitterMs(attempt)),
      () {
        _reconnectWatchdogTimer = null;
        if (!isInitialized || InvalidateSync.isBackgrounded) return;

        if (socketIoClient.connectionStatus == ConnectionStatus.connected) {
          _reconnectWatchdogAttempt = 0;
          return;
        }

        // A dial is already negotiating — redialing here would abandon a
        // handshake the server may well complete (it allows 20s) and the
        // server would book the abandoned one as an involuntary
        // disconnect. Re-arm without touching the socket.
        if (socketIoClient.connectionStatus == ConnectionStatus.connecting) {
          logger.info(
            '[Sync] reconnect watchdog skipped — a dial is already '
            'in flight',
          );
          _reconnectWatchdogAttempt = attempt + 1;
          _scheduleReconnectWatchdog();
          return;
        }

        _reconnectWatchdogAttempt = attempt + 1;

        logger.warning(
          '[Sync] reconnect watchdog fired (attempt ${attempt + 1}) — '
          'socket still disconnected, forcing fresh reconnect',
        );
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: 'Sync reconnect watchdog triggered',
              category: 'sync.lifecycle',
              level: SentryLevel.warning,
              data: <String, dynamic>{
                'socketStatus': socketIoClient.connectionStatus.name,
                'attempt': attempt + 1,
                'visibleSessionId': _visibleSessionId,
              },
            ),
          ),
        );

        socketIoClient.reconnect(reason: DialReason.watchdog);
        // Refresh the expensive sessions/catalog path only when it has not
        // run recently. The visible chat fetch below still runs after each
        // watchdog cycle so foreground recovery does not wait on catalog
        // freshness.
        final watchdogNowMs = DateTime.now().millisecondsSinceEpoch;
        if (_shouldRunReconnectGlobalInvalidation(
          watchdogNowMs,
          resumeHttpFallbackRecentlyFired: false,
        )) {
          _invalidateAllSyncs(force: true);
        } else {
          logger.info(
            '[Sync] reconnect watchdog skipped broad invalidation; '
            'recent sessions recovery already ran',
          );
        }

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

        // Re-arm while still disconnected, on the NEXT backoff step.
        // reconnect() above only started a fresh Socket.IO cycle; if that
        // also fails (network still settling after wake, server restart),
        // the library would otherwise burn through its backoff attempts
        // before the exhausted-listener reschedules this watchdog.
        // _scheduleReconnectWatchdog() cancels the current timer first and
        // no-ops once connected, and the reconnected handler cancels the
        // timer on success.
        _scheduleReconnectWatchdog();
      },
    );
  }

  /// Force a fresh socket connection and (re-)arm the reconnect watchdog.
  ///
  /// Entry point for the user-facing "Reconnect now" action. A bare
  /// [SocketIoClient.reconnect] leaves the app without a retry safety net
  /// when the fresh dial also fails (e.g. the network is still settling
  /// after the device wakes); routing the manual action through here keeps
  /// the watchdog armed so recovery stays bounded and the tap can never
  /// degrade into a single silent failed dial.
  void forceReconnect({String reason = 'manual'}) {
    if (!isInitialized) return;
    logger.info('[Sync] forceReconnect ($reason)');
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Sync forceReconnect',
          category: 'sync.lifecycle',
          level: SentryLevel.info,
          data: <String, dynamic>{
            'reason': reason,
            'socketStatus': socketIoClient.connectionStatus.name,
          },
        ),
      ),
    );
    socketIoClient.reconnect(reason: DialReason.userManual, force: true);
    _scheduleReconnectWatchdog(resetBackoff: true);
  }

  /// Shutdown sync engine and clear volatile state.
  Future<void> shutdown() async {
    _deferredSocketDisconnectTimer?.cancel();
    _deferredSocketDisconnectTimer = null;
    _reconnectWatchdogTimer?.cancel();
    _reconnectWatchdogTimer = null;
    _reconnectWatchdogAttempt = 0;
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
    _sessionSocketCatchUpAfterSeq.clear();
    _sessionsRestoredFromMessageCache.clear();
    _sessionsNeedingLegacySocketGapRepair.clear();
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
    socketIoClient.disconnect(reason: DisconnectReason.appShutdown);

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
    //
    // [_autoRestoreFailureController] follows the same convention;
    // [_safeEmitAutoRestoreFailure] guards `isClosed` so the stream
    // silently no-ops if a test ever closes it directly.

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
    _lastNoEmbedEventCursorSeq.clear();
    // _lastNoEmbedEventCursorSeq cleared in shutdown (per cursor seq must
    // not survive logout — a stale cursor would suppress the post-login
    // no-embed probe cooldown).
    _lastMachineRpcWarnMs.clear();
    _sessionsWithPendingSocketMessages.clear();
    _notifiedPermissionIds.clear();
    // _sessionMessagesRevision cleared in shutdown (per-session revision
    // counter must reset so a new login does not compare revisions
    // against a different user's session IDs and skip change notifications).
    _sessionMessagesRevision.clear();
    // _sessionContentSignatures cleared in shutdown (signatures from
    // the previous user's sessions must not suppress merge of new
    // messages after login).
    _sessionContentSignatures.clear();
    // _sessionsNeedingFetchProbe cleared in shutdown (set membership
    // from the previous user would force spurious fetch probes for
    // sessions that do not exist post-login).
    _sessionsNeedingFetchProbe.clear();
    _messageFetchProbeIntents.clear();
    _messageFetchCoverage.clear();
    _messageFetchWorkOrder = 0;
    // _sessionsNeedingVisibleRegroup cleared in shutdown (orphans from
    // the previous user would be re-grouped on next login, causing
    // spurious UI work).
    _sessionsNeedingVisibleRegroup.clear();
    // _sessionsNeedingSidechainRegroup cleared in shutdown (sidechain
    // regroup requests for the previous user's sessions would fire on
    // next login against unrelated sessions).
    _sessionsNeedingSidechainRegroup.clear();
    // _sidechainRegroupSweepCount cleared in shutdown (per-session
    // sweep counters must not leak across logout — a high count
    // would prevent the orphan-absorption cap from ever resetting).
    _sidechainRegroupSweepCount.clear();
    // _orphanFetchOlderAttemptedMs cleared in shutdown (per-session
    // throttle timestamps must not survive logout — a stale entry
    // would block the post-login fetchOlder orphan-recovery path
    // for an unrelated session).
    _orphanFetchOlderAttemptedMs.clear();
    // _orphanFetchOlderNoProgressCount cleared in shutdown (per-session
    // no-progress counters must reset so the next user cannot inherit
    // a near-cap counter that blocks orphan recovery immediately).
    _orphanFetchOlderNoProgressCount.clear();
    // _orphanWalkbackOrphanIds/_orphanWalkbackParentKeys cleared in
    // shutdown (per-session tracked orphan-id/parent-key sets from a
    // different user would suppress a fresh walk-back budget on next
    // login).
    _orphanWalkbackOrphanIds.clear();
    _orphanWalkbackParentKeys.clear();
    // _orphanSuppressedUntilMs cleared in shutdown (per-session
    // suppression windows must not leak across logout).
    _orphanSuppressedUntilMs.clear();
    // _dekFallbackCaptured cleared in shutdown (the per-launch
    // DEK-fallback Sentry guard must reset so the next user gets
    // a fresh capture opportunity).
    _dekFallbackCaptured.clear();
    // _profileModelKillInFlight cleared in shutdown (in-flight kill
    // tracking from the previous user must not deadlock the next
    // user's sendMessage auto-restore path).
    _profileModelKillInFlight.clear();
    // _loopsBySession cleared in shutdown (loop list per session
    // belongs to the previous user; must not leak into the new
    // session IDs after login).
    _loopsBySession.clear();
    // _workflowsBySession cleared in shutdown (workflow runs per session
    // belong to the previous user; must not leak into the new session IDs
    // after login).
    _workflowsBySession.clear();
    _workflowRefreshesInFlight.clear();
    _workflowListUnsupportedCapabilities.clear();
    _loopListUnsupportedCapabilities.clear();
    _workflowRefreshBackoffUntil.clear();
    _workflowRefreshFailureCount.clear();
    _clearRpcCapabilityPolicyState();
    // _dataChangeCounter reset in shutdown (monotonic counter must
    // restart at 0 so the next login's providers see a clean
    // baseline and do not compare against stale last-seen values).
    _dataChangeCounter = 0;
    // _domainChangeCounters reset in shutdown (per-domain monotonic
    // counters must restart so the next login's per-domain
    // subscribers see a clean baseline).
    for (final domain in SyncDomain.values) {
      _domainChangeCounters[domain] = 0;
    }
    // _activeSyncCount reset in shutdown (running-sync count must
    // restart at 0 so the next login's UI does not show a stale
    // "syncing" indicator).
    _activeSyncCount = 0;
    // _runningSyncNames cleared in shutdown (running-sync names
    // belong to the previous user — leaking them would show the
    // wrong sync label on first launch of the next login).
    _runningSyncNames.clear();

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
    _sessionEncryptionRecoveryAttempts.clear();
    _machineDataKeys.clear();
    artifactManager?.clear();
    for (final timer in _saveMsgsDebounceTimers.values) {
      timer.cancel();
    }
    _saveMsgsDebounceTimers.clear();
    _saveMsgsFirstScheduledAtMs.clear();
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

  bool _resumeSessionsSyncSatisfiedByRecentRecovery() {
    if (_forceFullFetchNext) return false;
    final lastGlobalInvalidationMs = _lastInvalidateAllSyncsAtMs;
    if (lastGlobalInvalidationMs == null) return false;
    final lastSessionsRunEndMs = sessionsSync.lastRunEndMs;
    if (lastSessionsRunEndMs == null) return false;
    if (lastSessionsRunEndMs < lastGlobalInvalidationMs) return false;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return nowMs - lastSessionsRunEndMs <
        Sync._sessionsSyncMinInterval.inMilliseconds;
  }
}
