part of 'sync_service.dart';

extension SyncData on Sync {
  /// Lenient int coercion for wire payloads that may arrive as `int`,
  /// `double`, or `null`.
  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return null;
  }

  /// Placeholder sync callback for session git status. Git status is
  /// managed locally and updated via socket events; this exists so the
  /// [InvalidateSync] manager has a no-op fetcher to schedule.
  Future<void> _fetchSessionGitStatus() async {
    logger.info('Session git status sync triggered');
  }

  /// Fetch sessions from server
  Future<void> fetchSessions() async {
    logger.info('Fetching sessions...');

    final fetchStartMs = DateTime.now().millisecondsSinceEpoch;
    final forceFullFetch = _forceFullFetchNext;
    if (forceFullFetch) _forceFullFetchNext = false;
    final changedSince = forceFullFetch ? null : _lastSessionsFetchedAt;

    try {
      final apiClient = ApiClient();
      final allSessions = await SessionsApi(
        client: apiClient,
      ).fetchSessions(limit: 50, changedSince: changedSince);

      if (logger.shouldLog(LogLevel.info)) {
        logger.info(
          'fetchSessions: received ${allSessions.length} sessions '
          '(changedSince=$changedSince)',
        );
      }
      if (allSessions.isNotEmpty) {
        _setSyncProgress(
          SyncProgress(
            label: 'Fetching conversations',
            completed: 0,
            total: allSessions.length,
          ),
        );
      }

      if (allSessions.isEmpty) {
        if (changedSince != null) {
          // Delta fetch with no changes -- update timestamp and return.
          _lastSessionsFetchedAt = fetchStartMs;
          _scheduleSaveSessionsCache();
          logger.info('fetchSessions: no changes since delta fetch');
        } else {
          logger.warning(
            'fetchSessions: full fetch returned 0 sessions -- '
            'possible auth/server issue',
          );
        }
        return;
      }

      final sessionKeys = <String, Uint8List?>{};

      final sessionDecryptTasks =
          <({String sessionId, String dataEncryptionKey})>[];
      for (final session in allSessions) {
        if (session is! Map<String, dynamic>) {
          logger.warning(
            'Skipping session with invalid payload type',
            'Session data: $session',
          );
          continue;
        }

        final sessionId = WireParsers.parseString(session['id']);
        if (sessionId == null || sessionId.isEmpty) {
          logger.warning(
            'Skipping session with missing/empty ID',
            'Session data: $session',
          );
          continue;
        }

        final dataEncryptionKey = WireParsers.parseString(
          session['dataEncryptionKey'],
        );

        if (dataEncryptionKey != null) {
          _sessionEncryptedDataKeys[sessionId] = dataEncryptionKey;
          sessionDecryptTasks.add((
            sessionId: sessionId,
            dataEncryptionKey: dataEncryptionKey,
          ));
        } else {
          _sessionEncryptedDataKeys.remove(sessionId);
          sessionKeys[sessionId] = null;
        }
      }

      if (sessionDecryptTasks.isNotEmpty) {
        final decryptedKeys = await Future.wait(
          sessionDecryptTasks.map(
            (t) => encryption
                .decryptEncryptionKey(t.dataEncryptionKey)
                .catchError((Object e) {
                  if (logger.shouldLog(LogLevel.info)) {
                    logger.info(
                      '[Encryption] DEK decryption threw for session '
                      '${t.sessionId}: $e '
                      '-- falling back to legacy encryption.',
                    );
                  }
                  return null;
                }),
          ),
        );

        for (var i = 0; i < sessionDecryptTasks.length; i++) {
          final sessionId = sessionDecryptTasks[i].sessionId;
          final decryptedKey = decryptedKeys[i];
          if (decryptedKey != null) {
            sessionKeys[sessionId] = decryptedKey;
          } else {
            logger.warning(
              '[Encryption] DEK decryption failed for session '
              '$sessionId (returned null) -- falling back to legacy '
              'encryption. Run `happy auth debug` and test the printed '
              'vector in Flutter to confirm key mismatch.',
            );
            if (_dekFallbackCaptured.add(sessionId)) {
              unawaited(
                Sentry.captureMessage(
                  '[Encryption] DEK decryption failed — legacy fallback',
                  level: SentryLevel.warning,
                  withScope: (scope) {
                    scope.setTag('dek_fallback_session', sessionId);
                  },
                ),
              );
            }
            sessionKeys[sessionId] = null;
          }
        }
      }

      // Parallelize the per-session encryptor open.  Without this
      // `openEncryption` is awaited sequentially in
      // `Encryption.initializeSessions` — for a delta fetch with
      // 50 returned sessions that's 50 sequential FFI round-trips
      // on the sync.fetch critical path.  Fan out via the same
      // helper used by `_restoreSessionsCache` so the wait time
      // is the slowest single call instead of the sum.
      await Future.wait(
        sessionKeys.entries.map(
          (e) => _ensureSessionEncryptionInitialized(e.key, e.value),
        ),
      );

      // Pre-decrypt metadata + agentState for every session concurrently
      // before the assembly loop. The loop used to `await` each
      // decrypt sequentially, serializing 50 isolate calls (one per
      // metadata + one per agentState) on the main isolate's event
      // loop. With Future.wait, AES isolate batches run in parallel
      // and NaCl yields interleave naturally, dropping fetchSessions
      // p95 from ~1s to roughly the slowest single decrypt.
      final preDecryptStartMs = DateTime.now().millisecondsSinceEpoch;
      final preDecrypted = await _preDecryptSessions(allSessions);
      final preDecryptMs =
          DateTime.now().millisecondsSinceEpoch - preDecryptStartMs;
      if (allSessions.length > 1 && logger.shouldLog(LogLevel.info)) {
        logger.info(
          '[fetchSessions] Pre-decrypted ${preDecrypted.length} '
          'sessions in ${preDecryptMs}ms',
        );
      }

      final decryptedSessions = <Session>[];
      for (var i = 0; i < allSessions.length; i++) {
        if (i == 0 || (i + 1) % 10 == 0 || i == allSessions.length - 1) {
          _setSyncProgress(
            SyncProgress(
              label: 'Fetching conversations',
              completed: i + 1,
              total: allSessions.length,
            ),
          );
        }
        final session = allSessions[i];

        if (session is! Map<String, dynamic>) {
          logger.warning(
            'Skipping session with invalid payload type',
            'Session data: $session',
          );
          continue;
        }

        final sessionId = WireParsers.parseString(session['id']);
        if (sessionId == null || sessionId.isEmpty) {
          logger.warning(
            'Skipping session with missing/empty ID',
            'Session data: $session',
          );
          continue;
        }

        // Always add the session, even if encryption isn't available.
        // This prevents the "Session not loaded" bug where sessions
        // are silently skipped when sessionEncryption is null.
        //
        // Use safe casts with defaults to prevent session from being
        // silently skipped when server returns malformed data.
        // Previously, direct casts like `session['seq'] as int` would
        // throw TypeError on null/wrong type and the session would be
        // silently dropped.
        try {
          // Safe casts with defaults for required fields. For delta
          // fetches the server omits unchanged fields, so preserve any
          // existing in-memory timestamps before falling back to 0.
          // Defaulting to DateTime.now() here would stamp every delta
          // payload as "active just now", incorrectly promoting old
          // sessions to the top of the list until they were re-fetched
          // individually (e.g. by opening the chat).
          final existing = _sessions[sessionId];
          final seq = _asSessionInt(session['seq']) ?? existing?.seq ?? 0;
          final createdAt =
              _asSessionInt(session['createdAt']) ?? existing?.createdAt ?? 0;
          final updatedAt =
              _asSessionInt(session['updatedAt']) ?? existing?.updatedAt ?? 0;
          final active =
              _asSessionBool(session['active']) ?? existing?.active ?? false;
          final now = DateTime.now().millisecondsSinceEpoch;
          final activeAt =
              _clampTimestampToNow(_asSessionInt(session['activeAt']), now) ??
              existing?.activeAt ??
              0;
          final metadataVersion =
              _asSessionInt(session['metadataVersion']) ?? 0;
          final agentStateVersion =
              _asSessionInt(session['agentStateVersion']) ?? 0;
          final lastSeq = max(
            _asSessionInt(session['lastSeq']) ?? 0,
            _sessions[sessionId]?.lastSeq ?? 0,
          );

          // Pull `lastMessage.createdAt` out of the wire payload. The
          // server includes it on every session in /v2/sessions; this
          // is the only fallback we have for inbox time/sort/grouping
          // when the local message cache is empty (session not opened
          // yet). Preserve any newer in-memory value so a delta fetch
          // that omits lastMessage doesn't regress to null.
          final wireLastMessage = session['lastMessage'];
          int? lastMessageAt;
          if (wireLastMessage is Map) {
            final created = _asSessionInt(wireLastMessage['createdAt']);
            if (created != null) lastMessageAt = created;
          }
          final existingLm = existing?.lastMessageAt;
          if (existingLm != null &&
              (lastMessageAt == null || existingLm > lastMessageAt)) {
            lastMessageAt = existingLm;
          }

          // Pull pre-decrypted blobs from the parallel pass above.
          // Empty/missing entries (e.g. session had no encryption)
          // map to null fields, matching the original behavior.
          final pre = preDecrypted[sessionId];
          final metadata = pre?.metadata;
          final agentState = pre?.agentState;

          Metadata? parsedMetadata;
          if (metadata != null) {
            try {
              parsedMetadata = Metadata.fromJson(metadata);
            } catch (e) {
              logger.warning(
                'Failed to parse session metadata for $sessionId',
                e,
              );
            }
          }

          AgentState? parsedAgentState;
          if (agentState != null && agentState.isNotEmpty) {
            try {
              parsedAgentState = AgentState.fromJson(agentState);
            } catch (e) {
              logger.warning(
                'Failed to parse session agentState for $sessionId',
                e,
              );
            }
          }

          final processedSession = Session(
            id: sessionId,
            seq: seq,
            createdAt: createdAt,
            updatedAt: updatedAt,
            active: active,
            activeAt: activeAt,
            archived: _asSessionBool(session['archived']) ?? false,
            metadata: parsedMetadata,
            metadataVersion: metadataVersion,
            agentState: parsedAgentState,
            agentStateVersion: agentStateVersion,
            thinking: false,
            thinkingAt: null,
            // REST fetches cannot tell us whether the CLI process is
            // actually running -- the server's `active` flag is
            // persistent (true until archived) and stale. For delta
            // fetches, preserve the existing presence if known.
            // On first-load of a session (e.g. cross-device), fall
            // back to inferring presence from activeAt freshness:
            // if the server reports active=true within the same 60 s
            // window used by _presenceTimers, treat as 'online' so
            // the user doesn't see their live session as inactive
            // until the first WebSocket activity event arrives.
            presence:
                _sessions[sessionId]?.presence ??
                (active &&
                        DateTime.now().millisecondsSinceEpoch - activeAt < 60000
                    ? 'online'
                    : 'offline'),
            lastSeq: lastSeq,
            lastMessageAt: lastMessageAt,
          );

          decryptedSessions.add(processedSession);
        } catch (error) {
          // Log error in ALL builds (not just debug) so we can detect
          // malformed session data in production
          logger.error('Failed to process session $sessionId', error);
        }
      }

      if (changedSince == null) {
        // Full fetch: selectively cancel presence timers. Preserve
        // timers for sessions that remain 'online' so their countdown
        // from the last keep-alive is maintained. Without this, dead
        // sessions (e.g. after a daemon restart) get a fresh 60-second
        // timer that delays offline detection and allows messages to
        // be sent to a session with no running process.
        // Atomic update: build new map then swap to avoid the clear()
        // window where concurrent operations see an empty _sessions.
        final newSessions = Map<String, Session>.fromEntries(
          decryptedSessions.map((s) => MapEntry(s.id, s)),
        );
        // Preserve recently-spawned optimistic sessions that the
        // server hasn't propagated yet (replication lag). Without
        // this, the full fetch wipes the placeholder added by
        // createSession(), causing "Session not loaded" errors when
        // the user tries to send a message immediately after creating
        // a session.
        final now = DateTime.now().millisecondsSinceEpoch;
        final preservedSessions = <String>[];
        for (final entry in _sessionSpawnedAt.entries) {
          final sid = entry.key;
          final spawnedAt = entry.value;
          if (newSessions.containsKey(sid)) continue;
          if (now - spawnedAt >= 60000) continue;
          // Read once into a local to avoid any chance of a racing
          // mutation between the containsKey check and the `!` deref —
          // socket events / delete-session can mutate _sessions while
          // fetchSessions has yielded for awaits on the same iteration.
          final preserved = _sessions[sid];
          if (preserved == null) continue;
          newSessions[sid] = preserved;
          preservedSessions.add(sid);
        }
        if (preservedSessions.isNotEmpty) {
          logger.info(
            '[fetchSessions] Preserved '
            '${preservedSessions.length} '
            'optimistic sessions from full fetch: '
            '$preservedSessions',
          );
        }
        // Cancel timers for sessions that were removed or went
        // offline. Keep timers for sessions that remain 'online' so
        // their original countdown from the last keep-alive is
        // preserved.
        final staleTimerIds = <String>[];
        for (final entry in _presenceTimers.entries) {
          final newSession = newSessions[entry.key];
          if (newSession == null || newSession.presence != 'online') {
            entry.value.cancel();
            staleTimerIds.add(entry.key);
          }
        }
        for (final id in staleTimerIds) {
          _presenceTimers.remove(id);
        }
        _sessions = newSessions;
      } else {
        // Delta fetch: merge updated sessions, cancel their stale
        // timers.
        for (final session in decryptedSessions) {
          _sessions[session.id] = session;
          _presenceTimers.remove(session.id)?.cancel();
        }
      }

      // Clear optimistic archive flags for sessions that the server
      // has confirmed as archived or inactive. This prevents the
      // "archive then reappear" bug.
      for (final session in decryptedSessions) {
        if (session.archived || !session.active) {
          _optimisticallyArchivedSessions.remove(session.id);
        }
      }
      // On full fetch, clear any optimistic archives for sessions not
      // in the response (deleted or truly archived on server).
      if (changedSince == null) {
        _optimisticallyArchivedSessions.removeWhere(
          (sessionId) => !_sessions.containsKey(sessionId),
        );
      }

      // Start 60 s staleness timers for sessions that came back
      // 'online' but don't already have a running timer. Existing
      // timers (from keep-alives) are preserved so their original
      // countdown is maintained -- this prevents dead sessions from
      // getting a fresh 60 s window after every fetch.
      for (final s in decryptedSessions) {
        if (s.presence == 'online' && !_presenceTimers.containsKey(s.id)) {
          _presenceTimers[s.id] = Timer(const Duration(seconds: 60), () {
            _presenceTimers.remove(s.id);
            final current = _sessions[s.id];
            if (current != null && current.presence == 'online') {
              _sessions[s.id] = current.copyWith(
                presence: 'offline',
                thinking: false,
              );
              _notifyDataChanged({SyncDomain.sessions});
            }
          });
        }
      }

      // Re-apply permission data only for sessions that changed,
      // not all sessions -- avoids O(sessions x messages) on every
      // fetch.
      for (final session in decryptedSessions) {
        if (_sessionMessages.containsKey(session.id)) {
          final messagesChanged = _applyPermissionRequests(session.id);
          if (messagesChanged) {
            _notifySessionMessagesChanged(session.id);
          }
        }
      }

      // Fire local notifications for any new permission requests.
      _checkForNewPermissionRequests(decryptedSessions);

      logger.info('Fetched and decrypted ${decryptedSessions.length} sessions');
      _lastSessionsFetchedAt = fetchStartMs;
      _scheduleSaveSessionsCache();
      _notifyDataChanged({SyncDomain.sessions});
    } on DioException {
      rethrow;
    } catch (error, stack) {
      if (error is SessionsApiException ||
          Sync._isTransientConnectionError(error)) {
        logger.warning('Error fetching sessions', error, stack);
      } else {
        logger.error('Error fetching sessions', error, stack);
      }
    }
  }

  /// Fetch a single session by ID from the server, decrypt it, and
  /// add it to the local cache. Returns the session if found, or null
  /// otherwise.
  /// This avoids a full session list re-fetch when only one session
  /// is needed.
  Future<Session?> fetchSingleSession(String sessionId) async {
    final override = testFetchSingleSessionOverride;
    if (override != null) return override(sessionId);
    try {
      final apiClient = ApiClient();
      final raw = await SessionsApi(
        client: apiClient,
      ).fetchSessionById(sessionId);
      if (raw == null) return null;

      final dataEncryptionKey = WireParsers.parseString(
        raw['dataEncryptionKey'],
      );
      Uint8List? sessionKey;
      if (dataEncryptionKey != null) {
        _sessionEncryptedDataKeys[sessionId] = dataEncryptionKey;
        try {
          sessionKey = await encryption.decryptEncryptionKey(dataEncryptionKey);
        } catch (e) {
          logger.info(
            '[Encryption] DEK decryption threw for single session '
            '$sessionId: $e -- falling back to legacy encryption.',
          );
        }
      } else {
        _sessionEncryptedDataKeys.remove(sessionId);
      }
      await _ensureSessionEncryptionInitialized(sessionId, sessionKey);

      final sessionEncryption = encryption.getSessionEncryption(sessionId);

      final metadataVersion = _asSessionInt(raw['metadataVersion']) ?? 0;
      final agentStateVersion = _asSessionInt(raw['agentStateVersion']) ?? 0;

      Map<String, dynamic>? metadata;
      Map<String, dynamic>? agentState;
      if (sessionEncryption != null) {
        try {
          metadata = await sessionEncryption.decryptMetadata(
            metadataVersion,
            WireParsers.parseString(raw['metadata']) ?? '',
          );
        } catch (e) {
          logger.warning('fetchSingleSession: decrypt metadata failed', e);
        }
        try {
          agentState = await sessionEncryption.decryptAgentState(
            agentStateVersion,
            WireParsers.parseString(raw['agentState']),
          );
        } catch (e) {
          logger.warning('fetchSingleSession: decrypt agentState failed', e);
        }
      }

      Metadata? parsedMetadata;
      if (metadata != null) {
        try {
          parsedMetadata = Metadata.fromJson(metadata);
        } catch (e) {
          logger.warning(
            'fetchSingleSession: parse metadata failed '
            'for $sessionId',
            e,
          );
        }
      }

      AgentState? parsedAgentState;
      if (agentState != null && agentState.isNotEmpty) {
        try {
          parsedAgentState = AgentState.fromJson(agentState);
        } catch (e) {
          logger.warning(
            'fetchSingleSession: parse agentState failed '
            'for $sessionId',
            e,
          );
        }
      }

      // Single-session fetch may also be partial — preserve any
      // in-memory timestamps before falling back to 0 to avoid stamping
      // a session as "active just now" when the server omits the field.
      final existing = _sessions[sessionId];
      final session = Session(
        id: sessionId,
        seq: _asSessionInt(raw['seq']) ?? existing?.seq ?? 0,
        createdAt: _asSessionInt(raw['createdAt']) ?? existing?.createdAt ?? 0,
        updatedAt: _asSessionInt(raw['updatedAt']) ?? existing?.updatedAt ?? 0,
        active: _asSessionBool(raw['active']) ?? existing?.active ?? false,
        archived:
            _asSessionBool(raw['archived']) ?? existing?.archived ?? false,
        activeAt:
            _clampTimestampToNow(
              _asSessionInt(raw['activeAt']),
              DateTime.now().millisecondsSinceEpoch,
            ) ??
            existing?.activeAt ??
            0,
        metadata: parsedMetadata,
        metadataVersion: metadataVersion,
        agentState: parsedAgentState,
        agentStateVersion: agentStateVersion,
        thinking: false,
        presence: _sessions[sessionId]?.presence ?? 'offline',
        lastSeq: max(
          _asSessionInt(raw['lastSeq']) ?? 0,
          _sessions[sessionId]?.lastSeq ?? 0,
        ),
        lastMessageAt: () {
          final wireLastMessage = raw['lastMessage'];
          int? lm;
          if (wireLastMessage is Map) {
            lm = _asSessionInt(wireLastMessage['createdAt']);
          }
          final existingLm = existing?.lastMessageAt;
          if (existingLm != null && (lm == null || existingLm > lm)) {
            return existingLm;
          }
          return lm;
        }(),
      );

      _sessions[sessionId] = session;
      _notifyDataChanged({SyncDomain.sessions});
      _scheduleSaveSessionsCache();
      return session;
    } catch (error, stack) {
      if (error is SessionsApiException ||
          Sync._isTransientConnectionError(error)) {
        logger.warning(
          'fetchSingleSession failed for $sessionId',
          error,
          stack,
        );
      } else {
        logger.error('fetchSingleSession failed for $sessionId', error, stack);
      }
      return null;
    }
  }

  /// Decrypt every session's `metadata` + `agentState` concurrently.
  ///
  /// The previous implementation `await`-ed each decrypt sequentially
  /// inside the assembly for-loop, serializing up to 100 isolate-bound
  /// AES-GCM calls (50 sessions × 2 fields) on cold-start delta
  /// fetches. Running them through `Future.wait` lets:
  ///   * the AES backend's `Isolate.run` calls execute truly in
  ///     parallel on a multi-core device, and
  ///   * cache hits (delta fetches where versions are unchanged)
  ///     resolve instantly without queuing behind earlier awaits.
  ///
  /// Returns a sessionId-keyed map; sessions whose payload is invalid
  /// or which lack a registered encryptor are simply absent (the
  /// caller treats that as "no decrypted content available", matching
  /// the original null-handling).
  Future<Map<String, _DecryptedSessionContent>> _preDecryptSessions(
    List<dynamic> allSessions,
  ) async {
    final tasks = <Future<MapEntry<String, _DecryptedSessionContent>?>>[];
    for (final raw in allSessions) {
      if (raw is! Map<String, dynamic>) continue;
      final sessionId = WireParsers.parseString(raw['id']);
      if (sessionId == null || sessionId.isEmpty) continue;
      final sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) continue;
      final metadataVersion = _asSessionInt(raw['metadataVersion']) ?? 0;
      final agentStateVersion = _asSessionInt(raw['agentStateVersion']) ?? 0;
      final metadataCipher = WireParsers.parseString(raw['metadata']) ?? '';
      final agentStateCipher = WireParsers.parseString(raw['agentState']);
      tasks.add(() async {
        Future<Map<String, dynamic>?> metadataFuture;
        Future<Map<String, dynamic>> agentStateFuture;
        try {
          metadataFuture = sessionEncryption.decryptMetadata(
            metadataVersion,
            metadataCipher,
          );
        } catch (e) {
          logger.warning(
            'Failed to start session metadata decrypt for $sessionId',
            e,
          );
          metadataFuture = Future<Map<String, dynamic>?>.value(null);
        }
        try {
          agentStateFuture = sessionEncryption.decryptAgentState(
            agentStateVersion,
            agentStateCipher,
          );
        } catch (e) {
          logger.warning(
            'Failed to start session agentState decrypt for $sessionId',
            e,
          );
          agentStateFuture = Future<Map<String, dynamic>>.value({});
        }
        Map<String, dynamic>? metadata;
        Map<String, dynamic>? agentState;
        try {
          metadata = await metadataFuture;
        } catch (e) {
          logger.warning(
            'Failed to decrypt session metadata for $sessionId',
            e,
          );
        }
        try {
          agentState = await agentStateFuture;
        } catch (e) {
          logger.warning(
            'Failed to decrypt session agentState for $sessionId',
            e,
          );
        }
        return MapEntry(
          sessionId,
          _DecryptedSessionContent(metadata: metadata, agentState: agentState),
        );
      }());
    }
    final results = await Future.wait(tasks);
    final map = <String, _DecryptedSessionContent>{};
    for (final entry in results) {
      if (entry == null) continue;
      map[entry.key] = entry.value;
    }
    return map;
  }
}

/// Decrypted bundle for one session — output of [_preDecryptSessions].
class _DecryptedSessionContent {
  const _DecryptedSessionContent({
    required this.metadata,
    required this.agentState,
  });

  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? agentState;
}
