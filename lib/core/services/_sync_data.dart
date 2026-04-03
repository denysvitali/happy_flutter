part of 'sync_service.dart';

extension SyncData on Sync {
  void handleEphemeralUpdate(dynamic data) {
    final payload = _normalizeSocketPayload(
      data,
      handlerName: 'handleEphemeralUpdate',
    );
    if (payload == null) {
      return;
    }

    final type = payload['type'] as String? ?? payload['t'] as String?;
    // Activity events use 'id'; fall back to 'sid' for other shapes.
    final sessionId = payload['id'] as String? ?? payload['sid'] as String?;
    if (sessionId == null) {
      return;
    }

    void markOnline({
      required bool keepThinking,
      bool? thinking,
      int? activeAt,
    }) {
      final session = _sessions[sessionId];
      if (session == null) return;

      _lastEphemeralAt[sessionId] =
          DateTime.now().millisecondsSinceEpoch;

      final nextThinking = keepThinking ? session.thinking : thinking ?? false;
      final nextThinkingAt = keepThinking
          ? session.thinkingAt
          : (nextThinking
                ? (activeAt ??
                    DateTime.now().millisecondsSinceEpoch)
                : null);

      _sessions[sessionId] = session.copyWith(
        thinking: nextThinking,
        thinkingAt: nextThinkingAt,
        presence: 'online',
      );
      _notifyDataChanged();

      _presenceTimers[sessionId]?.cancel();
      _presenceTimers[sessionId] = Timer(const Duration(seconds: 60), () {
        _presenceTimers.remove(sessionId);
        final current = _sessions[sessionId];
        if (current != null && current.presence == 'online') {
          _sessions[sessionId] = current.copyWith(
            presence: 'offline',
            thinking: false,
          );
          _notifyDataChanged();
        }
      });
    }

    if (type == 'activity') {
      final session = _sessions[sessionId];
      if (session != null) {
        final thinking = payload['thinking'] as bool? ?? false;
        final activeAt = payload['activeAt'] as int?;
        // The server can push active:false to explicitly mark a session
        // offline (matches ApiEphemeralActivityUpdateSchema in the
        // reference implementation).
        final isActive = payload['active'] as bool? ?? true;

        if (isActive) {
          markOnline(
            thinking: thinking,
            activeAt: activeAt,
            keepThinking: false,
          );
        } else {
          // Session explicitly went offline — cancel any timer and
          // immediately mark it inactive.
          _presenceTimers[sessionId]?.cancel();
          _presenceTimers.remove(sessionId);
          _sessions[sessionId] = session.copyWith(
            presence: 'offline',
            thinking: false,
            thinkingAt: null,
          );
          _notifyDataChanged();
        }
      }
      return;
    }

    if (type == 'session-alive' || type == 'session_alive') {
      markOnline(keepThinking: true);
      return;
    }

    // Machine-activity ephemeral — the CLI daemon sends machine-alive every
    // 20s and the server broadcasts this ephemeral.  Patch activeAt in memory
    // so createSession()'s offline check doesn't false-positive between
    // daemon heartbeats.
    //
    // The server may omit activeAt from the event (sending only active:true).
    // In that case synthesise activeAt=now so the 120 s threshold in
    // createSession() stays fresh for every incoming heartbeat.
    if (type == 'machine-activity' || type == 'machine_activity') {
      final machineId = sessionId; // parsed as 'id' above
      final machine = _machines[machineId];
      if (machine != null) {
        final eventActiveAt = payload['activeAt'] is int
            ? payload['activeAt'] as int
            : payload['activeAt'] is double
                ? (payload['activeAt'] as double).toInt()
                : null;
        final active = payload['active'] as bool?;
        // If the server says the machine is active but omits activeAt,
        // use the current time so the client-side 120 s window stays fresh.
        final now = DateTime.now().millisecondsSinceEpoch;
        final activeAt =
            eventActiveAt ?? (active == true ? now : null);
        logger.debug(
          '[machine-activity] machineId=$machineId '
          'active=$active activeAt=$activeAt '
          '(eventActiveAt=$eventActiveAt)',
        );
        if (activeAt != null || active != null) {
          _machines[machineId] = machine.copyWith(
            active: active ?? machine.active,
            activeAt: activeAt ?? machine.activeAt,
          );
          _notifyDataChanged();
        }
      }
      return;
    }

    // Only invalidate if this session is currently open — ephemeral updates
    // for non-visible sessions are not urgent and can wait until the user
    // navigates to them. Invalidating all sessions caused a thundering herd
    // of fetchMessages calls (one per active typing/tool event × every session
    // the user had previously opened), blocking the main thread.
    if (sessionId == _visibleSessionId && messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId]?.invalidate();
    }
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

      logger.info(
        'fetchSessions: received ${allSessions.length} sessions '
        '(changedSince=$changedSince)',
      );

      if (allSessions.isEmpty) {
        if (changedSince != null) {
          // Delta fetch with no changes — update timestamp and return.
          _lastSessionsFetchedAt = fetchStartMs;
          _scheduleSaveSessionsCache();
          logger.info('fetchSessions: no changes since delta fetch');
        } else {
          logger.warning(
            'fetchSessions: full fetch returned 0 sessions — '
            'possible auth/server issue',
          );
        }
        return;
      }

      // Initialize session encryptions — decrypt all keys in parallel
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
                '— falling back to legacy encryption.',
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
              '[Encryption] DEK decryption failed for session $sessionId '
              '(returned null) — falling back to legacy encryption. '
              'Run `happy auth debug` and test the printed vector in '
              'Flutter to confirm key mismatch.',
            );
            sessionKeys[sessionId] = null;
          }
        }
      }

      await encryption.initializeSessions(sessionKeys);

      // Decrypt sessions — yield between each so the looper stays
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

        final sessionId = WireParsers.parseString(session['id']);
        if (sessionId == null || sessionId.isEmpty) {
          logger.warning(
            'Skipping session with missing/empty ID',
            'Session data: $session',
          );
          continue;
        }
        final sessionEncryption = encryption.getSessionEncryption(sessionId);

        // Always add the session, even if encryption isn't available.
        // This prevents the "Session not loaded" bug where sessions are
        // silently skipped when sessionEncryption is null.
        //
        // Use safe casts with defaults to prevent session from being silently
        // skipped when server returns malformed data. Previously, direct casts
        // like `session['seq'] as int` would throw TypeError on null/wrong type
        // and the session would be silently dropped.
        try {
          // Safe casts with defaults for required fields
          final seq = _asSessionInt(session['seq']) ?? 0;
          final createdAt =
              _asSessionInt(session['createdAt']) ??
              DateTime.now().millisecondsSinceEpoch;
          final updatedAt =
              _asSessionInt(session['updatedAt']) ??
              DateTime.now().millisecondsSinceEpoch;
          final active = _asSessionBool(session['active']) ?? false;
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
              logger.warning('Failed to decrypt session metadata', e);
            }

            // Decrypt agent state
            try {
              agentState = await sessionEncryption.decryptAgentState(
                agentStateVersion,
                WireParsers.parseString(session['agentState']),
              );
            } catch (e) {
              logger.warning('Failed to decrypt session agentState', e);
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
            // actually running — the server's `active` flag is
            // persistent (true until archived) and stale.  Default
            // to 'offline'; only real-time WebSocket activity events
            // should promote a session to 'online'.  For delta
            // fetches, preserve the existing presence if known.
            presence: _sessions[sessionId]?.presence ?? 'offline',
            lastSeq: lastSeq,
          );

          decryptedSessions.add(processedSession);
        } catch (error) {
          // Log error in ALL builds (not just debug) so we can detect
          // malformed session data in production
          logger.error('Failed to process session $sessionId', error);
        }
      }

      if (changedSince == null) {
        // Full fetch: selectively cancel presence timers. Preserve timers
        // for sessions that remain 'online' so their countdown from the
        // last keep-alive is maintained.  Without this, dead sessions
        // (e.g. after a daemon restart) get a fresh 60-second timer that
        // delays offline detection and allows messages to be sent to a
        // session with no running process.
        // Atomic update: build new map then swap to avoid the clear()
        // window where concurrent operations see an empty _sessions.
        final newSessions = Map<String, Session>.fromEntries(
          decryptedSessions.map((s) => MapEntry(s.id, s)),
        );
        // Preserve recently-spawned optimistic sessions that the server
        // hasn't propagated yet (replication lag). Without this, the full
        // fetch wipes the placeholder added by createSession(), causing
        // "Session not loaded" errors when the user tries to send a
        // message immediately after creating a session.
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
            '[fetchSessions] Preserved ${preservedSessions.length} '
            'optimistic sessions from full fetch: $preservedSessions',
          );
        }
        // Cancel timers for sessions that were removed or went offline.
        // Keep timers for sessions that remain 'online' so their original
        // countdown from the last keep-alive is preserved.
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
        // Delta fetch: merge updated sessions, cancel their stale timers.
        for (final session in decryptedSessions) {
          _sessions[session.id] = session;
          _presenceTimers.remove(session.id)?.cancel();
        }
      }

      // Clear optimistic archive flags for sessions that the server has
      // confirmed as archived or inactive. This prevents the
      // "archive then reappear" bug.
      for (final session in decryptedSessions) {
        if (session.archived || !session.active) {
          _optimisticallyArchivedSessions.remove(session.id);
        }
      }
      // On full fetch, clear any optimistic archives for sessions not in
      // the response (deleted or truly archived on server).
      if (changedSince == null) {
        _optimisticallyArchivedSessions.removeWhere(
          (sessionId) => !_sessions.containsKey(sessionId),
        );
      }

      // Start 60 s staleness timers for sessions that came back 'online'
      // but don't already have a running timer.  Existing timers (from
      // keep-alives) are preserved so their original countdown is
      // maintained — this prevents dead sessions from getting a fresh
      // 60 s window after every fetch.
      for (final s in decryptedSessions) {
        if (s.presence == 'online' &&
            !_presenceTimers.containsKey(s.id)) {
          _presenceTimers[s.id] = Timer(const Duration(seconds: 60), () {
            _presenceTimers.remove(s.id);
            final current = _sessions[s.id];
            if (current != null && current.presence == 'online') {
              _sessions[s.id] = current.copyWith(
                presence: 'offline',
                thinking: false,
              );
              _notifyDataChanged();
            }
          });
        }
      }

      // Re-apply permission data only for sessions that changed,
      // not all sessions — avoids O(sessions × messages) on every fetch.
      for (final session in decryptedSessions) {
        if (_sessionMessages.containsKey(session.id)) {
          _applyPermissionRequests(session.id);
          _notifySessionMessagesChanged(session.id);
        }
      }

      // Fire local notifications for any new permission requests.
      _checkForNewPermissionRequests(decryptedSessions);

      logger.info('Fetched and decrypted ${decryptedSessions.length} sessions');
      _lastSessionsFetchedAt = fetchStartMs;
      _scheduleSaveSessionsCache();
      _notifyDataChanged();
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Error fetching sessions', error, stack);
    }
  }

  /// Fetch a single session by ID from the server, decrypt it, and add it to
  /// the local cache. Returns the session if found, or null otherwise.
  /// This avoids a full session list re-fetch when only one session is needed.
  Future<Session?> fetchSingleSession(String sessionId) async {
    final override = testFetchSingleSessionOverride;
    if (override != null) return override(sessionId);
    try {
      final apiClient = ApiClient();
      final raw = await SessionsApi(client: apiClient).fetchSessionById(
        sessionId,
      );
      if (raw == null) return null;

      // Initialize encryption for this session.
      final dataEncryptionKey = WireParsers.parseString(
        raw['dataEncryptionKey'],
      );
      Uint8List? sessionKey;
      if (dataEncryptionKey != null) {
        _sessionEncryptedDataKeys[sessionId] = dataEncryptionKey;
        try {
          sessionKey = await encryption.decryptEncryptionKey(dataEncryptionKey);
          if (sessionKey != null) {
            _sessionDataKeys[sessionId] = sessionKey;
          }
        } catch (e) {
          logger.info(
            '[Encryption] DEK decryption threw for single session '
            '$sessionId: $e — falling back to legacy encryption.',
          );
        }
      } else {
        _sessionEncryptedDataKeys.remove(sessionId);
      }
      await encryption.initializeSessions({sessionId: sessionKey});

      final sessionEncryption = encryption.getSessionEncryption(sessionId);

      // Decrypt metadata and agent state.
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
            'fetchSingleSession: parse metadata failed for $sessionId',
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
            'fetchSingleSession: parse agentState failed for $sessionId',
            e,
          );
        }
      }

      final session = Session(
        id: sessionId,
        seq: _asSessionInt(raw['seq']) ?? 0,
        createdAt:
            _asSessionInt(raw['createdAt']) ??
            DateTime.now().millisecondsSinceEpoch,
        updatedAt:
            _asSessionInt(raw['updatedAt']) ??
            DateTime.now().millisecondsSinceEpoch,
        active: _asSessionBool(raw['active']) ?? false,
        activeAt:
            _asSessionInt(raw['activeAt']) ??
            DateTime.now().millisecondsSinceEpoch,
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
      );

      _sessions[sessionId] = session;
      _notifyDataChanged();
      _scheduleSaveSessionsCache();
      return session;
    } catch (error, stack) {
      logger.error('fetchSingleSession failed for $sessionId', error, stack);
      return null;
    }
  }

  /// Fetch machines from server
  Future<void> fetchMachines() async {
    logger.info('Fetching machines...');

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/v1/machines');

      if (apiClient.isSuccess(response)) {
        // Machines response may be a list directly or wrapped in an object
        final rawData = response.data;
        final List data;
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map<String, dynamic> &&
            rawData['machines'] is List) {
          data = rawData['machines'] as List;
        } else {
          logger.warning(
            'Unexpected response format for machines: '
            '${rawData?.runtimeType}',
          );
          return;
        }

        // Initialize machine encryptions — decrypt all keys in parallel
        // for better performance, then assign results back.
        final machineKeys = <String, Uint8List?>{};

        // Collect machines with their encryption keys.
        final machineDecryptTasks = <({
          String machineId,
          String dataEncryptionKey,
        })>[];
        for (final machine in data) {
          final machineId = machine['id'] as String;
          final dataEncryptionKey = machine['dataEncryptionKey'] as String?;

          if (dataEncryptionKey != null) {
            machineDecryptTasks.add((
              machineId: machineId,
              dataEncryptionKey: dataEncryptionKey,
            ));
          } else {
            machineKeys[machineId] = null;
          }
        }

        // Decrypt all machine keys in parallel.
        if (machineDecryptTasks.isNotEmpty) {
          final decryptedKeys = await Future.wait(
            machineDecryptTasks.map(
              (t) => encryption
                  .decryptEncryptionKey(t.dataEncryptionKey)
                  .catchError((Object e) {
                logger.info(
                  '[Encryption] DEK decryption threw for machine '
                  '${t.machineId}: $e '
                  '— falling back to legacy encryption.',
                );
                return null;
              }),
            ),
          );

          for (var i = 0; i < machineDecryptTasks.length; i++) {
            final machineId = machineDecryptTasks[i].machineId;
            final decryptedKey = decryptedKeys[i];
            if (decryptedKey != null) {
              machineKeys[machineId] = decryptedKey;
              _machineDataKeys[machineId] = decryptedKey;
            } else {
              logger.warning(
                '[Encryption] DEK decryption failed for machine $machineId '
                '(returned null) — falling back to legacy encryption. '
                'Run `happy auth debug` to diagnose key mismatch.',
              );
              machineKeys[machineId] = null;
            }
          }
        }

        await encryption.initializeMachines(machineKeys);

        // Build isolate payloads for machine decryption.
        final legacyKey = encryption.legacySecretKey;
        final machineIsolateItems = <_MachineIsolateItem>[];
        for (final machine in data) {
          final machineId = machine['id'] as String;
          if (!machineKeys.containsKey(machineId)) continue;

          final dataKey = machineKeys[machineId];
          final rawMeta = machine['metadata'];
          final encMeta = (rawMeta is String && rawMeta.isNotEmpty)
              ? Base64Utils.decode(rawMeta, Encoding.base64)
              : null;
          final rawDs = machine['daemonState'] as String?;
          final encDs = (rawDs != null && rawDs.isNotEmpty)
              ? Base64Utils.decode(rawDs, Encoding.base64)
              : null;

          machineIsolateItems.add(
            _MachineIsolateItem(
              id: machineId,
              secretKey: dataKey ?? legacyKey,
              isAes: dataKey != null,
              encryptedMetadata: encMeta,
              metadataVersion: _asSessionInt(machine['metadataVersion']) ?? 0,
              encryptedDaemonState: encDs,
              daemonStateVersion:
                  _asSessionInt(machine['daemonStateVersion']) ?? 0,
            ),
          );
        }

        // Decrypt all machine payloads (AES in background isolate).
        final machineIsolateResults =
            await _decryptMachinesInIsolate(machineIsolateItems);
        final machineResultById = {
          for (final r in machineIsolateResults) r.id: r,
        };

        final decryptedMachines = <Machine>[];
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final machine in data) {
          final machineId = machine['id'] as String;
          final result = machineResultById[machineId];
          if (result == null) continue;

          // If the server says the machine is active, use the server's
          // activeAt but clamp it to a reasonable window.  The server's
          // activeAt can be stale (cached snapshot from minutes ago), and
          // using it directly fails the 120 s threshold in createSession()
          // — the "Machine is offline" false positive.  When active is true
          // but activeAt is older than 60 s, treat it as now.
          final isActive = machine['active'] as bool? ?? false;
          final serverActiveAt = _asSessionInt(machine['activeAt']);
          int activeAt;
          if (isActive) {
            final fallback = serverActiveAt ?? now;
            activeAt = now - fallback > 60000 ? now : fallback;
          } else {
            activeAt = serverActiveAt ?? 0;
          }

          decryptedMachines.add(
            Machine(
              id: machineId,
              seq: _asSessionInt(machine['seq']) ?? 0,
              createdAt: _asSessionInt(machine['createdAt']) ?? 0,
              updatedAt: _asSessionInt(machine['updatedAt']) ?? 0,
              active: isActive,
              activeAt: activeAt,
              metadata: result.metadata != null
                  ? MachineMetadata.fromJson(result.metadata!)
                  : null,
              metadataVersion: _asSessionInt(machine['metadataVersion']) ?? 0,
              daemonState: result.daemonState,
              daemonStateVersion:
                  _asSessionInt(machine['daemonStateVersion']) ?? 0,
            ),
          );
        }

        // Guard against a transient empty response wiping out known
        // machines — mirrors fetchSessions() which returns early on an
        // empty full-fetch rather than clearing _sessions.
        if (decryptedMachines.isEmpty) {
          logger.warning(
            'fetchMachines: full fetch returned 0 machines — '
            'possible auth/server issue, skipping update',
          );
          return;
        }

        _machines
          ..clear()
          ..addEntries(
            decryptedMachines.map((machine) => MapEntry(machine.id, machine)),
          );
        logger.info(
          'Fetched and decrypted ${decryptedMachines.length} machines',
        );
        _notifyDataChanged();
      } else {
        logger.warning('Failed to fetch machines: ${response.statusCode}');
      }
    } catch (error, stack) {
      logger.error('Error fetching machines', error, stack);
    }
  }

  /// Fetch artifacts list from server
  Future<void> fetchArtifactsList() async {
    logger.info('Fetching artifacts...');
    try {
      final api = ApiClient();
      final response = await api.get('/v1/artifacts');
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch artifacts: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawArtifacts = (data is Map<String, dynamic>)
          ? data['artifacts']
          : data;
      if (rawArtifacts is! List) {
        _artifacts.clear();
        return;
      }

      // Phase 1: Decrypt artifact data keys on the main thread.
      // CryptoBox.decrypt is fast (single NaCl call per artifact).
      final keyedArtifacts = <({Artifact artifact, Uint8List key})>[];
      final decryptedArtifacts = <DecryptedArtifact>[];
      for (final raw in rawArtifacts) {
        await Future<void>.delayed(Duration.zero); // yield to event queue
        if (raw is! Map<String, dynamic>) continue;
        try {
          final artifact = Artifact.fromJson(raw);
          final decryptedKey = await encryption.decryptEncryptionKey(
            artifact.dataEncryptionKey,
          );
          if (decryptedKey != null) {
            _artifactDataKeys[artifact.id] = decryptedKey;
            keyedArtifacts.add((artifact: artifact, key: decryptedKey));
          } else {
            decryptedArtifacts.add(
              DecryptedArtifact(
                id: artifact.id,
                headerVersion: artifact.headerVersion,
                bodyVersion: artifact.bodyVersion,
                seq: artifact.seq,
                createdAt: artifact.createdAt,
                updatedAt: artifact.updatedAt,
                isDecrypted: false,
              ),
            );
          }
        } catch (error) {
          logger.warning('Failed to parse artifact key', error);
        }
      }

      // Phase 2: Decrypt headers + bodies off the main thread.
      // AES-GCM pure-Dart decryption can be slow for many artifacts.
      if (keyedArtifacts.isNotEmpty) {
        final artifactIsolateItems = keyedArtifacts.map((e) {
          final encHeader = Base64Utils.decode(
            e.artifact.header,
            Encoding.base64,
          );
          final encBody = e.artifact.body != null
              ? Base64Utils.decode(e.artifact.body!, Encoding.base64)
              : null;
          return _ArtifactIsolateItem(
            id: e.artifact.id,
            secretKey: e.key,
            encryptedHeader: encHeader,
            encryptedBody: encBody,
          );
        }).toList();

        final artifactIsolateResults =
            await _decryptArtifactsInIsolate(artifactIsolateItems);
        final artifactResultById = {
          for (final r in artifactIsolateResults) r.id: r,
        };

        for (final e in keyedArtifacts) {
          final artifact = e.artifact;
          final result = artifactResultById[artifact.id];
          final header = result?.header;
          final body = result?.body;
          decryptedArtifacts.add(
            DecryptedArtifact(
              id: artifact.id,
              title: header?['title'] as String?,
              sessions: (header?['sessions'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList(),
              draft: header?['draft'] as bool?,
              body: body?['body'] as String?,
              headerVersion: artifact.headerVersion,
              bodyVersion: artifact.bodyVersion,
              seq: artifact.seq,
              createdAt: artifact.createdAt,
              updatedAt: artifact.updatedAt,
              isDecrypted: header != null,
            ),
          );
        }
      }

      _artifacts
        ..clear()
        ..addAll(decryptedArtifacts);
      logger.info('Fetched artifacts: ${_artifacts.length}');
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error(
        'Failed to fetch artifacts',
        error,
        stack,
      );
    }
  }

  /// Fetch a single artifact with full body decrypted.
  Future<DecryptedArtifact?> fetchArtifactWithBody(String id) async {
    try {
      final api = ApiClient();
      final response = await api.get('/v1/artifacts/$id');
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch artifact: ${response.statusCode}');
        return null;
      }
      final raw = response.data;
      if (raw is! Map<String, dynamic>) return null;
      final artifact = Artifact.fromJson(raw);
      final decryptedKey =
          _artifactDataKeys[artifact.id] ??
          await encryption.decryptEncryptionKey(artifact.dataEncryptionKey);
      if (decryptedKey == null) return null;
      _artifactDataKeys[artifact.id] = decryptedKey;
      final artifactEncryption = ArtifactEncryption(decryptedKey);
      final header = await artifactEncryption.decryptHeader(artifact.header);
      final body = artifact.body != null
          ? await artifactEncryption.decryptBody(artifact.body!)
          : null;
      return DecryptedArtifact(
        id: artifact.id,
        title: header?['title'] as String?,
        body: body?['body'] as String?,
        headerVersion: artifact.headerVersion,
        bodyVersion: artifact.bodyVersion,
        seq: artifact.seq,
        createdAt: artifact.createdAt,
        updatedAt: artifact.updatedAt,
        isDecrypted: header != null,
      );
    } catch (error, stack) {
      logger.error('Failed to fetch artifact', error, stack);
      return null;
    }
  }

  /// Create a new artifact with optional title and body.
  /// Returns the new artifact's ID.
  Future<String> createArtifact(String? title, String? body) async {
    final dek = ArtifactEncryption.generateDataEncryptionKey();
    final artifactEncryption = ArtifactEncryption(dek);
    final encryptedDek = await encryption.encryptEncryptionKey(dek);
    final encryptedDekB64 = Base64Utils.encode(encryptedDek, Encoding.base64);
    final encryptedHeader = await artifactEncryption.encryptHeader({
      'title': title,
    });
    final encryptedBody = await artifactEncryption.encryptBody({
      'body': body ?? '',
    });
    final artifactId = encryption.generateId();
    final request = ArtifactCreateRequest(
      id: artifactId,
      header: encryptedHeader,
      body: encryptedBody,
      dataEncryptionKey: encryptedDekB64,
    );
    final api = ApiClient();
    final response = await api.post(
      '/v1/artifacts',
      data: request.toJson(),
    );
    if (!api.isSuccess(response)) {
      throw StateError('Failed to create artifact: ${response.statusCode}');
    }
    _artifactDataKeys[artifactId] = dek;
    artifactsSync.invalidate();
    return artifactId;
  }

  /// Update an existing artifact's title and/or body.
  Future<void> updateArtifact(String id, String? title, String? body) async {
    final dek = _artifactDataKeys[id];
    if (dek == null) {
      throw StateError('No decryption key found for artifact $id');
    }
    final artifactEncryption = ArtifactEncryption(dek);
    final existing = _artifacts.firstWhere(
      (a) => a.id == id,
      orElse: () => throw StateError('Artifact $id not found in cache'),
    );
    final encryptedHeader = await artifactEncryption.encryptHeader({
      'title': title,
    });
    final encryptedBody = await artifactEncryption.encryptBody({
      'body': body ?? '',
    });
    final request = ArtifactUpdateRequest(
      header: encryptedHeader,
      expectedHeaderVersion: existing.headerVersion,
      body: encryptedBody,
      expectedBodyVersion: existing.bodyVersion,
    );
    final api = ApiClient();
    final response = await api.post(
      '/v1/artifacts/$id',
      data: request.toJson(),
    );
    if (!api.isSuccess(response)) {
      throw StateError('Failed to update artifact: ${response.statusCode}');
    }
    artifactsSync.invalidate();
  }

  /// Delete an artifact by ID.
  Future<void> deleteArtifact(String id) async {
    final api = ApiClient();
    final response = await api.delete('/v1/artifacts/$id');
    if (!api.isSuccess(response)) {
      throw StateError('Failed to delete artifact: ${response.statusCode}');
    }
    _artifactDataKeys.remove(id);
    _artifacts.removeWhere((a) => a.id == id);
    _notifyDataChanged();
  }

  /// Fetch friends list from server
  Future<void> fetchFriends() async {
    logger.info('Fetching friends...');
    try {
      final api = ApiClient();
      final response = await api.get('/v1/friends');
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch friends: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawFriends = (data is Map<String, dynamic>)
          ? data['friends']
          : data;
      if (rawFriends is! List) {
        _friends.clear();
        _friendRequests.clear();
        return;
      }

      final parsedFriends = <UserProfile>[];
      for (final raw in rawFriends) {
        if (raw is Map<String, dynamic>) {
          parsedFriends.add(_mapFriendProfile(raw));
        }
      }

      _friends
        ..clear()
        ..addAll(parsedFriends);
      _friendRequests
        ..clear()
        ..addAll(_deriveFriendRequests(parsedFriends));

      logger.info(
        'Fetched friends: ${_friends.length}, '
        'pending requests: ${_friendRequests.length}',
      );
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error(
        'Failed to fetch friends',
        error,
        stack,
      );
    }
  }

  /// Fetch friend requests from server.
  /// Friends and requests are both returned by fetchFriends() from /v1/friends,
  /// so this is a no-op to avoid a double network request.
  Future<void> fetchFriendRequests() async {}

  /// Fetch feed items from server
  Future<void> fetchFeed() async {
    logger.info('Fetching feed...');
    try {
      final api = ApiClient();
      final response = await api.get(
        '/v1/feed',
        queryParameters: <String, dynamic>{'limit': 50},
      );
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch feed: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawItems = (data is Map<String, dynamic>) ? data['items'] : data;
      if (rawItems is! List) {
        _feedItems.clear();
        return;
      }

      final parsed = <FeedItem>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          parsed.add(_mapFeedItem(raw));
        }
      }

      _feedItems
        ..clear()
        ..addAll(parsed);
      logger.info('Fetched feed items: ${_feedItems.length}');
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Failed to fetch feed', error, stack);
    }
  }

  /// Fetch todos from server
  Future<void> fetchTodos() async {
    logger.info('Fetching todos...');
    try {
      final items = await KvApi().getByPrefix('todo.', limit: 1000);
      final decryptedByKey = <String, Map<String, dynamic>>{};

      final results = await Future.wait(
        items.map((item) async {
          try {
            final decrypted = await encryption.decryptRaw(item.value);
            if (decrypted is Map<String, dynamic>) {
              return MapEntry(item.key, decrypted);
            }
          } catch (error) {
            logger.warning(
              'Failed to decrypt todo item'
              ' ${item.key}: $error',
            );
          }
          return null;
        }),
      );
      for (final entry in results) {
        if (entry != null) {
          decryptedByKey[entry.key] = entry.value;
        }
      }

      final parsedTodoLists = parseTodoListsFromDecryptedKv(decryptedByKey);
      _todoLists
        ..clear()
        ..addAll(parsedTodoLists);

      final totalItems = parsedTodoLists.values
          .expand((list) => list.items)
          .toSet()
          .length;
      logger.info(
        'Fetched todos: ${parsedTodoLists.length} list(s),'
        ' $totalItems item(s)',
      );
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Failed to fetch todos', error, stack);
    }
  }

  /// Fetch session git status from server
  /// Git status is managed locally and updated via socket events
  Future<void> _fetchSessionGitStatus() async {
    // Git status is currently managed locally via the provider
    // This sync can be extended to fetch from server when needed
    logger.info('Session git status sync triggered');
  }

  @visibleForTesting
  Map<String?, TodoList> parseTodoListsFromDecryptedKv(
    Map<String, Map<String, dynamic>> decryptedByKey,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final todosById = <String, TodoItem>{};
    var undoneOrder = <String>[];
    var doneOrder = <String>[];

    for (final entry in decryptedByKey.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == 'todo.index') {
        final rawUndone = value['undoneOrder'];
        if (rawUndone is List) {
          undoneOrder = rawUndone.whereType<String>().toList();
        }

        final rawCompleted = value['completedOrder'];
        if (rawCompleted is List) {
          doneOrder = rawCompleted.whereType<String>().toList();
        } else {
          final rawDone = value['doneOrder'];
          if (rawDone is List) {
            doneOrder = rawDone.whereType<String>().toList();
          }
        }
        continue;
      }

      if (!key.startsWith('todo.')) {
        continue;
      }

      final todoId = key.substring(5);
      if (todoId.isEmpty || todoId == 'index') {
        continue;
      }

      final mapped = _mapDecryptedTodoItem(
        todoId,
        value,
        createdFallbackAt: now,
      );
      todosById[todoId] = mapped;
    }

    undoneOrder = undoneOrder.where(todosById.containsKey).toList();
    doneOrder = doneOrder.where(todosById.containsKey).toList();

    final orderedIds = <String>{...undoneOrder, ...doneOrder};
    for (final entry in todosById.entries) {
      if (!orderedIds.contains(entry.key)) {
        if (entry.value.status == TodoState.completed ||
            entry.value.status == TodoState.canceled) {
          doneOrder.add(entry.key);
        } else {
          undoneOrder.add(entry.key);
        }
      }
    }

    final allOrderedIds = <String>[...undoneOrder, ...doneOrder];
    final grouped = <String?, List<TodoItem>>{null: <TodoItem>[]};
    var order = 0;

    for (final todoId in allOrderedIds) {
      final base = todosById[todoId];
      if (base == null) {
        continue;
      }

      final item = base.copyWith(order: order++);
      grouped[null]!.add(item);

      final sessionId = item.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        grouped.putIfAbsent(sessionId, () => <TodoItem>[]).add(item);
      }
    }

    final result = <String?, TodoList>{};
    for (final entry in grouped.entries) {
      result[entry.key] = TodoList(
        sessionId: entry.key,
        items: entry.value,
        updatedAt: now,
      );
    }
    return result;
  }

  TodoItem _mapDecryptedTodoItem(
    String todoId,
    Map<String, dynamic> raw, {
    required int createdFallbackAt,
  }) {
    final content =
        (raw['content'] as String?) ?? (raw['title'] as String?) ?? '';

    final rawStatus = raw['status'];
    final status = _mapTodoStatus(rawStatus, raw['done']);

    final linkedSessions = raw['linkedSessions'];
    var sessionId = raw['sessionId'] as String?;
    if ((sessionId == null || sessionId.isEmpty) &&
        linkedSessions is Map<String, dynamic> &&
        linkedSessions.isNotEmpty) {
      sessionId = linkedSessions.keys.first;
    }

    final dependenciesRaw = raw['dependencies'];
    final dependencies = dependenciesRaw is List
        ? dependenciesRaw.whereType<String>().toList()
        : <String>[];

    return TodoItem(
      id: (raw['id'] as String?) ?? todoId,
      content: content,
      status: status,
      priority: (raw['priority'] as String?) ?? 'medium',
      order: 0,
      parentId: raw['parentId'] as String?,
      dependencies: dependencies,
      dueAt: _asInt(raw['dueAt']),
      createdAt: _asInt(raw['createdAt']) ?? createdFallbackAt,
      updatedAt: _asInt(raw['updatedAt']) ?? createdFallbackAt,
      sessionId: sessionId,
      completedAt: _asInt(raw['completedAt']),
    );
  }

  TodoState _mapTodoStatus(dynamic rawStatus, dynamic rawDone) {
    if (rawStatus is String) {
      return TodoState.fromString(rawStatus);
    }

    if (rawDone is bool) {
      return rawDone ? TodoState.completed : TodoState.pending;
    }

    return TodoState.pending;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return null;
  }

  @visibleForTesting
  UserProfile mapFriendProfile(Map<String, dynamic> raw) {
    return _mapFriendProfile(raw);
  }

  UserProfile _mapFriendProfile(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ?? (raw['uid'] as String?) ?? 'unknown';
    final firstName = (raw['firstName'] as String?) ?? '';
    final lastName = raw['lastName'] as String?;
    final username = (raw['username'] as String?) ?? '';
    final avatarRaw = raw['avatar'];
    AvatarRef? avatar;
    if (avatarRaw is Map<String, dynamic>) {
      avatar = AvatarRef.fromJson(avatarRaw);
    }

    return UserProfile(
      id: id,
      firstName: firstName,
      lastName: lastName,
      username: username,
      avatar: avatar,
      bio: raw['bio'] as String?,
      status: RelationshipStatus.fromString(raw['status'] as String? ?? 'none'),
    );
  }

  List<FriendRequest> _deriveFriendRequests(List<UserProfile> profiles) {
    return profiles
        .where((profile) => profile.status == RelationshipStatus.pending)
        .map(
          (profile) => FriendRequest(
            id: 'friend-request-${profile.id}',
            fromUserId: profile.id,
            fromUserName: profile.name ?? profile.id,
            fromUserAvatarUrl: profile.avatarUrl,
            toUserId: serverID,
            createdAt: 0,
            status: 'pending',
          ),
        )
        .toList();
  }

  @visibleForTesting
  FeedItem mapFeedItem(Map<String, dynamic> raw) {
    return _mapFeedItem(raw);
  }

  FeedItem _mapFeedItem(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ?? '';
    final createdAt =
        _asInt(raw['createdAt']) ?? DateTime.now().millisecondsSinceEpoch;
    final bodyRaw = raw['body'];
    final bodyMap = bodyRaw is Map<String, dynamic>
        ? bodyRaw
        : <String, dynamic>{};
    final kind = bodyMap['kind'] as String? ?? 'text';
    var userId = raw['userId'] as String? ?? 'system';

    // Derive userId from uid in body for relationship events
    if (kind == 'friend_request' || kind == 'friend_accepted') {
      userId = (bodyMap['uid'] as String?) ?? userId;
    }

    final body = FeedBody(
      kind: kind,
      uid: bodyMap['uid'] as String?,
      text: bodyMap['text'] as String?,
    );

    return FeedItem(
      id: id,
      userId: userId,
      userName: raw['userName'] as String?,
      userAvatarUrl: raw['userAvatarUrl'] as String?,
      body: body,
      createdAt: createdAt,
      read: raw['read'] as bool? ?? false,
      sessionId: raw['sessionId'] as String?,
      repeatKey: raw['repeatKey'] as String?,
      cursor: raw['cursor'] as String?,
      counter: raw['counter'] as int?,
    );
  }
}
