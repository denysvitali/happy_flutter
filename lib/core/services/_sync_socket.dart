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

    // Await initial syncs
    await settingsSync.awaitQueue();
    await profileSync.awaitQueue();
    await purchasesSync.awaitQueue();

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
    await _restoreSessionsCache();

    // Restore cached settings so that loadFromSync() serves the user's
    // last-known settings instead of defaults before syncSettings()
    // completes.  Without this, there is a race between checkAuth()
    // (which calls loadFromSync → reads _settingsSnapshot) and
    // _initializeTheme() (which loads from MMKV).  If checkAuth wins,
    // the Riverpod state briefly reverts to Settings() defaults.
    _settingsSnapshot = await MMKVStorage().getSettings();

    // Bulk-restore cached messages for all sessions so that
    // getLastMessagePreview() works immediately on cold start.
    // Deferred off the synchronous _init() critical path — sessions can
    // render from the session cache before per-session message caches are
    // warm.  Messages are loaded lazily when the user opens a chat.
    unawaited(_restoreAllCachedMessagesAsync());

    // Initialize sync managers
    sessionsSync = InvalidateSync(fetchSessions, name: 'fetchSessions');
    settingsSync = InvalidateSync(syncSettings, name: 'syncSettings');
    profileSync = InvalidateSync(fetchProfile, name: 'fetchProfile');
    purchasesSync = InvalidateSync(syncPurchases, name: 'syncPurchases');
    machinesSync = InvalidateSync(fetchMachines, name: 'fetchMachines');
    pushTokenSync = InvalidateSync(syncPushToken, name: 'syncPushToken');
    nativeUpdateSync =
        InvalidateSync(fetchNativeUpdate, name: 'fetchNativeUpdate');
    artifactsSync =
        InvalidateSync(fetchArtifactsList, name: 'fetchArtifactsList');
    friendsSync = InvalidateSync(fetchFriends, name: 'fetchFriends');
    friendRequestsSync =
        InvalidateSync(fetchFriendRequests, name: 'fetchFriendRequests');
    feedSync = InvalidateSync(fetchFeed, name: 'fetchFeed');
    todosSync = InvalidateSync(fetchTodos, name: 'fetchTodos');
    sessionGitStatusSync =
        InvalidateSync(_fetchSessionGitStatus, name: 'fetchSessionGitStatus');

    // Mark initialized early so that provider loadFromSync() can serve
    // cached sessions and messages immediately, before network syncs
    // complete.  Screens subscribing to onDataChanged will pick up the
    // cached snapshot within the debounce window (~100ms).
    isInitialized = true;
    _notifyDataChanged();

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
    try {
      await Future.wait([sessionsSync.awaitQueue(), machinesSync.awaitQueue()]);
      _isReady = true;
    } catch (error) {
      logger.warning('Failed initial ready sync', error);
    }

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

    // Phase 0: Critical syncs (sessions, machines) - immediate invalidation
    // These are essential for core app functionality and navigation
    if (phase == null || phase == Sync._criticalSyncPhase) {
      sessionsSync.invalidate();
      machinesSync.invalidate();

      // Settings, profile, and purchases are also critical for UI
      settingsSync.invalidate();
      profileSync.invalidate();
      purchasesSync.invalidate();

      // Push token and native update are low-priority but fast
      pushTokenSync.invalidate();
      nativeUpdateSync.invalidate();

      logger.info(
        'Invalidated critical syncs '
        '(sessions, machines, settings, profile, purchases)',
      );
    }

    // Phase 1: Deferred syncs - invalidate after 2-3 second staggered delay
    // These are non-critical and can be loaded lazily when accessed
    if (phase == null || phase == Sync._deferredSyncPhase) {
      _deferredSyncsTimer?.cancel();
      _deferredSyncsTimer = Timer(
        const Duration(milliseconds: 2500),
        () {
          // Only invalidate if sync is still initialized to avoid
          // errors after logout/dispose
          if (!isInitialized) return;
          logger.info(
            'Invalidating deferred syncs '
            '(friends, feed, todos, artifacts, git status)',
          );
          friendsSync.invalidate();
          friendRequestsSync.invalidate();
          feedSync.invalidate();
          todosSync.invalidate();
          artifactsSync.invalidate();
          sessionGitStatusSync.invalidate();
        },
      );
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
  void _notifyDataChanged() {
    _dataChangeCounter++;
    // If no timer is running, fire immediately (leading edge) and
    // start a cooldown window.
    if (_dataChangeDebounceTimer == null ||
        !_dataChangeDebounceTimer!.isActive) {
      if (!_dataChangeController.isClosed) {
        _dataChangeController.add(null);
      }
      _dataChangePendingTrailing = false;
      _dataChangeDebounceTimer =
          Timer(const Duration(milliseconds: 250), () {
        // Trailing edge: emit once more if calls arrived during
        // the cooldown window.
        if (_dataChangePendingTrailing &&
            !_dataChangeController.isClosed) {
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
  void _flushDataChanged() {
    _dataChangeDebounceTimer?.cancel();
    _dataChangeCounter++;
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
  void _notifySessionMessagesChangedUiOnly(String sessionId) {
    _sessionMessageDebounceTimers[sessionId]?.cancel();
    _sessionMessageDebounceTimers[sessionId] = Timer(
      const Duration(milliseconds: 200),
      () {
        _sessionMessageDebounceTimers.remove(sessionId);
        if (!_sessionMessageChangeController.isClosed) {
          _sessionMessageChangeController.add(sessionId);
        }
      },
    );
  }

  /// Advance the message seq cursor for [sessionId] and keep
  /// [Session.lastSeq] in sync so that gap detection and tail-load
  /// calculations use a current value (the sessions API may lag behind
  /// the actual cursor because inline socket messages advance it
  /// faster than [fetchSessions] runs).
  void _advanceSeqCursor(String sessionId, int newSeq) {
    if (!_cursorManager.advanceSeqCursor(
      sessionId,
      newSeq,
    )) {
      return;
    }
    _scheduleSaveSeq();

    // Keep session.lastSeq in sync so
    // _tailAfterSeqForSession and gapTooLarge use the
    // authoritative cursor, not the stale value from the
    // last fetchSessions response.
    final session = _sessions[sessionId];
    if (session != null &&
        (session.lastSeq ?? 0) < newSeq) {
      _sessions[sessionId] =
          session.copyWith(lastSeq: newSeq);
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
      const Duration(milliseconds: 500),
      () {
        _saveMsgsDebounceTimers.remove(sessionId);
        final msgs = _sessionMessages[sessionId];
        if (msgs != null) {
          // Strip sidechain messages before persisting — if the deferred
          // regroup timer hasn't fired yet, orphaned isSidechain entries
          // can slip into the list.  Persisting them causes "invisible
          // messages" on cold-start restore because ChatScreen filters
          // them out in _buildMessageList.
          final clean = msgs
              .where((m) => m['isSidechain'] != true)
              .toList();
          MessageCacheService().saveMessages(sessionId, clean);
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
        final clean = msgs
            .where((m) => m['isSidechain'] != true)
            .toList();
        MessageCacheService().saveMessages(entry.key, clean);
      }
    }
    _saveMsgsDebounceTimers.clear();
  }

  void _scheduleSaveSessionsCache() {
    _saveSessionsCacheDebounceTimer?.cancel();
    _saveSessionsCacheDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      _persistSessionsCache,
    );
  }

  Future<void> _restoreSessionsCache() async {
    final cache = MMKVStorage().getSessionsCache();
    if (cache == null) return;

    try {
      final sessionsRaw = cache['sessions'];
      final encryptedKeysRaw = cache['encryptedDataKeys'];

      if (sessionsRaw is List) {
        final restoredSessions = <Session>[];
        for (final item in sessionsRaw) {
          if (item is Map<String, dynamic>) {
            restoredSessions.add(Session.fromJson(item));
          } else if (item is Map) {
            restoredSessions.add(
              Session.fromJson(Map<String, dynamic>.from(item)),
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
            entries.map(
              (e) => encryption.decryptEncryptionKey(e.$2),
            ),
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

      // Intentionally NOT restoring _lastSessionsFetchedAt from cache.
      // On cold start, we need a FULL session fetch (not delta) to get
      // accurate lastSeq values. The server's changedSince filter may only
      // track metadata changes, not new messages, so a delta fetch would
      // miss sessions that only received messages while the app was closed.
      // _lastSessionsFetchedAt = _asInt(lastFetchedAt);
      _lastSessionsFetchedAt = null;
      if (_sessions.isNotEmpty) {
        logger.info(
          'Restored ${_sessions.length} cached sessions '
          '(forcing full fetch on startup)',
        );
      }
    } catch (error, stack) {
      logger.warning('Failed to restore sessions cache', error, stack);
      _sessions.clear();
      _sessionDataKeys.clear();
      _sessionEncryptedDataKeys.clear();
      _lastSessionsFetchedAt = null;
      MMKVStorage().clearSessionsCache();
    }
  }

  void _persistSessionsCache() {
    _saveSessionsCacheDebounceTimer?.cancel();
    _saveSessionsCacheDebounceTimer = null;

    // Incrementally update only sessions whose object changed.
    for (final entry in _sessions.entries) {
      final cached = _sessionJsonCache[entry.key];
      if (cached == null || !identical(cached.$1, entry.value)) {
        _sessionJsonCache[entry.key] =
            (entry.value, entry.value.toJson());
      }
    }
    // Remove stale entries for deleted sessions.
    _sessionJsonCache.removeWhere(
      (id, _) => !_sessions.containsKey(id),
    );

    MMKVStorage().saveSessionsCache({
      'lastFetchedAt': _lastSessionsFetchedAt,
      'sessions': [
        for (final e in _sessionJsonCache.values) e.$2,
      ],
      'encryptedDataKeys':
          Map<String, String>.from(_sessionEncryptedDataKeys),
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
    _restoreAllCachedMessages();
  }

  void _restoreAllCachedMessages() {
    var firstLoadedChanged = false;
    for (final sessionId in _sessions.keys) {
      if (_sessionMessages.containsKey(sessionId)) continue;
      final cached = MessageCacheService().getMessages(sessionId);
      if (cached.isNotEmpty) {
        // Strip orphaned sidechain messages that were persisted
        // before the deferred regroup timer could clean them up.
        final clean = cached.any((m) => m['isSidechain'] == true)
            ? cached.where((m) => m['isSidechain'] != true).toList()
            : cached;
        if (clean.isNotEmpty) {
          _sessionMessages[sessionId] = clean;
          _sessionMessagesViewCache.remove(sessionId);
          // Notify UI so ChatScreen refreshes with cached messages.
          // Use UI-only notification — we just loaded these from MMKV,
          // there is no reason to write them back immediately.
          _notifySessionMessagesChangedUiOnly(sessionId);

          // The MMKV cache only stores the most recent ~100 messages.
          // _sessionFirstLoadedSeq may say 0 or null, telling
          // hasOlderMessages() there is nothing older.  Recalculate
          // from the lowest seq so the user can scroll up.
          int? minSeq;
          for (final m in clean) {
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
    _notifyDataChanged();
  }
}
