part of 'sync_service.dart';

extension SyncDataMachines on Sync {
  void handleEphemeralUpdate(dynamic data) {
    // The socket is deliberately kept alive for a short grace period after
    // backgrounding. Do not let heartbeats during that window wake the UI or
    // reset presence timers; resume performs the authoritative catch-up.
    if (InvalidateSync.isBackgrounded) return;

    final payload = _normalizeSocketPayload(
      data,
      handlerName: 'handleEphemeralUpdate',
    );
    if (payload == null) {
      return;
    }

    final type = payload['type'] as String? ?? payload['t'] as String?;

    if (type == 'alive-batch') {
      final sessions = payload['sessions'] as List?;
      if (sessions == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      var anyChanged = false;
      for (final s in sessions) {
        if (s is! Map) continue;
        final sid = s['id'] as String?;
        if (sid == null) continue;
        final session = _sessions[sid];
        if (session == null) continue;

        _lastEphemeralAt[sid] = now;
        final activeAt = s['activeAt'] as int?;
        final thinking = s['thinking'] as bool? ?? false;
        final nextThinkingAt = thinking
            ? (activeAt ??
                (session.thinking ? session.thinkingAt : null) ??
                now)
            : null;
        final changed =
            session.presence != 'online' ||
            session.thinking != thinking ||
            session.thinkingAt != nextThinkingAt;
        if (changed) {
          _sessions[sid] = session.copyWith(
            thinking: thinking,
            thinkingAt: nextThinkingAt,
            presence: 'online',
          );
          anyChanged = true;
        }

        _presenceTimers[sid]?.cancel();
        _presenceTimers[sid] = Timer(const Duration(seconds: 60), () {
          _presenceTimers.remove(sid);
          final current = _sessions[sid];
          if (current != null && current.presence == 'online') {
            _sessions[sid] = current.copyWith(
              presence: 'offline',
              thinking: false,
            );
            _notifyDataChanged({SyncDomain.sessions});
          }
        });
      }
      if (anyChanged) {
        _notifyDataChanged({SyncDomain.sessions});
      }
      return;
    }

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

      final changed =
          session.presence != 'online' ||
          session.thinking != nextThinking ||
          session.thinkingAt != nextThinkingAt;
      if (changed) {
        _sessions[sessionId] = session.copyWith(
          thinking: nextThinking,
          thinkingAt: nextThinkingAt,
          presence: 'online',
        );
        _notifyDataChanged({SyncDomain.sessions});
      }

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
      final session = _sessions[sessionId];
      if (session != null) {
        _lastEphemeralAt[sessionId] = DateTime.now().millisecondsSinceEpoch;
        if (session.presence != 'online') {
          _sessions[sessionId] = session.copyWith(presence: 'online');
          _notifyDataChanged({SyncDomain.sessions});
        }
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
      final activeAt =
          _clampTimestampToNow(eventActiveAt, now) ??
          ((active ?? false) ? now : null);
      // ageMs = now - activeAt tells us whether the server's activeAt
      // is fresh (a few hundred ms old) or stale (caches 30 s+ old
      // snapshot from a cold daemon). Synthesised activeAt is
      // reported as 0 so we can spot when the daemon is alive but
      // the server omitted the timestamp.
      final ageMs = (activeAt != null) ? now - activeAt : null;
      final ageLabel = ageMs == null
          ? 'null'
          : ageMs < 1000
          ? '${ageMs}ms'
          : '${(ageMs / 1000).toStringAsFixed(1)}s';
      final source = eventActiveAt != null ? 'event' : 'synth';
      logger.debug(
        '[machine-activity] machineId=$machineId '
        'inMap=${machine != null} active=$active '
        'activeAt=$activeAt age=$ageLabel source=$source',
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
        final updatedMachine = machine.copyWith(
          active: active ?? machine.active,
          activeAt: activeAt ?? machine.activeAt,
        );
        _machines[machineId] = updatedMachine;
        // Re-emit ageMs at info so a "stuck offline" report can
        // confirm the patch landed even when the network log filter
        // hides the debug stream. Single line, low frequency
        // (~1/20s per active machine).
        if (ageMs != null && ageMs > 5 * 1000) {
          logger.info(
            '[machine-activity] patched in-memory '
            'machineId=$machineId age=$ageLabel '
            '(server cached activeAt; UI will recover on next fetch)',
          );
        }
        // Heartbeats normally keep `active` true, so checking only the
        // boolean misses the refreshed activeAt. Without a machines-domain
        // notification, Riverpod keeps the old timestamp and eventually
        // renders the still-running machine as offline.
        if (updatedMachine.active != machine.active ||
            updatedMachine.activeAt != machine.activeAt) {
          _notifyDataChanged({SyncDomain.machines});
        }
      }
      return;
    }

    // Only fetch immediately if this session is currently open. For
    // non-visible sessions, remember that socket-side activity happened so
    // onSessionVisible() performs a catch-up fetch. Ignoring these hints made
    // some sessions appear to advance only while the chat screen was open.
    if (sessionId == _visibleSessionId && messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId]?.invalidate();
    } else if (_sessions.containsKey(sessionId)) {
      _sessionsWithPendingSocketMessages.add(sessionId);
      _sessionsWithPendingUpdates.add(sessionId);
    }
  }

  /// Fetch machines from server
  Future<void> fetchMachines() async {
    logger.info('Fetching machines...');

    try {
      final apiClient = ApiClient();
      // Machine presence is a liveness signal, not durable API data. Serving
      // this request from the client HTTP cache can leave the new-session
      // dialog showing a disconnected daemon as online.
      final response = await apiClient.get(
        '/v1/machines',
        options: Options(extra: const {'bypassCache': true}),
      );

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
          // Aggregated per fetch — see the session DEK path in
          // `_sync_data.dart` for why this is counted at batch level.
          var dekFailures = 0;
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
              dekFailures++;
              logger.info(
                '[Encryption] DEK decryption failed for machine '
                '$machineId (returned null) -- falling back to legacy '
                'encryption. Run `happy auth debug` to diagnose key '
                'mismatch.',
              );
              machineKeys[machineId] = null;
            }
          }
          recordDecryptFailure(
            envelope: kEnvelopeAes,
            stage: kStageDek,
            fromCache: false,
            count: dekFailures,
          );
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
          final serverActiveAt = _clampTimestampToNow(
            _asSessionInt(machine['activeAt']),
            now,
          );
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
        final statusCode = response.statusCode;
        logger.warning('Failed to fetch machines: $statusCode');
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: 'fetchMachines: non-success response',
              category: 'sync.machines',
              level: SentryLevel.warning,
              data: {
                'statusCode': statusCode,
                'cachedMachines': _machines.length,
              },
            ),
          ),
        );
        throw StateError('fetchMachines failed: statusCode=$statusCode');
      }
    } catch (error, stack) {
      if (Sync._isTransientConnectionError(error)) {
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: 'fetchMachines: transient fetch failure',
              category: 'sync.machines',
              level: SentryLevel.warning,
              data: {
                'cachedMachines': _machines.length,
                'error': error.toString(),
              },
            ),
          ),
        );
        logger.warning('Error fetching machines', error, stack);
        // Transient network errors are environmental, not app bugs.
        // LoggerService already forwards the warning to Sentry; do not
        // capture them as exceptions.
        rethrow;
      } else {
        logger.error('Error fetching machines', error, stack);
        if (error is StateError &&
            error.message.startsWith('fetchMachines failed:')) {
          rethrow;
        }
      }
    }
  }
}
