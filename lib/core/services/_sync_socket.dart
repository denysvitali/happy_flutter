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

  /// Subscribe to socket updates
  void subscribeToUpdates() {
    socketIoClient
      ..onMessage('update', handleUpdate)
      ..onMessage('ephemeral', handleEphemeralUpdate)
      ..onMessage('error', _handleErrorEvent)
      ..onReconnected(() {
        logger.info('Socket reconnected');
        _invalidateAllSyncs();
        // Only re-fetch messages for the currently visible session.
        // All other sessions will be lazily refreshed when the user
        // navigates to them via onSessionVisible(). Invalidating every
        // messagesSync entry caused a thundering herd of concurrent
        // fetchMessages calls on reconnect, blocking the main thread.
        // IMPORTANT: Chain after sessionsSync invalidation so fetchMessages
        // runs AFTER fetchSessions has updated serverLastSeq. Without this,
        // fetchMessages may see stale serverLastSeq and skip via early exit.
        if (_visibleSessionId != null) {
          unawaited(sessionsSync.invalidateAndAwait().then((_) {
            if (_visibleSessionId != null) {
              messagesSync[_visibleSessionId]?.invalidate();
            }
          }));
        }
      })
      ..onStatusChange((status) {
        _connectionStatus = status;
      });
  }

  /// Handle incoming updates
  Future<void> handleUpdate(dynamic data) async {
    final payload = _normalizeSocketPayload(data, handlerName: 'handleUpdate');
    if (payload == null) {
      return;
    }

    ApiUpdate? update;
    try {
      update = ApiUpdate.fromJson(payload);

      // Skip Sentry breadcrumbs for high-frequency streaming events.
      // new-message arrives at 10-50/sec during AI responses — recording
      // each one floods Sentry's ring buffer and wastes allocations.
      if (update.type != 'new-message') {
        unawaited(Sentry.addBreadcrumb(Breadcrumb(
          message: 'sync update: ${update.type}',
          category: 'sync.update',
          level: SentryLevel.info,
          data: <String, dynamic>{
            'type': update.type,
            if (update.data['sid'] is String)
              'sessionId': update.data['sid'] as String,
            if (update.data['id'] is String)
              'entityId': update.data['id'] as String,
          },
        )));
      }

      switch (update.type) {
        case 'new-message':
          _handleNewMessage(update.data);
          break;
        case 'new-session':
          _handleNewSession(update.data);
          break;
        case 'delete-session':
          _handleDeleteSession(update.data);
          break;
        case 'archive-session':
          _handleArchiveSession(update.data);
          break;
        case 'update-session':
          _handleUpdateSession(update.data);
          break;
        case 'update-account':
          _handleUpdateAccount(update.data);
          break;
        case 'update-machine':
          _handleUpdateMachine(update.data);
          break;
        case 'relationship-updated':
          _handleRelationshipUpdated(update.data);
          break;
        case 'new-artifact':
          _handleNewArtifact(update.data);
          break;
        case 'update-artifact':
          _handleUpdateArtifact(update.data);
          break;
        case 'delete-artifact':
          _handleDeleteArtifact(update.data);
          break;
        case 'new-feed-post':
          _handleNewFeedPost(update.data);
          break;
        case 'kv-batch-update':
          _handleKvBatchUpdate(update.data);
          break;
      }

    } catch (error, stack) {
      logger.error('Failed to handle update', error, stack);
    }
  }

  /// Socket payloads can arrive as a single-element list depending on the
  /// socket.io transport/codec path. Normalize to a map for parsers.
  Map<String, dynamic>? _normalizeSocketPayload(
    dynamic data, {
    required String handlerName,
  }) {
    dynamic payload = data;
    if (payload is List) {
      if (payload.length == 1) {
        payload = payload.first;
      } else {
        logger.warning(
          '$handlerName: unexpected list payload length=${payload.length}',
        );
        return null;
      }
    }

    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in payload.entries) {
        if (entry.key is String) {
          normalized[entry.key as String] = entry.value;
        }
      }
      return normalized;
    }

    logger.warning(
      '$handlerName: unexpected data type: ${payload.runtimeType}',
    );
    return null;
  }

  /// Handle new message update
  void _handleNewMessage(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String? ?? data['id'] as String?;
    // Do NOT invalidate sessionsSync here — message events fire on every
    // streaming token and would cause dozens of sessions re-fetches per
    // response. Sessions are updated by _handleUpdateSession (session-level
    // state changes) and by the reconnect / resume handlers.
    if (sessionId == null) return;

    final isVisible = sessionId == _visibleSessionId;

    // Recreate per-session sync lazily for the visible session if needed.
    if (!messagesSync.containsKey(sessionId) && isVisible) {
      messagesSync[sessionId] = InvalidateSync(
        () => fetchMessages(sessionId),
        minInterval: Sync._messagesSyncMinInterval,
        name: 'fetchMessages:$sessionId',
      );
    }

    // Deduplicate ALL socket events, not just visible ones.  The server
    // often broadcasts the same new-message event 7-8 times.  Without
    // dedup for non-visible sessions, a background session with an
    // active AI response floods the logger and triggers hundreds of
    // wasteful fetchMessages calls that immediately skip.
    //
    // Keys are added to _pendingInlineMessageKeys BEFORE processing and
    // moved to _recentInlineMessageKeys AFTER success.  This allows
    // retry on failure: if processing throws, the key stays pending so
    // the HTTP fallback can re-process the message without it being
    // incorrectly deduped as "already seen".
    final embeddedMessage = data['message'] as Map<String, dynamic>?;
    if (embeddedMessage != null) {
      final msgId = embeddedMessage['id'] as String?;
      final msgSeq = embeddedMessage['seq'];
      final dedupKey = '$sessionId:$msgId:$msgSeq';
      if (!_recentInlineMessageKeys.contains(dedupKey) &&
          !_pendingInlineMessageKeys.add(dedupKey)) {
        return; // already seen (committed or currently processing)
      }
    }

    if (isVisible) {
      if (embeddedMessage != null) {
        // Serialize inline processing per session so sidechain messages
        // (which form a parentUuid chain) are always upserted and grouped
        // in arrival order.  Without this, concurrent decryptions can
        // finish out of order, breaking the chain and leaving messages
        // orphaned outside their parent Task.
        _inlineProcessor.enqueue(
          sessionId,
          () => _processInlineMessage(
            sessionId,
            embeddedMessage,
          ),
        );
      } else {
        // Visible session with no embedded message — HTTP fetch.
        // Dedup rapid-fire duplicates: the server often broadcasts the
        // same event 7-18 times; without this gate each duplicate
        // triggers a wasteful fetchMessages HTTP call and logger flood.
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final lastMs = _lastNoEmbedEventMs[sessionId] ?? 0;
        if (nowMs - lastMs < 50) return;
        _lastNoEmbedEventMs[sessionId] = nowMs;
        messagesSync[sessionId]?.invalidate();
      }
      logger.info('New message received: $sessionId');
    } else {
      // Non-visible session: mark dirty so onSessionVisible() triggers
      // a fetch when the user navigates to it.
      //
      // Note: Do NOT persist raw encrypted messages here. The raw wire format
      // (with {c: 'encrypted_b64'}) would be cached and displayed as-is if we
      // saved it before decryption. _sessionsWithPendingSocketMessages already
      // tracks that this session has pending messages, so onSessionVisible()
      // will force a server fetch instead of restoring stale cache.
      //
      // Update session.lastSeq so the delta-fetch path in fetchMessages
      // can detect the gap (serverLastSeq > cursorSeq).  Do NOT advance
      // _sessionLastSeq — the messages aren't stored in _sessionMessages,
      // so the cursor must stay at its pre-navigation position.  Advancing
      // the cursor would make cursor == server, hiding the gap and forcing
      // a destructive full tail-refresh on every navigation.
      final msgSeq = embeddedMessage?['seq'] as int?;
      if (msgSeq != null) {
        final session = _sessions[sessionId];
        if (session != null && (session.lastSeq ?? 0) < msgSeq) {
          _sessions[sessionId] = session.copyWith(lastSeq: msgSeq);
        }
      }
      final isNew = _sessionsWithPendingUpdates.add(sessionId);
      if (isNew) {
        logger.info(
          '[handleNewMessage] NON-VISIBLE session=$sessionId '
          'msgSeq=$msgSeq embedded=${embeddedMessage != null} '
          '— pendingUpdates added',
        );
      }
      // Track that this session received socket messages while non-visible
      // so onSessionVisible() knows to force a server fetch instead of
      // restoring stale cache.
      _sessionsWithPendingSocketMessages.add(sessionId);
      // Rate-limit unread increments: during rapid agent streaming,
      // most socket events are sidechain/meta messages that won't be
      // visible in the main chat. Increment at most once per interval
      // to keep the badge count proportional to actual new content.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastIncrMs =
          _sessionUnreadLastIncrementMs[sessionId] ?? 0;
      final current = _sessionUnreadCounts[sessionId] ?? 0;
      final int newUnread;
      if (current < Sync._maxUnreadCount &&
          nowMs - lastIncrMs >= Sync._unreadIncrementMinIntervalMs) {
        newUnread = current + 1;
        _sessionUnreadCounts[sessionId] = newUnread;
        _sessionUnreadLastIncrementMs[sessionId] = nowMs;
      } else {
        newUnread = current;
      }

      Sentry.addBreadcrumb(Breadcrumb(
        message: 'Background message received',
        category: 'chat.background',
        level: SentryLevel.info,
        data: <String, dynamic>{
          'sessionId': sessionId,
          'msgSeq': msgSeq,
          'unreadCount': newUnread,
          'hasEmbedded': embeddedMessage != null,
          'isFirstPending': isNew,
        },
      ));
    }
  }

  /// Decrypt and upsert a single message received inline from the socket
  /// event, bypassing the HTTP fetch round-trip.
  ///
  /// Falls back to [InvalidateSync.invalidate] on failure or when the
  /// message produces no displayable content.
  Future<void> _processInlineMessage(
    String sessionId,
    Map<String, dynamic> wireMessage,
  ) async {
    final msgId = wireMessage['id'] as String?;
    final msgSeq = wireMessage['seq'];
    final dedupKey = '$sessionId:$msgId:$msgSeq';

    final sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      // Leave key in _pendingInlineMessageKeys so retry can re-enter inline
      // path once encryption is initialized.
      messagesSync[sessionId]?.invalidate();
      _notifySessionMessagesChanged(sessionId);
      return;
    }

    try {
      final processed = await sessionEncryption.decryptAndProcessMessages([
        wireMessage,
      ], sessionId);

      if (processed.messages.isEmpty && processed.toolResults.isEmpty) {
        // Nothing displayable from inline processing.  Do NOT advance
        // the seq cursor here — doing so causes the fallback HTTP fetch
        // (below) to be skipped by fetchMessages' "already caught up"
        // guard, permanently losing the message.  Keeping the cursor
        // unchanged lets the fetch retrieve the message from the server.
        if (processed.droppedReasons.isNotEmpty) {
          for (final reason in processed.droppedReasons) {
            logger.warning(
              '[inline] dropped: $reason',
            );
          }
        }
        messagesSync[sessionId]?.invalidate();
        _notifySessionMessagesChanged(sessionId);
        return;
      }

      if (processed.messages.isNotEmpty) {
        _upsertSessionMessages(sessionId, processed.messages);
      }
      if (processed.toolResults.isNotEmpty) {
        _applyToolResults(sessionId, processed.toolResults);
      }
      // Apply any pending tool results that arrived before these messages.
      // This handles the case where a tool-call-result arrives via socket
      // before the tool-call message itself.
      final pending = _pendingToolResults.remove(sessionId);
      if (pending != null && pending.isNotEmpty) {
        _applyToolResults(sessionId, pending);
      }
      for (final u in processed.usageUpdates) {
        _updateSessionUsage(
          u['sessionId'] as String,
          u['usage'] as Map<String, dynamic>,
          u['timestamp'] as int,
        );
      }
      _applyPermissionRequests(sessionId);

      // Run the sidechain grouper when the incoming messages contain
      // sidechain content.  We intentionally omit changedIds here to
      // force the full 4-pass grouper instead of the fast-path.  The
      // fast-path only checks whether the *changed* messages are
      // sidechain-relevant, which misses orphaned children from
      // previous batches whose parent chain wasn't established yet.
      // During active agent streaming, messages arrive every ~50ms and
      // the deferred regroup timer (300ms) keeps getting cancelled, so
      // orphans accumulate and never get grouped — this is the root
      // cause of agent conversation screens showing incomplete children
      // (only 1-2 tool calls, no thinking or text blocks).
      //
      // The full grouper is O(4n) where n ≤ 3000 (the message cap),
      // which completes in ~1-2ms — negligible for inline processing.
      final hasSidechain = processed.messages.any(
        (m) =>
            m['isSidechain'] == true ||
            m['kind'] == 'sidechain-root',
      );
      if (hasSidechain) {
        _groupSidechainMessages(sessionId);
      }

      // Advance the seq cursor so future incremental fetches don't
      // re-download this message.
      _advanceSeqCursor(sessionId, processed.maxSeq);

      // Commit the dedup key: remove from _pendingInlineMessageKeys and
      // add to _recentInlineMessageKeys with FIFO eviction.
      _pendingInlineMessageKeys.remove(dedupKey);
      _recentInlineMessageKeys.add(dedupKey);
      _recentInlineMessageKeyOrder.addLast(dedupKey);
      while (_recentInlineMessageKeyOrder.length > Sync._maxRecentInlineKeys) {
        _recentInlineMessageKeys.remove(
          _recentInlineMessageKeyOrder.removeFirst(),
        );
      }

      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged();
      // Remove the completed Future from the queue so new messages can
      // start fresh processing without chaining onto a resolved Future.
      // The queue entry is also removed on error (below) for symmetry.
      _inlineProcessor.clearSession(sessionId);
    } catch (error, stack) {
      logger.warning(
        'Inline message processing failed — HTTP fetch will retry',
        error,
        stack,
      );
      // Leave key in _pendingInlineMessageKeys so retry can re-process.
      // Remove the failed Future from the queue so subsequent messages
      // can re-enter the inline fast path instead of being silently
      // dropped by chaining onto a rejected Future.
      _inlineProcessor.clearSession(sessionId);
      messagesSync[sessionId]?.invalidate();
      _notifySessionMessagesChanged(sessionId);
    }
  }

  /// Handle new session update
  void _handleNewSession(Map<String, dynamic> data) {
    final sessionId = data['id'] as String? ?? data['sid'] as String?;
    logger.info('New session received: $sessionId');
    if (sessionId != null && sessionId.isNotEmpty) {
      _pendingNewSessionIds.add(sessionId);
    }
    _scheduleSessionsRefresh();
  }

  /// Handle session deletion
  void _handleDeleteSession(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String?;
    if (sessionId != null) {
      // Clear _visibleSessionId if this was the visible session to prevent
      // stale references pointing to a deleted session.
      if (sessionId == _visibleSessionId) {
        _visibleSessionId = null;
      }
      messagesSync.remove(sessionId)?.dispose();
      _postSendCatchUpTimers.remove(sessionId)?.cancel();
      _loadingOlderMessages.remove(sessionId);
      _sessionMessages.remove(sessionId);
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
      _todoLists.remove(sessionId);
      _sessions.remove(sessionId);
      _presenceTimers.remove(sessionId)?.cancel();
      _sessionDataKeys.remove(sessionId);
      _sessionEncryptedDataKeys.remove(sessionId);
      _sessionsNeedingTailRefresh.remove(sessionId);
      _sessionsWithPendingUpdates.remove(sessionId);
      _sessionsWithPendingSocketMessages.remove(sessionId);
      _sessionSpawnedAt.remove(sessionId);
      _autoRestoreInFlight.remove(sessionId);
      _pendingToolResults.remove(sessionId);
      if (isInitialized) {
        _sessionLastSeq.remove(sessionId);
        MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
        _sessionFirstLoadedSeq.remove(sessionId);
        MMKVStorage().saveSessionFirstLoadedSeq(
          Map.unmodifiable(_sessionFirstLoadedSeq),
        );
        _saveMsgsDebounceTimers.remove(sessionId)?.cancel();
        MessageCacheService().clearMessages(sessionId);
        encryption.removeSessionEncryption(sessionId);
      }
    }
    _scheduleSaveSessionsCache();
    sessionsSync.invalidate();
    logger.info(
      'Session deletion received'
      '${sessionId != null ? ': $sessionId' : ''}',
    );
  }

  /// Handle server-side error events.
  ///
  /// When the server emits `{code: "session-invalid", sid: "..."}` it means
  /// the session has been deleted server-side while the client still holds a
  /// reference.  We treat this identically to a `delete-session` update so
  /// all local state is cleaned up and the UI stops showing the stale session.
  void _handleErrorEvent(dynamic data) {
    final payload = _normalizeSocketPayload(
      data,
      handlerName: '_handleErrorEvent',
    );
    if (payload == null) return;
    final code = payload['code'] as String?;
    if (code == 'session-invalid') {
      final sid = payload['sid'] as String?;
      if (sid != null) {
        logger.info('Received session-invalid for $sid — removing local state');
        _handleDeleteSession({'sid': sid});
      }
    }
  }

  /// Handle archive-session WebSocket event.
  ///
  /// The server broadcasts this after a successful archive/unarchive API
  /// call.  We apply the archived flag immediately to the in-memory session
  /// so the UI updates without waiting for a full refetch.
  void _handleArchiveSession(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String?;
    final archived = data['archived'] as bool?;
    if (sessionId == null || archived == null) return;

    final session = _sessions[sessionId];
    if (session == null) return;

    _sessions[sessionId] = session.copyWith(archived: archived);
    if (archived) {
      _optimisticallyArchivedSessions.add(sessionId);
    } else {
      _optimisticallyArchivedSessions.remove(sessionId);
    }
    _notifyDataChanged();
    logger.info(
      'Session archive event: $sessionId archived=$archived',
    );
  }

  /// Handle session update
  ///
  /// Applies delta patches directly to the in-memory session for unencrypted
  /// fields (presence, active, activeAt, title, thinking).  Only falls back
  /// to [sessionsSync.invalidate()] for encrypted fields (metadata, agentState)
  /// that require decryption.  This eliminates the ~4 fetchSessions() HTTP
  /// calls/sec that were happening during active streaming even with
  /// debouncing.
  void _handleUpdateSession(Map<String, dynamic> data) {
    final sessionId = data['id'] as String?;
    if (sessionId == null) return;

    // Apply delta patch directly to the in-memory session for unencrypted
    // fields. This updates the UI immediately without waiting for a debounced
    // HTTP fetch.
    // Ephemeral events (handleEphemeralUpdate) already handle presence/typing
    // directly -- the update-session event carries the same data plus metadata.
    final session = _sessions[sessionId];
    if (session != null) {
      final presence = data['presence'] as String?;
      final active = data['active'] as bool?;
      final activeAt = data['activeAt'] is int
          ? data['activeAt'] as int
          : data['activeAt'] is double
              ? (data['activeAt'] as double).toInt()
              : null;
      final title = data['title'] as String?;
      final thinking = data['thinking'] as bool?;
      final thinkingAt = data['thinkingAt'] is int
          ? data['thinkingAt'] as int
          : data['thinkingAt'] is double
              ? (data['thinkingAt'] as double).toInt()
              : null;
      final archived = data['archived'] as bool?;

      // Only update if at least one unencrypted field is present.
      if (presence != null ||
          active != null ||
          activeAt != null ||
          title != null ||
          thinking != null ||
          thinkingAt != null ||
          archived != null) {
        _sessions[sessionId] = session.copyWith(
          presence: presence ?? session.presence,
          active: active ?? session.active,
          activeAt: activeAt ?? session.activeAt,
          thinking: thinking ?? session.thinking,
          thinkingAt: thinkingAt,
          archived: archived ?? session.archived,
        );
        _notifyDataChanged();
      }
    }

    // Schedule a debounced refresh as a safety net for encrypted fields
    // (metadata, agentState) that we can't decrypt inline here.  The refresh
    // is also needed for new sessions that aren't in _sessions yet.
    _scheduleSessionsRefresh();

    // Only log the first occurrence per session within a debounce window.
    // The server broadcasts dozens of identical update-session events per
    // second during streaming (typing/tool state changes).
    if (_pendingUpdateSessionIds.add(sessionId)) {
      logger.info('Session update received: $sessionId');
    }
  }
}
