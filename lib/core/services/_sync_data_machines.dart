part of 'sync_service.dart';

extension SyncDataMachines on Sync {
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

      _lastEphemeralAt[sessionId] = DateTime.now().millisecondsSinceEpoch;

      final nextThinking = keepThinking ? session.thinking : thinking ?? false;
      final nextThinkingAt = keepThinking
          ? session.thinkingAt
          : (nextThinking
                ? (activeAt ?? DateTime.now().millisecondsSinceEpoch)
                : null);

      _sessions[sessionId] = session.copyWith(
        thinking: nextThinking,
        thinkingAt: nextThinkingAt,
        presence: 'online',
      );
      _notifyDataChanged({SyncDomain.sessions});

      _presenceTimers[sessionId]?.cancel();
      _presenceTimers[sessionId] = Timer(const Duration(seconds: 60), () {
        _presenceTimers.remove(sessionId);
        final current = _sessions[sessionId];
        if (current != null && current.presence == 'online') {
          _sessions[sessionId] = current.copyWith(
            presence: 'offline',
            thinking: false,
          );
          _notifyDataChanged({SyncDomain.sessions});
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
          // Session explicitly went offline -- cancel any timer and
          // immediately mark it inactive.
          _presenceTimers[sessionId]?.cancel();
          _presenceTimers.remove(sessionId);
          _sessions[sessionId] = session.copyWith(
            presence: 'offline',
            thinking: false,
            thinkingAt: null,
          );
          _notifyDataChanged({SyncDomain.sessions});
        }
      }
      return;
    }

    if (type == 'session-alive' || type == 'session_alive') {
      markOnline(keepThinking: true);
      return;
    }

    // Machine-activity ephemeral -- the CLI daemon sends machine-alive
    // every 20s and the server broadcasts this ephemeral. Patch
    // activeAt in memory so createSession()'s offline check doesn't
    // false-positive between daemon heartbeats.
    //
    // The server may omit activeAt from the event (sending only
    // active:true). In that case synthesise activeAt=now so the
    // 120 s threshold in createSession() stays fresh for every
    // incoming heartbeat.
    if (type == 'machine-activity' || type == 'machine_activity') {
      final machineId = sessionId; // parsed as 'id' above
      final machine = _machines[machineId];
      final eventActiveAt = payload['activeAt'] is int
          ? payload['activeAt'] as int
          : payload['activeAt'] is double
          ? (payload['activeAt'] as double).toInt()
          : null;
      final active = payload['active'] as bool?;
      // If the server says the machine is active but omits activeAt,
      // use the current time so the client-side 120 s window stays
      // fresh.
      final now = DateTime.now().millisecondsSinceEpoch;
      final activeAt = eventActiveAt ?? ((active ?? false) ? now : null);
      logger.debug(
        '[machine-activity] machineId=$machineId '
        'active=$active activeAt=$activeAt '
        '(eventActiveAt=$eventActiveAt)',
      );
      if (machine == null) {
        // A daemon can come online while the app is already running.
        // The first signal is usually machine-activity, not update-machine,
        // so refresh the catalog when we see activity for an unknown machine.
        logger.info(
          '[machine-activity] unknown machineId=$machineId '
          '-- scheduling machines refresh',
        );
        _scheduleMachinesRefresh();
        return;
      }
      if (activeAt != null || active != null) {
        _machines[machineId] = machine.copyWith(
          active: active ?? machine.active,
          activeAt: activeAt ?? machine.activeAt,
        );
        _notifyDataChanged({SyncDomain.machines});
      }
      return;
    }

    // Only invalidate if this session is currently open -- ephemeral
    // updates for non-visible sessions are not urgent and can wait
    // until the user navigates to them. Invalidating all sessions
    // caused a thundering herd of fetchMessages calls (one per active
    // typing/tool event x every session the user had previously
    // opened), blocking the main thread.
    if (sessionId == _visibleSessionId && messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId]?.invalidate();
    }
  }

  /// Fetch machines from server
  Future<void> fetchMachines() async {
    logger.info('Fetching machines...');

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/v1/machines');

      if (apiClient.isSuccess(response)) {
        // Machines response may be a list directly or wrapped in an
        // object
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

        // Initialize machine encryptions -- decrypt all keys in
        // parallel for better performance, then assign results back.
        final machineKeys = <String, Uint8List?>{};

        // Collect machines with their encryption keys.
        final machineDecryptTasks =
            <({String machineId, String dataEncryptionKey})>[];
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
                      '-- falling back to legacy encryption.',
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
              logger.info(
                '[Encryption] DEK decryption failed for machine '
                '$machineId (returned null) -- falling back to legacy '
                'encryption. Run `happy auth debug` to diagnose key '
                'mismatch.',
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
        final machineIsolateResults = await _decryptMachinesInIsolate(
          machineIsolateItems,
        );
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
          // activeAt but clamp it to a reasonable window. The server's
          // activeAt can be stale (cached snapshot from minutes ago),
          // and using it directly fails the 120 s threshold in
          // createSession() -- the "Machine is offline" false positive.
          // When active is true but activeAt is older than 60 s, treat
          // it as now.
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
        // machines -- mirrors fetchSessions() which returns early on
        // an empty full-fetch rather than clearing _sessions.
        if (decryptedMachines.isEmpty) {
          logger.warning(
            'fetchMachines: full fetch returned 0 machines -- '
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
        _notifyDataChanged({SyncDomain.machines});
      } else {
        logger.warning('Failed to fetch machines: ${response.statusCode}');
      }
    } catch (error, stack) {
      if (Sync._isTransientConnectionError(error)) {
        logger.warning('Error fetching machines', error, stack);
        Sentry.captureException(error, stackTrace: stack);
      } else {
        logger.error('Error fetching machines', error, stack);
      }
    }
  }
}
