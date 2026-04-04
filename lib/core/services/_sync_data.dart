part of 'sync_service.dart';

extension SyncData on Sync {
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

      logger.info(
        'fetchSessions: received ${allSessions.length} sessions '
        '(changedSince=$changedSince)',
      );

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

      // Initialize session encryptions -- decrypt all keys in parallel
      // for better performance, then assign results back.
      final sessionKeys = <String, Uint8List?>{};

      // Collect valid sessions with their encryption keys.
      final sessionDecryptTasks = <({
        String sessionId,
        String dataEncryptionKey,
      })>[];
      for (final session in allSessions) {
        if (session is! Map<String, dynamic>) {
          logger.warning(
            'Skipping session with invalid payload type',
            'Session data: $session',
          );
          continue;
        }

        final sessionId =
            WireParsers.parseString(session['id']);
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

      // Decrypt all session keys in parallel.
      if (sessionDecryptTasks.isNotEmpty) {
        final decryptedKeys = await Future.wait(
          sessionDecryptTasks.map(
            (t) => encryption
                .decryptEncryptionKey(t.dataEncryptionKey)
                .catchError((Object e) {
              logger.info(
                '[Encryption] DEK decryption threw for session '
                '${t.sessionId}: $e '
                '-- falling back to legacy encryption.',
              );
              return null;
            }),
          ),
        );

        for (var i = 0; i < sessionDecryptTasks.length; i++) {
          final sessionId = sessionDecryptTasks[i].sessionId;
          final decryptedKey = decryptedKeys[i];
          if (decryptedKey != null) {
            sessionKeys[sessionId] = decryptedKey;
            _sessionDataKeys[sessionId] = decryptedKey;
          } else {
            logger.warning(
              '[Encryption] DEK decryption failed for session '
              '$sessionId (returned null) -- falling back to legacy '
              'encryption. Run `happy auth debug` and test the printed '
              'vector in Flutter to confirm key mismatch.',
            );
            sessionKeys[sessionId] = null;
          }
        }
      }

      await encryption.initializeSessions(sessionKeys);

      // Decrypt sessions -- yield between each so the looper stays
      // responsive even when processing many sessions.
      final decryptedSessions = <Session>[];
      for (final session in allSessions) {
        // Yield to event queue before each session decrypt.
        await Future<void>.delayed(Duration.zero);

        if (session is! Map<String, dynamic>) {
          logger.warning(
            'Skipping session with invalid payload type',
            'Session data: $session',
          );
          continue;
        }

        final sessionId =
            WireParsers.parseString(session['id']);
        if (sessionId == null || sessionId.isEmpty) {
          logger.warning(
            'Skipping session with missing/empty ID',
            'Session data: $session',
          );
          continue;
        }
        final sessionEncryption =
            encryption.getSessionEncryption(sessionId);

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
          // Safe casts with defaults for required fields
          final seq = _asSessionInt(session['seq']) ?? 0;
          final createdAt =
              _asSessionInt(session['createdAt']) ??
              DateTime.now().millisecondsSinceEpoch;
          final updatedAt =
              _asSessionInt(session['updatedAt']) ??
              DateTime.now().millisecondsSinceEpoch;
          final active =
              _asSessionBool(session['active']) ?? false;
          final activeAt =
              _asSessionInt(session['activeAt']) ??
              DateTime.now().millisecondsSinceEpoch;
          final metadataVersion =
              _asSessionInt(session['metadataVersion']) ?? 0;
          final agentStateVersion =
              _asSessionInt(session['agentStateVersion']) ?? 0;
          final lastSeq = max(
            _asSessionInt(session['lastSeq']) ?? 0,
            _sessions[sessionId]?.lastSeq ?? 0,
          );

          Map<String, dynamic>? metadata;
          Map<String, dynamic>? agentState;

          if (sessionEncryption != null) {
            // Decrypt metadata
            try {
              metadata = await sessionEncryption.decryptMetadata(
                metadataVersion,
                WireParsers.parseString(session['metadata']) ?? '',
              );
            } catch (e) {
              logger.warning(
                'Failed to decrypt session metadata',
                e,
              );
            }

            // Decrypt agent state
            try {
              agentState =
                  await sessionEncryption.decryptAgentState(
                agentStateVersion,
                WireParsers.parseString(session['agentState']),
              );
            } catch (e) {
              logger.warning(
                'Failed to decrypt session agentState',
                e,
              );
            }
          }

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

          // Create session object
          final processedSession = Session(
            id: sessionId,
            seq: seq,
            createdAt: createdAt,
            updatedAt: updatedAt,
            active: active,
            activeAt: activeAt,
            metadata: parsedMetadata,
            metadataVersion: metadataVersion,
            agentState: parsedAgentState,
            agentStateVersion: agentStateVersion,
            thinking: false,
            thinkingAt: null,
            // REST fetches cannot tell us whether the CLI process is
            // actually running -- the server's `active` flag is
            // persistent (true until archived) and stale. Default
            // to 'offline'; only real-time WebSocket activity events
            // should promote a session to 'online'. For delta
            // fetches, preserve the existing presence if known.
            presence:
                _sessions[sessionId]?.presence ?? 'offline',
            lastSeq: lastSeq,
          );

          decryptedSessions.add(processedSession);
        } catch (error) {
          // Log error in ALL builds (not just debug) so we can detect
          // malformed session data in production
          logger.error(
            'Failed to process session $sessionId',
            error,
          );
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
          if (!newSessions.containsKey(sid) &&
              _sessions.containsKey(sid) &&
              now - spawnedAt < 60000) {
            newSessions[sid] = _sessions[sid]!;
            preservedSessions.add(sid);
          }
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
          if (newSession == null ||
              newSession.presence != 'online') {
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
        if (s.presence == 'online' &&
            !_presenceTimers.containsKey(s.id)) {
          _presenceTimers[s.id] = Timer(
            const Duration(seconds: 60),
            () {
              _presenceTimers.remove(s.id);
              final current = _sessions[s.id];
              if (current != null &&
                  current.presence == 'online') {
                _sessions[s.id] = current.copyWith(
                  presence: 'offline',
                  thinking: false,
                );
                _notifyDataChanged();
              }
            },
          );
        }
      }

      // Re-apply permission data only for sessions that changed,
      // not all sessions -- avoids O(sessions x messages) on every
      // fetch.
      for (final session in decryptedSessions) {
        if (_sessionMessages.containsKey(session.id)) {
          _applyPermissionRequests(session.id);
          _notifySessionMessagesChanged(session.id);
        }
      }

      // Fire local notifications for any new permission requests.
      _checkForNewPermissionRequests(decryptedSessions);

      logger.info(
        'Fetched and decrypted ${decryptedSessions.length} sessions',
      );
      _lastSessionsFetchedAt = fetchStartMs;
      _scheduleSaveSessionsCache();
      _notifyDataChanged();
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Error fetching sessions', error, stack);
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
      final raw = await SessionsApi(client: apiClient)
          .fetchSessionById(sessionId);
      if (raw == null) return null;

      // Initialize encryption for this session.
      final dataEncryptionKey = WireParsers.parseString(
        raw['dataEncryptionKey'],
      );
      Uint8List? sessionKey;
      if (dataEncryptionKey != null) {
        _sessionEncryptedDataKeys[sessionId] = dataEncryptionKey;
        try {
          sessionKey = await encryption
              .decryptEncryptionKey(dataEncryptionKey);
          if (sessionKey != null) {
            _sessionDataKeys[sessionId] = sessionKey;
          }
        } catch (e) {
          logger.info(
            '[Encryption] DEK decryption threw for single session '
            '$sessionId: $e -- falling back to legacy encryption.',
          );
        }
      } else {
        _sessionEncryptedDataKeys.remove(sessionId);
      }
      await encryption.initializeSessions({sessionId: sessionKey});

      final sessionEncryption =
          encryption.getSessionEncryption(sessionId);

      // Decrypt metadata and agent state.
      final metadataVersion =
          _asSessionInt(raw['metadataVersion']) ?? 0;
      final agentStateVersion =
          _asSessionInt(raw['agentStateVersion']) ?? 0;

      Map<String, dynamic>? metadata;
      Map<String, dynamic>? agentState;
      if (sessionEncryption != null) {
        try {
          metadata = await sessionEncryption.decryptMetadata(
            metadataVersion,
            WireParsers.parseString(raw['metadata']) ?? '',
          );
        } catch (e) {
          logger.warning(
            'fetchSingleSession: decrypt metadata failed',
            e,
          );
        }
        try {
          agentState =
              await sessionEncryption.decryptAgentState(
            agentStateVersion,
            WireParsers.parseString(raw['agentState']),
          );
        } catch (e) {
          logger.warning(
            'fetchSingleSession: decrypt agentState failed',
            e,
          );
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

      final session = Session(
        id: sessionId,
        seq: _asSessionInt(raw['seq']) ?? 0,
        createdAt: _asSessionInt(raw['createdAt']) ??
            DateTime.now().millisecondsSinceEpoch,
        updatedAt: _asSessionInt(raw['updatedAt']) ??
            DateTime.now().millisecondsSinceEpoch,
        active: _asSessionBool(raw['active']) ?? false,
        activeAt: _asSessionInt(raw['activeAt']) ??
            DateTime.now().millisecondsSinceEpoch,
        metadata: parsedMetadata,
        metadataVersion: metadataVersion,
        agentState: parsedAgentState,
        agentStateVersion: agentStateVersion,
        thinking: false,
        presence:
            _sessions[sessionId]?.presence ?? 'offline',
        lastSeq: max(
          _asSessionInt(raw['lastSeq']) ?? 0,
          _sessions[sessionId]?.lastSeq ?? 0,
        ),
      );

      _sessions[sessionId] = session;
      _notifyDataChanged();
      _scheduleSaveSessionsCache();
      return session;
    } catch (error, stack) {
      logger.error(
        'fetchSingleSession failed for $sessionId',
        error,
        stack,
      );
      return null;
    }
  }
}
