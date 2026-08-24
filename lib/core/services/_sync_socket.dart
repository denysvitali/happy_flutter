part of 'sync_service.dart';

extension SyncSocket on Sync {
  void _socketSend(String event, dynamic data) {
    if (testSocketSendOverride != null) {
      testSocketSendOverride!(event, data);
    } else {
      socketIoClient.send(event, data);
    }
  }

  /// Initialize sync with credentials and encryption
  Future<void> create(
    AuthCredentials credentials,
    Encryption encryption,
  ) async {
    if (isInitialized) {
      logger.info('Sync already initialized');
      return;
    }

    this.credentials = credentials;
    this.encryption = encryption;
    _encryptionInitialized = true;
    anonID = encryption.anonId;
    serverID = parseToken(credentials.token);
    _constructManagers(encryption);
    await _init();

    // Await initial syncs in parallel — these are independent HTTP
    // fetches that were previously sequential, adding latency to
    // first-login initialization.
    await Future.wait([
      settingsSync.awaitQueue(),
      profileSync.awaitQueue(),
      purchasesSync.awaitQueue(),
    ]);

    isInitialized = true;
  }

  /// Restore sync state from disk (app restart)
  Future<void> restore(
    AuthCredentials credentials,
    Encryption encryption,
  ) async {
    if (isInitialized) {
      logger.info('Sync already initialized');
      return;
    }

    _runtimeGeneration++;
    _isReady = false;

    this.credentials = credentials;
    this.encryption = encryption;
    _encryptionInitialized = true;
    anonID = encryption.anonId;
    serverID = parseToken(credentials.token);
    _constructManagers(encryption);
    await _init();
    // isInitialized is set early inside _init() after cache restore.
  }

  /// Builds the extracted state managers that [Sync] delegates to.
  ///
  /// Shared by [create] and [restore] — both entry points need the exact
  /// same wiring, and duplicating it once caused the two paths to drift.
  void _constructManagers(Encryption encryption) {
    artifactManager = ArtifactManager(
      encryption: encryption,
      artifactsSyncGetter: () => artifactsSync,
      onDataChanged: _notifyDataChanged,
    );
    settingsManager = SettingsManager(
      encryption: encryption,
      nativeUpdateFreshnessMs: Sync._nativeUpdateFreshnessMs,
      isTransientConnectionError: Sync._isTransientConnectionError,
      settingsSyncGetter: () => settingsSync,
      profileSyncGetter: () => profileSync,
      purchasesSyncGetter: () => purchasesSync,
      onDataChanged: _notifyDataChanged,
    );
  }

  /// Internal initialization
  Future<void> _init() async {
    final runtimeGeneration = _runtimeGeneration;
    // Restore persisted message cursors
    _sessionLastSeq
      ..clear()
      ..addAll(MMKVStorage().getSessionLastSeq());
    _sessionFirstLoadedSeq
      ..clear()
      ..addAll(MMKVStorage().getSessionFirstLoadedSeq());
    // Restore sessions and settings in parallel — they are independent
    // MMKV reads and running them sequentially adds ~200ms to cold start.
    late final Settings restoredSettings;
    await Future.wait([
      _restoreSessionsCache(),
      MMKVStorage().getSettings().then((s) => restoredSettings = s),
    ]);
    if (runtimeGeneration != _runtimeGeneration) return;

    // Restore cached settings so that loadFromSync() serves the user's
    // last-known settings instead of defaults before syncSettings()
    // completes.  Without this, there is a race between checkAuth()
    // (which calls loadFromSync → reads _settingsSnapshot) and
    // _initializeTheme() (which loads from MMKV).  If checkAuth wins,
    // the Riverpod state briefly reverts to Settings() defaults.
    settingsManager?.settingsSnapshot = restoredSettings;

    // Warm cached messages only for the most recent sessions.  Restoring all
    // 200 cached sessions does synchronous MMKV reads/jsonDecode work on the
    // UI isolate and can block startup for seconds.  Older sessions load
    // lazily when opened.
    unawaited(_restoreRecentCachedMessagesAsync());

    // Initialize sync managers
    sessionsSync = _createSync(
      fetchSessions,
      'fetchSessions',
      minInterval: Sync._sessionsSyncMinInterval,
    );
    settingsSync = _createSync(
      syncSettings,
      'syncSettings',
      minInterval: Sync._settingsSyncMinInterval,
    );
    profileSync = _createSync(fetchProfile, 'fetchProfile');
    purchasesSync = _createSync(syncPurchases, 'syncPurchases');
    machinesSync = _createSync(
      fetchMachines,
      'fetchMachines',
      minInterval: Sync._machinesSyncMinInterval,
    );
    pushTokenSync = _createSync(syncPushToken, 'syncPushToken');
    nativeUpdateSync = _createSync(fetchNativeUpdate, 'fetchNativeUpdate');
    artifactsSync = _createSync(fetchArtifactsList, 'fetchArtifactsList');
    sessionGitStatusSync = _createSync(
      _fetchSessionGitStatus,
      'fetchSessionGitStatus',
    );
    _criticalSyncManagersInitialized = true;

    // Mark initialized early so that provider loadFromSync() can serve
    // cached sessions and messages immediately, before network syncs
    // complete.  Screens subscribing to onDataChanged will pick up the
    // cached snapshot within the debounce window (~100ms).
    isInitialized = true;
    _notifyDataChanged(SyncDomain.values.toSet());

    // Cold-start loops hydration: populate the in-memory loops map
    // from MMKV for every session that came back from the cache
    // restore above. Defer to a microtask so it doesn't block
    // isInitialized = true and the first frame paint.
    unawaited(Future<void>.microtask(hydrateAllFromCache));

    // Cold-start workflows hydration: populate the in-memory workflows
    // map from MMKV for every session that came back from the cache.
    unawaited(Future<void>.microtask(hydrateAllWorkflowsFromCache));

    // Setup socket connection
    final serverUrl = getServerUrl();
    socketIoClient.connect(
      serverUrl: serverUrl,
      token: credentials.token,
      clientType: 'user-scoped',
    );

    // Subscribe to updates
    subscribeToUpdates();

    // Invalidate all syncs. Preserve the sessions delta cursor when a cached
    // session snapshot exists so cold launches can use incremental sync.
    _invalidateAllSyncs(
      force: true,
      resetSessionDeltaCursor: _lastSessionsFetchedAt == null,
    );

    // Wait for sessions and machines to load before marking as ready.
    // NOTE: Previously this was awaited, blocking restore() on every warm
    // start until the HTTP fetches completed (2-9s). Now runs fire-and-forget
    // so AuthState.authenticated is set immediately after MMKV cache restore.
    final readyGeneration = _runtimeGeneration;
    unawaited(
      Future.wait([sessionsSync.awaitQueue(), machinesSync.awaitQueue()])
          .then((_) {
            if (readyGeneration == _runtimeGeneration && isInitialized) {
              _isReady = true;
            }
          })
          .catchError((Object error, StackTrace stack) {
            logger.error('Failed initial ready sync', error, stack);
            Sentry.captureException(error, stackTrace: stack);
            return null; // Error handled — do not propagate
          }),
    );

    // Configure and restore the message outbox after sync is ready so
    // the encryption context is available for re-sends.
    messageOutbox.configure(
      deliver: _deliverOutboxEntry,
      onStatusChanged: (sessionId, localId, status) {
        _updateMessageSendStatus(sessionId, localId, status);
        _notifySessionMessagesChanged(sessionId);
      },
    );
    unawaited(
      messageOutbox.restoreAndFlush().then((_) {
        // The encrypted outbox can survive even when an Android MMKV cache
        // worker write did not. Its localIds were still minted by this client
        // in an earlier process lifetime, so seed them before an async status
        // callback observes the server ack. Otherwise every restored send is
        // misclassified as unknown_acked_local_id after restart.
        for (final entry in messageOutbox.entries) {
          messageInvariantMonitor.seedSentLocalId(entry.localId);
        }
        for (final entry in messageOutbox.deadEntries) {
          messageInvariantMonitor.seedSentLocalId(entry.localId);
        }
        // Cold-start race: the socket can reach `connected` before the
        // MMKV restore above has loaded the dead-letter bucket, in which
        // case the connect-time reviveTransientDead ran against an empty
        // bucket. Check again once the entries are actually in memory.
        if (socketIoClient.connectionStatus == ConnectionStatus.connected) {
          unawaited(messageOutbox.reviveTransientDead(reason: 'cold start'));
        }
      }),
    );
  }

  /// Creates an [InvalidateSync] wired to the standard
  /// [_onSyncRunningChanged] callback used by every sync manager in
  /// [_init]. Collapses near-identical boilerplate.
  InvalidateSync _createSync(
    Future<void> Function() action,
    String name, {
    Duration? minInterval,
  }) => InvalidateSync(
    action,
    minInterval: minInterval,
    name: name,
    onRunningChanged: _onSyncRunningChanged,
  );

  void _invalidateAllSyncs({
    bool force = false,
    bool resetSessionDeltaCursor = false,
    @visibleForTesting int? phase,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastRunMs = _lastInvalidateAllSyncsAtMs;
    if (!force &&
        lastRunMs != null &&
        nowMs - lastRunMs < Sync._invalidateAllSyncsCooldownMs) {
      logger.info('Skipping duplicate global sync invalidation');
      return;
    }
    _lastInvalidateAllSyncsAtMs = nowMs;
    powerDiagnostics.recordSyncInvalidation(
      phase == null ? 'all' : 'phase-$phase',
      global: true,
    );

    if (resetSessionDeltaCursor) {
      _lastSessionsFetchedAt = null;
    }

    // Phase 0: Critical syncs - immediate invalidation.
    // Keep launch limited to the data needed for the default sessions tab.
    if (phase == null || phase == Sync._criticalSyncPhase) {
      sessionsSync.invalidate();
      powerDiagnostics.recordSyncInvalidation('fetchSessions');

      logger.info('Invalidated critical syncs (sessions)');
    }

    // Phase 1: Deferred syncs needed when the user navigates to a
    // chat / settings tab. Fire on the next event loop tick — this
    // lets fetchSessions (phase 0) get its HTTP request into Dio's
    // connection pool first without adding visible latency to the
    // machine-online indicator. The previous 1 s wait was the
    // primary cause of "machine stays offline for several seconds
    // after daemon start" — the daemon's first machine-activity
    // heartbeat could arrive and patch activeAt before the catalog
    // fetch even fired, leaving the user staring at a stale
    // offline indicator. Cancel-on-suspend still guards the
    // background race.
    if (phase == null || phase == Sync._deferredSyncPhase) {
      _deferredSyncsTimer?.cancel();
      final staggerMs =
          Sync._deferredSyncPhaseBaseDelayMs +
          Sync._syncPhaseJitterRng.nextInt(Sync._deferredSyncPhaseJitterMs);
      _deferredSyncsTimer = Timer(Duration(milliseconds: staggerMs), () {
        // Only invalidate if sync is still initialized to avoid
        // errors after logout/dispose
        if (!isInitialized) return;
        logger.debug(
          'Invalidating deferred syncs '
          '(machines, settings, profile)',
        );
        machinesSync.invalidate();
        settingsSync.invalidate();
        profileSync.invalidate();
        powerDiagnostics.recordSyncInvalidation('deferredSyncs');
      });
    }

    // Phase 2: Truly-background syncs — none feed a screen the user
    // is likely on within the first few seconds of cold start. Run
    // them ~3s in so they don't compete for the connection pool /
    // event loop with phases 0+1.
    if (phase == null || phase == Sync._backgroundSyncPhase) {
      _backgroundSyncsTimer?.cancel();
      _backgroundSyncsTimer = Timer(const Duration(seconds: 3), () {
        if (!isInitialized) return;
        logger.debug(
          'Invalidating background syncs '
          '(purchases, push token, native update, git status)',
        );
        purchasesSync.invalidate();
        pushTokenSync.invalidate();
        nativeUpdateSync.invalidate();
        sessionGitStatusSync.invalidate();
        powerDiagnostics.recordSyncInvalidation('backgroundSyncs');
      });
    }
  }

  /// Leading-edge + trailing-edge debounced data change notification.
  ///
  /// The counter is incremented immediately so that callers like
  /// `loadFromSync()` can detect the change without waiting for the
  /// debounce timer.
  ///
  /// The stream emission uses a leading+trailing pattern: the first
  /// call in a quiet window fires immediately (so the UI updates
  /// promptly), then subsequent calls within 250ms are coalesced
  /// into a single trailing emission.  This prevents the old
  /// cancel-and-restart pattern from deferring the emission
  /// indefinitely during sustained streaming (events every 20-50ms).
  ///
  /// Scoping rule (perf P0): when [domains] is a non-null subset, this
  /// method emits ONLY on the per-domain stream ([onDomainChanged]).
  /// The global firehose [onDataChanged] is reserved for the
  /// "truly everything" case where the caller passes `null`. Screens
  /// using [SyncSubscriptionMixin.subscribeToDomains] receive the
  /// scoped event; the dataChangeCounter still ticks so any
  /// counter-based dedup paths see progress.
  void _notifyDataChanged([Set<SyncDomain>? domains]) {
    _dataChangeCounter++;
    // Piggybacked sweep: throttled to one pass per
    // idleSessionShrinkSweepIntervalMs, and the guard is two int compares —
    // safe on this hot path. Needs no timer, so there is no lifecycle
    // wiring to leak: a quiet app runs no sweeps and accumulates nothing.
    _maybeShrinkIdleSessionWindows();
    final effectiveDomains = domains ?? SyncDomain.values.toSet();
    for (final domain in effectiveDomains) {
      _domainChangeCounters[domain] = (_domainChangeCounters[domain] ?? 0) + 1;
      final existingTimer = _domainChangeDebounceTimers[domain];
      if (existingTimer == null || !existingTimer.isActive) {
        if (!_domainChangeController.isClosed) {
          _domainChangeController.add(domain);
        }
        _domainChangePendingTrailing.remove(domain);
        _domainChangeDebounceTimers[domain] = Timer(
          const Duration(milliseconds: 250),
          () {
            if (_domainChangePendingTrailing.remove(domain) &&
                !_domainChangeController.isClosed) {
              _domainChangeController.add(domain);
            }
          },
        );
      } else {
        _domainChangePendingTrailing.add(domain);
      }
    }
    // Only fire the global firehose for the truly-everything case
    // (domains == null). Scoped callers are already routed through
    // onDomainChanged above; emitting globally too would wake every
    // subscriber app-wide on every per-domain change.
    if (domains != null) {
      return;
    }
    // If no timer is running, fire immediately (leading edge) and
    // start a cooldown window.
    if (_dataChangeDebounceTimer == null ||
        !_dataChangeDebounceTimer!.isActive) {
      _emitDataChangeSpan();
      if (!_dataChangeController.isClosed) {
        _dataChangeController.add(null);
      }
      _dataChangePendingTrailing = false;
      _dataChangeDebounceTimer = Timer(const Duration(milliseconds: 250), () {
        // Trailing edge: emit once more if calls arrived during
        // the cooldown window.
        if (_dataChangePendingTrailing && !_dataChangeController.isClosed) {
          _dataChangeController.add(null);
        }
        _dataChangePendingTrailing = false;
      });
    } else {
      // Timer is active — mark that a trailing emission is needed.
      _dataChangePendingTrailing = true;
    }
  }

  /// Immediately emit data change notification, bypassing debounce.
  /// Use sparingly when listeners need to be notified synchronously.
  ///
  /// Scoping rule (perf P0): a non-null [domains] only emits on the
  /// per-domain stream. `domains == null` flushes the global firehose
  /// too, matching the [_notifyDataChanged] semantics.
  void _flushDataChanged([Set<SyncDomain>? domains]) {
    _dataChangeCounter++;
    final effectiveDomains = domains ?? SyncDomain.values.toSet();
    for (final domain in effectiveDomains) {
      _domainChangeDebounceTimers[domain]?.cancel();
      _domainChangeCounters[domain] = (_domainChangeCounters[domain] ?? 0) + 1;
      if (!_domainChangeController.isClosed) {
        _domainChangeController.add(domain);
      }
    }
    if (domains != null) {
      return;
    }
    _dataChangeDebounceTimer?.cancel();
    if (!_dataChangeController.isClosed) {
      _dataChangeController.add(null);
    }
  }

  /// Debounced session-message change notification.
  /// Coalesces rapid token-level updates into one emission per 200ms window
  /// per session, preventing the chat screen from rebuilding on every token.
  void _notifySessionMessagesChanged(String sessionId) {
    // Bump first: this is the single funnel for every real message-list
    // change, so the revision reliably moves whenever content mutates.
    _bumpMessagesRevision(sessionId);
    _notifySessionMessagesChangedUiOnly(sessionId);
    // Persist updated messages to MMKV for instant cold-start load.
    _scheduleSaveMessages(sessionId);
  }

  /// Like [_notifySessionMessagesChanged] but only emits the UI
  /// stream event — does NOT schedule a cache save.  Use this when
  /// no messages actually changed (e.g. fetchMessages early-exit).
  ///
  /// Uses leading+trailing edge debounce: the first call in a quiet
  /// window fires immediately (so new messages appear instantly), then
  /// subsequent calls within 200ms are coalesced into a single trailing
  /// emission.  This prevents the old cancel-and-restart pattern from
  /// deferring the notification indefinitely during streaming.
  void _notifySessionMessagesChangedUiOnly(String sessionId) {
    final timer = _sessionMessageDebounceTimers[sessionId];
    // If no timer is running, fire immediately (leading edge) and
    // start a cooldown window.
    if (timer == null || !timer.isActive) {
      if (!_sessionMessageChangeController.isClosed) {
        _sessionMessageChangeController.add(sessionId);
      }
      _sessionMessagePendingTrailing.remove(sessionId);
      _sessionMessageDebounceTimers[sessionId] = Timer(
        const Duration(milliseconds: 200),
        () {
          _sessionMessageDebounceTimers.remove(sessionId);
          // Trailing edge: emit once more if calls arrived during
          // the cooldown window.
          if (_sessionMessagePendingTrailing.remove(sessionId) &&
              !_sessionMessageChangeController.isClosed) {
            _sessionMessageChangeController.add(sessionId);
          }
        },
      );
    } else {
      // Timer is active — mark that a trailing emission is needed.
      _sessionMessagePendingTrailing.add(sessionId);
    }
  }

  /// Advance the message seq cursor for [sessionId] and keep
  /// [Session.lastSeq] in sync so that gap detection and tail-load
  /// calculations use a current value (the sessions API may lag behind
  /// the actual cursor because inline socket messages advance it
  /// faster than [fetchSessions] runs).
  void _advanceSeqCursor(String sessionId, int newSeq) {
    if (!_cursorManager.advanceSeqCursor(sessionId, newSeq)) {
      return;
    }
    _scheduleSaveSeq();

    // Keep session.lastSeq in sync so
    // Tail-load cursor calculation uses the
    // authoritative cursor, not the stale value from the
    // last fetchSessions response.
    final session = _sessions[sessionId];
    if (session != null && (session.lastSeq ?? 0) < newSeq) {
      _sessions[sessionId] = session.copyWith(lastSeq: newSeq);
    }
  }

  void _seedSeqCursorFromCache(String sessionId, int newSeq) {
    if (!_cursorManager.advanceSeqCursor(sessionId, newSeq)) {
      return;
    }
    _scheduleSaveSeq();
  }

  /// Debounced MMKV persist for session seq cursors.
  ///
  /// [saveSessionLastSeq] does a synchronous jsonEncode + MMKV disk write on
  /// the main thread. Called on every pagination page during [fetchMessages],
  /// it was the single biggest cause of jank when opening large sessions.
  /// We debounce to a 500ms window so rapid page fetches batch into one write.
  void _scheduleSaveSeq() {
    _saveSeqDebounceTimer?.cancel();
    _saveSeqDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveSeqDebounceTimer = null;
      unawaited(
        MMKVStorage().saveSessionLastSeqAsync(
          Map.unmodifiable(_sessionLastSeq),
        ),
      );
    });
  }

  /// Background serialization for the oldest loaded cursor map, debounced.
  ///
  /// Every call copies the whole cursor map twice and spawns an isolate
  /// (`saveAllAsync` -> `compute`), and callers fire it in bulk: pagination
  /// advances it once per page, and the residency-budget shrink calls it once
  /// per shrunk session — so a switch that shrinks 20 sessions used to queue
  /// 20 back-to-back isolate spawns on the UI isolate. Coalescing to one
  /// write per 500 ms window matches [_scheduleSaveSeq]; `shutdown()` still
  /// flushes the cursor map synchronously, so nothing is lost.
  void _scheduleSaveFirstLoadedSeq() {
    _saveFirstLoadedSeqDebounceTimer?.cancel();
    _saveFirstLoadedSeqDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        _saveFirstLoadedSeqDebounceTimer = null;
        unawaited(
          MMKVStorage().saveSessionFirstLoadedSeqAsync(
            Map.unmodifiable(_sessionFirstLoadedSeq),
          ),
        );
      },
    );
  }

  /// Debounced MMKV persist for a single session's message list.
  ///
  /// Batches rapid upserts (e.g. streaming tokens) into one disk write
  /// per session every [_saveMsgsDebounceMs], keeping only the last ~200
  /// messages in the persisted copy. The in-memory list retains all
  /// messages.
  ///
  /// Perf P0: a hard ceiling of [_saveMsgsMaxDelayMs] guarantees the
  /// disk write fires even under sustained streaming where the
  /// debounce would otherwise keep resetting every token (~20-50ms),
  /// preventing the cache from ever flushing until streaming stops.
  void _scheduleSaveMessages(String sessionId) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final firstScheduledAt = _saveMsgsFirstScheduledAtMs[sessionId];
    _saveMsgsFirstScheduledAtMs[sessionId] = firstScheduledAt ?? nowMs;
    // Remaining budget before the max-delay ceiling kicks in.
    final elapsed = firstScheduledAt == null ? 0 : nowMs - firstScheduledAt;
    final remainingBudget = _saveMsgsMaxDelayMs - elapsed;
    final delayMs = remainingBudget <= 0
        ? 0
        : remainingBudget < _saveMsgsDebounceMs
        ? remainingBudget
        : _saveMsgsDebounceMs;
    _saveMsgsDebounceTimers[sessionId]?.cancel();
    _saveMsgsDebounceTimers[sessionId] = Timer(
      Duration(milliseconds: delayMs),
      () {
        _saveMsgsDebounceTimers.remove(sessionId);
        _saveMsgsFirstScheduledAtMs.remove(sessionId);
        final msgs = _sessionMessages[sessionId];
        if (msgs != null) {
          // Persist all messages including sidechain entries.  The
          // sidechain grouper runs on restore
          // (_restoreAllCachedMessages) so children are correctly
          // re-parented.  Previously we stripped isSidechain messages
          // here, which permanently lost them on cold-start.
          unawaited(
            MessageCacheService().saveMessagesAsync(
              sessionId,
              msgs,
              revision: messagesRevision(sessionId),
            ),
          );
        }
      },
    );
  }

  /// Debounce window for the per-session cache write.
  ///
  /// Raised from 1000 ms after production showed 232 MMKV writes of
  /// 150-395 ms in 24 h, clustered on the two chattiest sessions. The
  /// cache is a cold-start accelerator, not the source of truth (the
  /// server tail is refetched on open), so trading a wider window for
  /// roughly half the writes is the right side of the durability
  /// tradeoff — provided the suspend flush actually runs.
  ///
  /// Mutable only through [SyncTestHelpers.testSetSaveMessagesTiming];
  /// production always runs [_saveMsgsDebounceMsDefault].
  static int _saveMsgsDebounceMs = _saveMsgsDebounceMsDefault;
  static const int _saveMsgsDebounceMsDefault = 2000;

  /// Hard ceiling on how long sustained streaming can defer a write.
  ///
  /// Fifteen seconds avoids the five-second cross-session snapshot storms
  /// observed in production while suspend still provides a synchronous
  /// durability fence before the OS can kill the app.
  ///
  /// Mutable only through [SyncTestHelpers.testSetSaveMessagesTiming];
  /// production always runs [_saveMsgsMaxDelayMsDefault].
  static int _saveMsgsMaxDelayMs = _saveMsgsMaxDelayMsDefault;
  static const int _saveMsgsMaxDelayMsDefault = 15000;

  /// Immediately flush all pending debounced message saves so the MMKV
  /// cache is not stale when the app is backgrounded or killed.
  void _flushPendingMessageSaves() {
    final timerSessionIds = _saveMsgsDebounceTimers.keys.toList();
    for (final entry in _saveMsgsDebounceTimers.entries) {
      entry.value.cancel();
    }
    MessageCacheService().flushPendingMessages(
      _sessionMessages,
      additionalSessionIds: timerSessionIds,
      latestRevisions: _sessionMessagesRevision,
    );
    _saveMsgsDebounceTimers.clear();
    _saveMsgsFirstScheduledAtMs.clear();
  }

  /// Immediately deliver any pending trailing-edge session message
  /// notifications so the UI is up-to-date before backgrounding.
  void _flushSessionMessageNotifications() {
    if (_sessionMessageDebounceTimers.isEmpty) return;
    for (final entry in _sessionMessageDebounceTimers.entries) {
      entry.value.cancel();
      if (_sessionMessagePendingTrailing.remove(entry.key) &&
          !_sessionMessageChangeController.isClosed) {
        _sessionMessageChangeController.add(entry.key);
      }
    }
    _sessionMessageDebounceTimers.clear();
  }

  void _scheduleSaveSessionsCache() {
    _saveSessionsCacheDebounceTimer?.cancel();
    _saveSessionsCacheDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      _persistSessionsCache,
    );
  }

  /// Number of most-recent sessions to deserialize synchronously during
  /// [_restoreSessionsCache]. The remaining sessions are decoded after
  /// the first frame via [_restoreRemainingSessionsAsync] so we don't
  /// JSON-decode all 200 cached sessions on the UI isolate during cold
  /// start (a documented contributor to startup time).
  static const int _coldStartSyncSessionRestoreLimit = 5;

  Future<void> _restoreSessionsCache() async {
    final runtimeGeneration = _runtimeGeneration;
    // SessionsCacheStorage abstracts IndexedDB on web / MMKV on native.
    final cache = await SessionsCacheStorage.instance.getSessionsCacheAsync();
    if (cache == null || runtimeGeneration != _runtimeGeneration) return;
    await _restoreSessionsCacheFrom(cache);
  }

  Future<void> _restoreSessionsCacheFrom(Map<String, dynamic> cache) async {
    final runtimeGeneration = _runtimeGeneration;
    try {
      final sessionsRaw = cache['sessions'];
      final encryptedKeysRaw = cache['encryptedDataKeys'];

      if (sessionsRaw is List) {
        final split = splitCachedSessionsForColdStart(
          sessionsRaw,
          syncLimit: _coldStartSyncSessionRestoreLimit,
        );

        final restoredSessions = <Session>[];
        for (final raw in split.recent) {
          try {
            restoredSessions.add(Session.fromJson(raw));
          } catch (error, stack) {
            logger.warning(
              'Skipping malformed cached session during restore',
              error,
              stack,
            );
          }
        }
        _sessions = {
          for (final session in restoredSessions) session.id: session,
        };

        if (split.remaining.isNotEmpty) {
          // Fire-and-forget the deferred decode of the long tail so
          // it does not block initialization.
          unawaited(_restoreRemainingSessionsAsync(split.remaining));
        }
      }

      if (encryptedKeysRaw is Map) {
        final sessionKeys = <String, Uint8List?>{};
        _sessionEncryptedDataKeys.clear();
        // Collect all entries first, then decrypt in parallel instead of
        // sequentially awaiting each one.
        // Only initialize encryption for the sessions we restored
        // synchronously — the rest are initialized on-demand when
        // the user opens the session.
        final entries = encryptedKeysRaw.entries
            .where(
              (e) =>
                  e.key is String &&
                  e.value is String &&
                  (e.value as String).isNotEmpty,
            )
            .map((e) => (e.key as String, e.value as String))
            .where((e) => _sessions.containsKey(e.$1))
            .toList();
        for (final (id, key) in entries) {
          _sessionEncryptedDataKeys[id] = key;
        }
        if (entries.isNotEmpty) {
          // Per-entry guard: one undecryptable key (rotated key, corrupt
          // cache row) must not reject the whole Future.wait and fall into
          // the catch-all below, which clears every restored session AND
          // wipes the on-disk cache. The session is simply left without a
          // data key and is re-fetched from the server on the next sync.
          final decrypted = await Future.wait(
            entries.map((e) async {
              try {
                return await encryption.decryptEncryptionKey(e.$2);
              } catch (error, stack) {
                logger.warning(
                  'Skipping cached session ${e.$1}: data key could not be '
                  'decrypted during restore',
                  error,
                  stack,
                );
                return null;
              }
            }),
          );
          for (var i = 0; i < decrypted.length; i++) {
            final dk = decrypted[i];
            final sessionId = entries[i].$1;
            sessionKeys[sessionId] = dk;
          }
        }
        if (sessionKeys.isNotEmpty) {
          // Parallelize the per-session encryptor open — without this
          // `openEncryption` is awaited sequentially, and on a device
          // with N cached sessions this is N FFI round-trips on the
          // sync.restore critical path.  Future.wait fans them out
          // so the wait time is the slowest single call instead of
          // the sum.
          //
          // Errors are caught per-session so a single bad row cannot fail
          // the whole fan-out and abort the cold-start restore. Only the
          // `openEncryption` call inside the helper is guarded, so the guard
          // is repeated here for the surrounding lookup/eviction steps —
          // otherwise one throw rejects the Future.wait and the catch-all
          // below drops every restored session and the on-disk cache.
          await Future.wait(
            sessionKeys.entries.map((e) async {
              try {
                await _ensureSessionEncryptionInitialized(
                  e.key,
                  e.value,
                  runtimeGeneration: runtimeGeneration,
                );
              } catch (error, stack) {
                logger.warning(
                  'Skipping cached session ${e.key}: encryption could not be '
                  'initialized during restore',
                  error,
                  stack,
                );
              }
            }),
          );
        }
      }

      // Restore the session delta cursor so that subsequent connections
      // (after this cold-start full fetch completes) use incremental sync
      // instead of re-fetching everything.
      _lastSessionsFetchedAt = WireParsers.parseInt(cache['lastFetchedAt']);

      // If any cached session has messages on the server (lastSeq > 0)
      // but no lastMessageAt locally, the cache predates the field and
      // the inbox would render stale times for those sessions until the
      // server-side updated_at advances again (which is throttled per
      // session). Force one full fetch so the inbox picks up
      // lastMessage.createdAt for every session immediately.
      final cacheMissingLastMessageAt = _sessions.values.any(
        (s) => s.lastMessageAt == null && (s.lastSeq ?? 0) > 0,
      );
      if (cacheMissingLastMessageAt) {
        logger.info(
          'Cached sessions are missing lastMessageAt — forcing full fetch '
          'on first sync to refresh inbox timestamps',
        );
        _forceFullFetchNext = true;
      }

      if (_sessions.isNotEmpty) {
        logger.info(
          'Restored ${_sessions.length} cached sessions '
          '(lastSessionsFetchedAt=$_lastSessionsFetchedAt, '
          'forceFullFetchNext=$_forceFullFetchNext)',
        );
      }
    } catch (error, stack) {
      logger.warning('Failed to restore sessions cache', error, stack);
      recordSyncFailure(
        domain: SyncDomain.sessions.name,
        reason: classifySyncFailureReason(error),
      );
      _sessions.clear();
      _sessionDataKeys.clear();
      _sessionEncryptedDataKeys.clear();
      _lastSessionsFetchedAt = null;
      SessionsCacheStorage.instance.clearSessionsCache();
    }
  }

  /// Open the [SessionEncryption] for a single session and cache it
  /// on [Encryption].  Used by [_restoreSessionsCache] and
  /// [SyncData.fetchSessions] to fan out per-session encryptor setup
  /// in parallel instead of awaiting each `openEncryption` FFI call
  /// sequentially.
  ///
  /// Errors are caught per-session: a corrupt cache row, an FFI
  /// hiccup, or a key-mismatch on one session must not abort the
  /// whole fan-out (which would surface as an unhandled async error
  /// and crash the app on cold start). The session is simply
  /// skipped — the user can re-fetch it from the server on the
  /// next sync, and a Sentry breadcrumb is captured with the
  /// session id + error for post-mortem correlation.
  Future<void> _openAndCacheSessionEncryption(
    String sessionId,
    Uint8List? dataKey, {
    int? runtimeGeneration,
  }) async {
    try {
      final encryptorDecryptor = await encryption.openEncryption(dataKey);
      if (runtimeGeneration != null &&
          runtimeGeneration != _runtimeGeneration) {
        return;
      }
      if (encryptorDecryptor is Encryptor) {
        final enc = encryptorDecryptor;
        final dec = encryptorDecryptor;
        encryption.setSessionEncryption(
          sessionId,
          SessionEncryption(
            sessionId: sessionId,
            encryptor: enc,
            decryptor: dec,
            cache: encryption.cache,
          ),
        );
        if (dataKey != null) {
          _sessionDataKeys[sessionId] = dataKey;
        } else {
          _sessionDataKeys.remove(sessionId);
        }
      }
    } catch (e, stack) {
      _sessionDataKeys.remove(sessionId);
      logger.warning(
        'Failed to open encryption for session=$sessionId, '
        'skipping (other sessions continue)',
        e,
        stack,
      );
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'session encryption open failed',
            category: 'sync.encryption',
            level: SentryLevel.warning,
            data: {'sessionId': sessionId, 'error': e.toString()},
          ),
        ),
      );
    }
  }

  bool _sessionDataKeysEqual(Uint8List? a, Uint8List? b) {
    if (a == null || b == null) {
      return a == null && b == null;
    }
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Ensure a session encryption is initialized with the freshest DEK for
  /// the session. If the cached key changed, replace the existing encryptor.
  Future<void> _ensureSessionEncryptionInitialized(
    String sessionId,
    Uint8List? dataKey, {
    int? runtimeGeneration,
  }) async {
    if (runtimeGeneration != null && runtimeGeneration != _runtimeGeneration) {
      return;
    }
    final existingEncryption = encryption.getSessionEncryption(sessionId);
    final cachedKey = _sessionDataKeys[sessionId];
    if (existingEncryption != null && cachedKey == null && dataKey == null) {
      return;
    }
    if (existingEncryption != null &&
        _sessionDataKeysEqual(cachedKey, dataKey)) {
      return;
    }
    if (existingEncryption != null) {
      encryption.removeSessionEncryption(sessionId);
      _sessionDataKeys.remove(sessionId);
    }
    await _openAndCacheSessionEncryption(
      sessionId,
      dataKey,
      runtimeGeneration: runtimeGeneration,
    );
  }

  /// Maximum sessions to store in the on-disk sessions cache.
  /// Cold-start performance is fine with 200 sessions; capping keeps the
  /// cache small enough to avoid localStorage quota exhaustion on web
  /// (~5–10 MB limit shared across all keys).
  static const int _maxCachedSessions = 200;

  void _persistSessionsCache({bool durable = false}) {
    _saveSessionsCacheDebounceTimer?.cancel();
    _saveSessionsCacheDebounceTimer = null;

    // Incrementally update only sessions whose object changed.
    for (final entry in _sessions.entries) {
      final cached = _sessionJsonCache[entry.key];
      if (cached == null || !identical(cached.$1, entry.value)) {
        _sessionJsonCache[entry.key] = (entry.value, entry.value.toJson());
      }
    }
    // Remove stale entries for deleted sessions.
    _sessionJsonCache.removeWhere((id, _) => !_sessions.containsKey(id));

    // LRU cap — drop oldest sessions beyond the limit to keep cache size
    // bounded and avoid localStorage quota exhaustion on web.
    if (_sessionJsonCache.length > _maxCachedSessions) {
      final sorted = _sessionJsonCache.keys.toList()
        ..sort((a, b) {
          final aTime = _sessions[a]?.updatedAt ?? 0;
          final bTime = _sessions[b]?.updatedAt ?? 0;
          return bTime.compareTo(aTime);
        });
      for (final id in sorted.skip(_maxCachedSessions)) {
        _sessionJsonCache.remove(id);
      }
    }

    final snapshot = <String, dynamic>{
      'lastFetchedAt': _lastSessionsFetchedAt,
      'sessions': [for (final e in _sessionJsonCache.values) e.$2],
      'encryptedDataKeys': Map<String, String>.from(_sessionEncryptedDataKeys),
    };
    if (durable) {
      SessionsCacheStorage.instance.saveSessionsCache(snapshot);
    } else {
      unawaited(SessionsCacheStorage.instance.saveSessionsCacheAsync(snapshot));
    }
  }

  /// Sessions warmed per batch when restoring cached messages on cold
  /// start. Only warm the message cache for the sessions that were restored
  /// synchronously. Older sessions load their cache on-demand when opened.
  static const int _coldStartMessageCacheBatchSize = 5;
  static const int _maxColdStartMessageCacheWarmSessions = 5;

  /// Number of sessions decoded per batch in
  /// [_restoreRemainingSessionsAsync]. Yielding to the event loop between
  /// batches keeps the UI isolate responsive during the deferred pass.
  static const int _coldStartSessionRestoreBatchSize = 25;

  /// Decode the remaining cached sessions (the tail beyond
  /// [_coldStartSyncSessionRestoreLimit]) in small batches, yielding to
  /// the event loop between batches so frames can still render. The
  /// most-recent sessions are already in [_sessions] from the synchronous
  /// pass in [_restoreSessionsCache]; this pass fills in the inbox so
  /// scroll-to-bottom and older-session searches work as expected.
  Future<void> _restoreRemainingSessionsAsync(
    List<Map<String, dynamic>> remaining,
  ) async {
    // Let the first frame paint before we start decoding.
    await Future<void>.delayed(Duration.zero);
    if (!isInitialized) return;

    final stopwatch = Stopwatch()..start();
    var processedInBatch = 0;
    var totalAdded = 0;
    for (final raw in remaining) {
      if (!isInitialized) return;
      try {
        final session = Session.fromJson(raw);
        // Preserve any session that was updated by the server while
        // we were yielding (e.g. socket push) — `putIfAbsent` would
        // be wrong if the server-side version is newer, so we keep
        // the existing entry to avoid clobbering live data.
        if (!_sessions.containsKey(session.id)) {
          _sessions[session.id] = session;
          totalAdded++;
        }
      } catch (error, stack) {
        logger.warning(
          'Skipping malformed cached session during deferred restore',
          error,
          stack,
        );
      }
      processedInBatch++;
      if (processedInBatch >= _coldStartSessionRestoreBatchSize) {
        processedInBatch = 0;
        _notifyDataChanged({SyncDomain.sessions});
        // Yield to the event loop so any pending frames can render.
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (totalAdded > 0) {
      _notifyDataChanged({SyncDomain.sessions});
    }
    logger.info(
      'Restored remaining ${remaining.length} cached sessions '
      '(added=$totalAdded, elapsedMs=${stopwatch.elapsedMilliseconds})',
    );
  }

  /// Restores cached messages for the most recent sessions from MMKV into
  /// [_sessionMessages]. Deferred off the synchronous [_init] critical path.
  ///
  /// Sessions are processed in [_coldStartMessageCacheBatchSize]-sized
  /// batches, ordered by [Session.updatedAt] desc, with a microtask yield
  /// between batches. Only [_maxColdStartMessageCacheWarmSessions] sessions
  /// are warmed at startup; older sessions lazy-load their cache when opened.
  Future<void> _restoreRecentCachedMessagesAsync() async {
    await Future<void>.delayed(Duration.zero);
    if (!isInitialized) return;

    final stopwatch = Stopwatch()..start();
    final entries = _sessions.entries.toList()
      ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    if (entries.isEmpty) return;
    final entriesToWarm = entries
        .take(_maxColdStartMessageCacheWarmSessions)
        .toList(growable: false);

    var totalRestored = 0;
    var batchRestored = 0;
    var batchFirstLoadedChanged = false;
    var processedInBatch = 0;

    for (final entry in entriesToWarm) {
      if (!isInitialized) return;
      final sessionId = entry.key;
      if (_sessionMessages.containsKey(sessionId)) {
        processedInBatch++;
        continue;
      }
      try {
        final cached = await MessageCacheService().getMessagesAsync(sessionId);
        if (cached.isNotEmpty) {
          batchRestored++;
          totalRestored++;
          _sessionMessages[sessionId] = cached;
          _sessionsRestoredFromMessageCache.add(sessionId);
          // Audit 2026-08-03: rows restored from the MMKV cache carry
          // localIds minted by an earlier process. Seed them so a later
          // ack does not read as an `unknown_acked_local_id` violation.
          for (final message in cached) {
            final localId = message['localId'];
            if (localId is String && localId.isNotEmpty) {
              messageInvariantMonitor.seedSentLocalId(localId);
            }
          }
          _rebuildSessionContentSignatures(sessionId);
          _sessionMessagesViewCache.remove(sessionId);
          final maxSeq = _maxCachedMessageSeq(cached);
          if (maxSeq != null) {
            _seedSeqCursorFromCache(sessionId, maxSeq);
          }

          // Defer sidechain grouping to onSessionVisible() instead of
          // running O(4N) grouper for every session on cold start.
          // Mark session as needing regroup; onSessionVisible() checks
          // this flag and runs the grouper only when the user opens it.
          if (cached.any((m) => m['isSidechain'] == true)) {
            _sessionsNeedingSidechainRegroup.add(sessionId);
          }

          // Recalculate the older-messages boundary from the lowest
          // seq so the user can scroll up.
          int? minSeq;
          for (final m in cached) {
            final seq = m['seq'] as int?;
            if (seq != null && (minSeq == null || seq < minSeq)) {
              minSeq = seq;
            }
          }
          if (minSeq != null && minSeq > 1) {
            _sessionFirstLoadedSeq[sessionId] = minSeq;
            batchFirstLoadedChanged = true;
          }
        }
      } catch (error, stack) {
        logger.warning(
          'Failed to restore cached messages for session $sessionId '
          'during cold start — skipping',
          error,
          stack,
        );
      }
      processedInBatch++;
      if (processedInBatch >= _coldStartMessageCacheBatchSize) {
        _flushBatchAfterCacheRestore(
          restored: batchRestored,
          firstLoadedChanged: batchFirstLoadedChanged,
        );
        batchRestored = 0;
        batchFirstLoadedChanged = false;
        processedInBatch = 0;
        await Future<void>.delayed(Duration.zero);
      }
    }

    _flushBatchAfterCacheRestore(
      restored: batchRestored,
      firstLoadedChanged: batchFirstLoadedChanged,
    );

    logger.debug(
      '[MessageCache] Warmed $totalRestored/${entriesToWarm.length} recent '
      'session caches in ${stopwatch.elapsedMilliseconds}ms '
      '(skipped ${entries.length - entriesToWarm.length})',
    );
  }

  void _flushBatchAfterCacheRestore({
    required int restored,
    required bool firstLoadedChanged,
  }) {
    if (restored == 0) return;
    _sessionMessagesCache = null;
    if (firstLoadedChanged) {
      _scheduleSaveFirstLoadedSeq();
    }
    _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
  }

  Future<void> _primeSessionFromSpawnResult({
    required String requestedSessionId,
    required String restoredSessionId,
    required Session seedSession,
    required SpawnSessionResponse result,
  }) async {
    if (result.dataEncryptionKey != null &&
        result.dataEncryptionKey!.isNotEmpty) {
      _sessionEncryptedDataKeys[restoredSessionId] = result.dataEncryptionKey!;
      final decryptedKey = await encryption.decryptEncryptionKey(
        result.dataEncryptionKey!,
      );
      if (decryptedKey != null) {
        await _ensureSessionEncryptionInitialized(
          restoredSessionId,
          decryptedKey,
        );
      } else {
        logger.warning(
          '[sendMessage] auto-restore DEK decrypt failed '
          'session=$restoredSessionId',
        );
      }
    }

    _registerSpawn(restoredSessionId);

    if (_sessions.containsKey(restoredSessionId)) {
      _scheduleSaveSessionsCache();
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    _sessions[restoredSessionId] = Session(
      id: restoredSessionId,
      seq: 0,
      createdAt: now,
      updatedAt: now,
      active: true,
      activeAt: now,
      metadata: _metadataWithSpawnResult(
        Metadata(
          host: seedSession.metadata?.host ?? '',
          machineId: seedSession.metadata?.machineId,
          path: result.directory ?? seedSession.metadata?.path,
          flavor: seedSession.metadata?.flavor,
          lifecycleState: 'starting',
          runtimeKind: seedSession.metadata?.runtimeKind,
          podName: seedSession.metadata?.podName,
          namespace: seedSession.metadata?.namespace,
          repoUrl: seedSession.metadata?.repoUrl,
        ),
        result,
      ),
      metadataVersion: 0,
      agentStateVersion: 0,
      thinking: false,
      presence: requestedSessionId == restoredSessionId
          ? seedSession.presence
          : 'offline',
      permissionMode: seedSession.permissionMode,
      modelMode: seedSession.modelMode,
    );
    _scheduleSaveSessionsCache();
    _notifyDataChanged({SyncDomain.sessions});
  }
}
