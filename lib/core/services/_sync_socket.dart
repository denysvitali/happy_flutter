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

    this.credentials = credentials;
    this.encryption = encryption;
    _encryptionInitialized = true;
    anonID = encryption.anonId;
    serverID = parseToken(credentials.token);
    await _init();
    // isInitialized is set early inside _init() after cache restore.
  }

  /// Internal initialization
  Future<void> _init() async {
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

    // Restore cached settings so that loadFromSync() serves the user's
    // last-known settings instead of defaults before syncSettings()
    // completes.  Without this, there is a race between checkAuth()
    // (which calls loadFromSync → reads _settingsSnapshot) and
    // _initializeTheme() (which loads from MMKV).  If checkAuth wins,
    // the Riverpod state briefly reverts to Settings() defaults.
    _settingsSnapshot = restoredSettings;

    // Bulk-restore cached messages for all sessions so that
    // getLastMessagePreview() works immediately on cold start.
    // Deferred off the synchronous _init() critical path — sessions can
    // render from the session cache before per-session message caches are
    // warm.  Messages are loaded lazily when the user opens a chat.
    unawaited(_restoreAllCachedMessagesAsync());

    // Initialize sync managers
    sessionsSync = InvalidateSync(
      fetchSessions,
      minInterval: Sync._sessionsSyncMinInterval,
      name: 'fetchSessions',
    );
    settingsSync = InvalidateSync(syncSettings, name: 'syncSettings');
    profileSync = InvalidateSync(fetchProfile, name: 'fetchProfile');
    purchasesSync = InvalidateSync(syncPurchases, name: 'syncPurchases');
    machinesSync = InvalidateSync(
      fetchMachines,
      minInterval: Sync._machinesSyncMinInterval,
      name: 'fetchMachines',
    );
    pushTokenSync = InvalidateSync(syncPushToken, name: 'syncPushToken');
    nativeUpdateSync = InvalidateSync(
      fetchNativeUpdate,
      name: 'fetchNativeUpdate',
    );
    artifactsSync = InvalidateSync(
      fetchArtifactsList,
      name: 'fetchArtifactsList',
    );
    friendsSync = InvalidateSync(fetchFriends, name: 'fetchFriends');
    friendRequestsSync = InvalidateSync(
      fetchFriendRequests,
      name: 'fetchFriendRequests',
    );
    feedSync = InvalidateSync(fetchFeed, name: 'fetchFeed');
    todosSync = InvalidateSync(fetchTodos, name: 'fetchTodos');
    sessionGitStatusSync = InvalidateSync(
      _fetchSessionGitStatus,
      name: 'fetchSessionGitStatus',
    );

    // Mark initialized early so that provider loadFromSync() can serve
    // cached sessions and messages immediately, before network syncs
    // complete.  Screens subscribing to onDataChanged will pick up the
    // cached snapshot within the debounce window (~100ms).
    isInitialized = true;
    _notifyDataChanged(SyncDomain.values.toSet());

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
    unawaited(
      Future.wait([sessionsSync.awaitQueue(), machinesSync.awaitQueue()])
          .then((_) => _isReady = true)
          .catchError((Object error) {
            logger.warning('Failed initial ready sync', error);
            return true; // Error handled — do not propagate
          }),
    );

    // Configure and restore the message outbox after sync is ready so
    // the encryption context is available for re-sends.
    messageOutbox.configure(
      deliver: _deliverOutboxEntry,
      onStatusChanged: (sessionId, localId, status) {
        _updateMessageSendStatus(sessionId, localId, status);
        if (!_sessionMessageChangeController.isClosed) {
          _sessionMessageChangeController.add(sessionId);
        }
      },
    );
    unawaited(messageOutbox.restoreAndFlush());
  }

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

    if (resetSessionDeltaCursor) {
      _lastSessionsFetchedAt = null;
    }

    // Phase 0: Critical syncs - immediate invalidation.
    // Keep launch limited to the data needed for the default sessions tab.
    if (phase == null || phase == Sync._criticalSyncPhase) {
      sessionsSync.invalidate();

      logger.info(
        'Invalidated critical syncs (sessions)',
      );
    }

    // Phase 1: Deferred syncs.
    // These are non-critical for the initial sessions screen and can load
    // shortly after first paint or on-demand when the user opens a tab.
    if (phase == null || phase == Sync._deferredSyncPhase) {
      _deferredSyncsTimer?.cancel();
      _deferredSyncsTimer = Timer(const Duration(seconds: 1), () {
        // Only invalidate if sync is still initialized to avoid
        // errors after logout/dispose
        if (!isInitialized) return;
        logger.debug(
          'Invalidating background deferred syncs '
          '(machines, settings, profile, purchases, push token, '
          'native update, friend requests, git status)',
        );
        machinesSync.invalidate();
        settingsSync.invalidate();
        profileSync.invalidate();
        purchasesSync.invalidate();
        pushTokenSync.invalidate();
        nativeUpdateSync.invalidate();
        friendRequestsSync.invalidate();
        sessionGitStatusSync.invalidate();
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
  void _notifyDataChanged([Set<SyncDomain>? domains]) {
    _dataChangeCounter++;
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
    // If no timer is running, fire immediately (leading edge) and
    // start a cooldown window.
    if (_dataChangeDebounceTimer == null ||
        !_dataChangeDebounceTimer!.isActive) {
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
  void _flushDataChanged([Set<SyncDomain>? domains]) {
    _dataChangeDebounceTimer?.cancel();
    _dataChangeCounter++;
    final effectiveDomains = domains ?? SyncDomain.values.toSet();
    for (final domain in effectiveDomains) {
      _domainChangeDebounceTimers[domain]?.cancel();
      _domainChangeCounters[domain] = (_domainChangeCounters[domain] ?? 0) + 1;
      if (!_domainChangeController.isClosed) {
        _domainChangeController.add(domain);
      }
    }
    if (!_dataChangeController.isClosed) {
      _dataChangeController.add(null);
    }
  }

  /// Debounced session-message change notification.
  /// Coalesces rapid token-level updates into one emission per 200ms window
  /// per session, preventing the chat screen from rebuilding on every token.
  void _notifySessionMessagesChanged(String sessionId) {
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
    // _tailAfterSeqForSession and gapTooLarge use the
    // authoritative cursor, not the stale value from the
    // last fetchSessions response.
    final session = _sessions[sessionId];
    if (session != null && (session.lastSeq ?? 0) < newSeq) {
      _sessions[sessionId] = session.copyWith(lastSeq: newSeq);
    }
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
      MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
    });
  }

  /// Debounced MMKV persist for a single session's message list.
  ///
  /// Batches rapid upserts (e.g. streaming tokens) into one disk write
  /// per session every 500 ms, keeping only the last ~200 messages in
  /// the persisted copy. The in-memory list retains all messages.
  void _scheduleSaveMessages(String sessionId) {
    // Always use the debounce path. The previous immediate-persist for
    // 'sending' messages ran jsonEncode on the full 200-message list
    // synchronously on the main thread for every streaming token.
    // The 500ms debounce is short enough that messages survive brief
    // backgrounding, and _flushPendingMessageSaves() handles app
    // lifecycle transitions.
    _saveMsgsDebounceTimers[sessionId]?.cancel();
    _saveMsgsDebounceTimers[sessionId] = Timer(
      const Duration(milliseconds: 1000),
      () {
        _saveMsgsDebounceTimers.remove(sessionId);
        final msgs = _sessionMessages[sessionId];
        if (msgs != null) {
          // Persist all messages including sidechain entries.  The
          // sidechain grouper runs on restore
          // (_restoreAllCachedMessages) so children are correctly
          // re-parented.  Previously we stripped isSidechain messages
          // here, which permanently lost them on cold-start.
          MessageCacheService().saveMessages(sessionId, msgs);
        }
      },
    );
  }

  /// Immediately flush all pending debounced message saves so the MMKV
  /// cache is not stale when the app is backgrounded or killed.
  void _flushPendingMessageSaves() {
    if (_saveMsgsDebounceTimers.isEmpty) return;
    for (final entry in _saveMsgsDebounceTimers.entries) {
      entry.value.cancel();
      final msgs = _sessionMessages[entry.key];
      if (msgs != null) {
        MessageCacheService().saveMessages(entry.key, msgs);
      }
    }
    _saveMsgsDebounceTimers.clear();
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

  Future<void> _restoreSessionsCache() async {
    // SessionsCacheStorage abstracts IndexedDB on web / MMKV on native.
    final cache = await SessionsCacheStorage.instance.getSessionsCacheAsync();
    if (cache == null) return;

    try {
      final sessionsRaw = cache['sessions'];
      final encryptedKeysRaw = cache['encryptedDataKeys'];

      if (sessionsRaw is List) {
        final restoredSessions = <Session>[];
        for (final item in sessionsRaw) {
          try {
            if (item is Map<String, dynamic>) {
              restoredSessions.add(Session.fromJson(item));
            } else if (item is Map) {
              restoredSessions.add(
                Session.fromJson(Map<String, dynamic>.from(item)),
              );
            }
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
      }

      if (encryptedKeysRaw is Map) {
        final sessionKeys = <String, Uint8List?>{};
        _sessionEncryptedDataKeys.clear();
        // Collect all entries first, then decrypt in parallel instead of
        // sequentially awaiting each one.
        final entries = encryptedKeysRaw.entries
            .where(
              (e) =>
                  e.key is String &&
                  e.value is String &&
                  (e.value as String).isNotEmpty,
            )
            .map((e) => (e.key as String, e.value as String))
            .toList();
        for (final (id, key) in entries) {
          _sessionEncryptedDataKeys[id] = key;
        }
        if (entries.isNotEmpty) {
          final decrypted = await Future.wait(
            entries.map((e) => encryption.decryptEncryptionKey(e.$2)),
          );
          for (var i = 0; i < decrypted.length; i++) {
            final dk = decrypted[i];
            if (dk == null) continue;
            final sessionId = entries[i].$1;
            _sessionDataKeys[sessionId] = dk;
            sessionKeys[sessionId] = dk;
          }
        }
        if (sessionKeys.isNotEmpty) {
          await encryption.initializeSessions(sessionKeys);
        }
      }

      // Restore the session delta cursor so that subsequent connections
      // (after this cold-start full fetch completes) use incremental sync
      // instead of re-fetching everything.
      _lastSessionsFetchedAt =
          WireParsers.parseInt(cache['lastFetchedAt']);
      if (_sessions.isNotEmpty) {
        logger.info(
          'Restored ${_sessions.length} cached sessions '
          '(lastSessionsFetchedAt=$_lastSessionsFetchedAt)',
        );
      }
    } catch (error, stack) {
      logger.warning('Failed to restore sessions cache', error, stack);
      _sessions.clear();
      _sessionDataKeys.clear();
      _sessionEncryptedDataKeys.clear();
      _lastSessionsFetchedAt = null;
      SessionsCacheStorage.instance.clearSessionsCache();
    }
  }

  /// Maximum sessions to store in the on-disk sessions cache.
  /// Cold-start performance is fine with 200 sessions; capping keeps the
  /// cache small enough to avoid localStorage quota exhaustion on web
  /// (~5–10 MB limit shared across all keys).
  static const int _maxCachedSessions = 200;

  void _persistSessionsCache() {
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

    SessionsCacheStorage.instance.saveSessionsCache({
      'lastFetchedAt': _lastSessionsFetchedAt,
      'sessions': [for (final e in _sessionJsonCache.values) e.$2],
      'encryptedDataKeys': Map<String, String>.from(_sessionEncryptedDataKeys),
    });
  }

  /// Restores cached messages for all sessions from MMKV into
  /// [_sessionMessages].  Called once during [_init] so that
  /// [getLastMessagePreview] and [messagesForSession] return data
  /// immediately on cold start, without waiting for any HTTP fetch.
  /// Async wrapper that defers [_restoreAllCachedMessages] off the
  /// synchronous [_init] critical path.  Sessions can render from the
  /// session cache before per-session message caches are warm.  Messages
  /// are loaded lazily when the user opens a chat.
  Future<void> _restoreAllCachedMessagesAsync() async {
    await Future<void>.delayed(Duration.zero);
    if (!isInitialized) return;
    _restoreAllCachedMessages();
  }

  void _restoreAllCachedMessages() {
    var firstLoadedChanged = false;
    for (final sessionId in _sessions.keys) {
      if (_sessionMessages.containsKey(sessionId)) continue;
      final cached = MessageCacheService().getMessages(sessionId);
      if (cached.isNotEmpty) {
        _sessionMessages[sessionId] = cached;
        _rebuildSessionContentSignatures(sessionId);
        _sessionMessagesViewCache.remove(sessionId);

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
          firstLoadedChanged = true;
        }
      }
    }
    _sessionMessagesCache = null;
    if (firstLoadedChanged) {
      MMKVStorage().saveSessionFirstLoadedSeq(
        Map.unmodifiable(_sessionFirstLoadedSeq),
      );
    }
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
        _sessionDataKeys[restoredSessionId] = decryptedKey;
        await encryption.initializeSessions({restoredSessionId: decryptedKey});
      } else {
        logger.warning(
          '[sendMessage] auto-restore DEK decrypt failed '
          'session=$restoredSessionId',
        );
      }
    }

    _sessionSpawnedAt[restoredSessionId] =
        DateTime.now().millisecondsSinceEpoch;

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
      metadata: Metadata(
        host: seedSession.metadata?.host ?? '',
        machineId: seedSession.metadata?.machineId,
        path: result.directory ?? seedSession.metadata?.path,
        flavor: seedSession.metadata?.flavor,
        lifecycleState: 'starting',
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
