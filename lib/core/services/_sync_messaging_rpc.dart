part of 'sync_service.dart';

extension SyncMessagingRpc on Sync {
  /// Expected socket transport failures, rather than application failures.
  bool isExpectedSocketTransportError(Object error) =>
      error is SocketNotConnectedException ||
      error is SocketAckTimeoutException;

  Future<dynamic> machineRPC(
    String machineId,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final stopwatch = Stopwatch()..start();
    final generation = _runtimeGeneration;
    Duration remaining() {
      if (generation != _runtimeGeneration) {
        throw StateError('Machine RPC runtime changed');
      }
      final left = timeout - stopwatch.elapsed;
      if (left <= Duration.zero) {
        throw const SocketAckTimeoutException('rpc-call');
      }
      return left;
    }

    final rpcMetrics = OpenTelemetryService();
    var stageStartedMs = 0;
    final requestId = _createRpcRequestId('mrpc');
    var machineEncryption = encryption.getMachineEncryption(machineId);
    if (machineEncryption == null) {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'machineRPC: encryption null, awaiting machines',
            category: 'sync.machines',
            data: {
              'machineId': machineId,
              'method': method,
              'requestId': requestId,
            },
          ),
        ),
      );
      // Encryption may not be initialized yet — wait for pending fetch.
      // This can happen after socket reconnect when machinesSync was
      // invalidated but fetch hasn't completed yet.
      await machinesSync.invalidateAndAwait().timeout(
        remaining(),
        onTimeout: () => throw const SocketAckTimeoutException('rpc-call'),
      );
      remaining();
      machineEncryption = encryption.getMachineEncryption(machineId);
      if (machineEncryption == null) {
        throw StateError('Machine encryption not found for $machineId');
      }
    }

    final encrypted = await machineEncryption
        .encryptRaw(params)
        .timeout(
          remaining(),
          onTimeout: () => throw const SocketAckTimeoutException('rpc-call'),
        );
    final ackTimeout = remaining();
    if (method == 'spawn-happy-session' && InvalidateSync.isBackgrounded) {
      throw StateError('Machine RPC suspended');
    }
    rpcMetrics.recordDuration(
      'app.machine_rpc.stage',
      Duration(milliseconds: stopwatch.elapsedMilliseconds - stageStartedMs),
      attributes: {'method': method, 'stage': 'encryption'},
    );
    stageStartedMs = stopwatch.elapsedMilliseconds;
    final rpcElapsedBeforeSend = stopwatch.elapsedMilliseconds;
    // emitWithAck now throws SocketNotConnectedException (socket not connected)
    // or SocketAckTimeoutException (ACK timeout) instead of returning null.
    // These propagate as-is so callers can distinguish connection failures from
    // application-level errors.
    final Object? result;
    try {
      result = await socketIoClient.emitWithAck('rpc-call', {
        'method': '$machineId:$method',
        'params': encrypted,
        'requestId': requestId,
      }, timeout: ackTimeout);
      remaining();
      rpcMetrics.recordDuration(
        'app.machine_rpc.stage',
        Duration(milliseconds: stopwatch.elapsedMilliseconds - stageStartedMs),
        attributes: {'method': method, 'stage': 'socket_ack'},
      );
      stageStartedMs = stopwatch.elapsedMilliseconds;
    } catch (error) {
      rpcMetrics.recordDuration(
        'app.machine_rpc',
        stopwatch.elapsed,
        attributes: {
          'method': method,
          'outcome': 'transport_error',
          'error_class': error.runtimeType.toString(),
        },
      );
      // Expected transport failure: the socket is not connected (app
      // suspended / offline) or the ACK timed out (offline daemon).
      // This is normal operation against machines that are away, not a
      // client defect — keep the full-fidelity line local only (the
      // interpolated elapsedMs defeats grouping anyway) and skip Sentry.
      final expectedTransport = isExpectedSocketTransportError(error);
      if (expectedTransport) {
        logger.warningLocal(
          '[machineRPC] FAILED request=$requestId method=$method '
          'machine=$machineId '
          'elapsedMs=${stopwatch.elapsedMilliseconds}: $error',
        );
        rethrow;
      }
      // Unexpected transport failure: keep the full-fidelity line locally
      // (info-level so it does NOT forward to Sentry — the interpolated
      // elapsedMs defeats grouping and a wedged daemon mints a fresh issue
      // per retry). The Sentry side is a separate, stable-message capture
      // throttled per machine+method so the retry storm collapses to one
      // issue.
      logger.info(
        '[machineRPC] FAILED request=$requestId method=$method '
        'machine=$machineId '
        'elapsedMs=${stopwatch.elapsedMilliseconds}: $error',
      );
      if (_shouldCaptureMachineRpcWarn('$machineId:$method:failed')) {
        unawaited(
          Sentry.captureMessage(
            '[machineRPC] FAILED method=$method',
            level: SentryLevel.warning,
            withScope: (scope) {
              // Stable fingerprint so every FAILED ping (any machine,
              // any elapsedMs) collapses into a single Sentry issue
              // instead of one issue per call.
              scope
                ..fingerprint = ['machineRPC', 'failed', method]
                ..setTag('machineRPC_machine', machineId)
                ..setContexts('machineRPC', {
                  'machineId': machineId,
                  'method': method,
                  'requestId': requestId,
                  'elapsedMs': stopwatch.elapsedMilliseconds,
                  'error': error.toString(),
                });
            },
          ),
        );
      }
      rethrow;
    }

    if (result is Map && result['ok'] == true) {
      final encryptedResult = result['result'] as String?;
      if (encryptedResult == null) {
        throw StateError('Machine RPC $method returned null result');
      }
      final decrypted = await machineEncryption
          .decryptRaw(encryptedResult)
          .timeout(
            remaining(),
            onTimeout: () => throw const SocketAckTimeoutException('rpc-call'),
          );
      remaining();
      rpcMetrics.recordDuration(
        'app.machine_rpc.stage',
        Duration(milliseconds: stopwatch.elapsedMilliseconds - stageStartedMs),
        attributes: {'method': method, 'stage': 'decrypt_decode'},
      );
      try {
        _throwIfRpcError(decrypted, fallbackMethod: method);
      } on RpcException catch (error) {
        rpcMetrics.recordDuration(
          'app.machine_rpc',
          stopwatch.elapsed,
          attributes: {
            'method': method,
            'outcome': 'rpc_error',
            'error_class': error.code.wireValue,
          },
        );
        rethrow;
      }
      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs >= Sync.slowMachineRpcThresholdMs(method)) {
        // Pre-flight pings over 2s usually mean a wedged daemon or a
        // saturated socket. Keep the full line locally at info-level
        // (does not forward to Sentry — interpolated elapsedMs defeats
        // grouping and a wedged daemon would mint a fresh issue per
        // retry). A breadcrumb preserves the per-call timing context.
        // The Sentry capture is a separate, stable-message event
        // throttled per machine+method so the storm collapses to one
        // issue. Stays well under the 8 s createSession budget.
        logger.info(
          '[machineRPC] SLOW request=$requestId method=$method '
          'machine=$machineId '
          'elapsedMs=$elapsedMs preSendMs=$rpcElapsedBeforeSend',
        );
        unawaited(
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: 'machineRPC SLOW',
              category: 'sync.machines',
              level: SentryLevel.warning,
              data: {
                'machineId': machineId,
                'method': method,
                'requestId': requestId,
                'elapsedMs': elapsedMs,
                'preSendMs': rpcElapsedBeforeSend,
              },
            ),
          ),
        );
        if (_shouldCaptureMachineRpcWarn('$machineId:$method:slow')) {
          unawaited(
            Sentry.captureMessage(
              '[machineRPC] SLOW method=$method',
              level: SentryLevel.warning,
              withScope: (scope) {
                // Stable fingerprint so every SLOW ping collapses into
                // one Sentry issue instead of one per elapsedMs value.
                scope
                  ..fingerprint = ['machineRPC', 'slow', method]
                  ..setTag('machineRPC_machine', machineId)
                  ..setContexts('machineRPC', {
                    'machineId': machineId,
                    'method': method,
                    'requestId': requestId,
                    'elapsedMs': elapsedMs,
                    'preSendMs': rpcElapsedBeforeSend,
                  });
              },
            ),
          );
        }
      }
      if (decrypted == null) {
        logger.error('machineRPC $method: decryption returned null');
        unawaited(
          Sentry.captureMessage(
            'machineRPC $method: decryption returned null',
            level: SentryLevel.error,
          ),
        );
      }
      rpcMetrics.recordDuration(
        'app.machine_rpc',
        stopwatch.elapsed,
        attributes: {'method': method, 'outcome': 'ok'},
      );
      return decrypted;
    }
    // Log the failure reason if available
    final rpcError = RpcException.fromWire(
      result is Map ? result : <String, dynamic>{'error': result},
      fallbackMethod: method,
    );
    rpcMetrics.recordDuration(
      'app.machine_rpc',
      stopwatch.elapsed,
      attributes: {
        'method': method,
        'outcome': 'rpc_error',
        'error_class': rpcError.code.wireValue,
      },
    );
    throw rpcError;
  }

  String _createRpcRequestId(String prefix) {
    final random = Random.secure();
    const alphabet = '0123456789abcdef';
    final chars = StringBuffer('${prefix}_');
    for (var i = 0; i < 24; i++) {
      chars.write(alphabet[random.nextInt(alphabet.length)]);
    }
    return chars.toString();
  }

  /// Test-aware wrapper for [machineRPC] used by the pre-flight
  /// liveness probe.
  ///
  /// Unit tests stub the typed RPC layer via [testMachineRPCOverride],
  /// but [ensureMachineReachable] calls the raw [machineRPC] path so
  /// it can treat any reply (including `Method not found`) as proof of
  /// liveness. This helper bridges the two: in tests it simulates the
  /// raw response path, in production it delegates to [machineRPC].
  Future<dynamic> _probeMachineRPC(
    String machineId,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final override = testEnsureMachineReachableMachineRPCOverride;
    Object? raw;
    if (override != null) {
      raw = await override(machineId, method, params);
      if (raw == null) {
        throw StateError(
          'Machine RPC $method returned null — '
          'test override may be misconfigured',
        );
      }
      if (raw is! Map<String, dynamic>) {
        throw StateError(
          'Machine RPC $method returned unexpected type: ${raw.runtimeType} '
          '(value: $raw)',
        );
      }
      if (raw['error'] != null) {
        throw RpcException.fromWire(raw, fallbackMethod: method);
      }
      if (raw['ok'] == true) return raw['result'];
      throw StateError('Machine RPC $method failed: $raw');
    }
    return machineRPC(machineId, method, params, timeout: timeout);
  }

  /// Cheap pre-flight liveness probe before long-running spawn RPCs.
  ///
  /// A fresh `activeAt` heartbeat only proves the daemon was alive
  /// recently — a wedged daemon (or dead socket on the server side)
  /// still ACKs nothing and previously burned the full 60 s spawn
  /// timeout before failing. This sends a `ping` RPC with a short
  /// timeout instead: any reply — even `Method not found` from daemons
  /// that predate the `ping` handler — proves the machine is reachable
  /// within seconds.
  ///
  /// Pings are idempotent: retry one transient routing failure or ACK
  /// timeout, with both attempts sharing a bounded caller deadline. A server
  /// handler miss is never proof of daemon liveness. A legacy daemon's
  /// unsupported ping response does prove that its handler received the call.
  Future<void> ensureMachineReachable(
    String machineId, {
    Duration timeout = const Duration(milliseconds: 24300),
  }) async {
    final generation = _runtimeGeneration;
    final clock = Stopwatch()..start();
    void checkRuntime() {
      if (generation != _runtimeGeneration) {
        throw StateError('Machine RPC runtime changed');
      }
      if (InvalidateSync.isBackgrounded) {
        throw StateError('Machine RPC suspended');
      }
    }

    StateError unreachable([Object? cause]) {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'ensureMachineReachable: readiness exhausted',
            category: 'sync.machines',
            level: SentryLevel.warning,
            data: {
              'machineId': machineId,
              'reason': cause?.runtimeType.toString() ?? 'deadline',
            },
          ),
        ),
      );
      return StateError('Machine is unreachable');
    }

    checkRuntime();
    final override = testEnsureMachineReachableOverride;
    if (override != null) {
      await override(machineId).timeout(timeout);
      checkRuntime();
      return;
    }
    // Generic spawn fixtures opt in to ping behavior explicitly.
    if (testMachineRPCOverride != null &&
        testEnsureMachineReachableMachineRPCOverride == null) {
      return;
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      checkRuntime();
      final remaining = timeout - clock.elapsed;
      if (remaining <= Duration.zero) {
        throw unreachable();
      }
      final probeTimeout = remaining < const Duration(seconds: 12)
          ? remaining
          : const Duration(seconds: 12);
      try {
        await _probeMachineRPC(
          machineId,
          'ping',
          const {},
          timeout: probeTimeout,
        ).timeout(
          probeTimeout,
          onTimeout: () => throw const SocketAckTimeoutException('rpc-call'),
        );
        checkRuntime();
        return;
      } on RpcException catch (error) {
        checkRuntime();
        if (error.code == RpcErrorCode.methodUnsupported) return;
        if (!error.retryable ||
            (error.code != RpcErrorCode.handlerOffline &&
                error.code != RpcErrorCode.forwardingFailed)) {
          rethrow;
        }
        if (attempt == 1) {
          throw unreachable(error);
        }
      } on SocketAckTimeoutException {
        checkRuntime();
        if (attempt == 1) throw unreachable();
      } on SocketNotConnectedException catch (error) {
        checkRuntime();
        if (attempt == 1) throw unreachable(error);
      } on StateError catch (error) {
        checkRuntime();
        final message = error.message.toLowerCase();
        if (message.contains('method not found') ||
            message.contains('unknown method') ||
            message.contains('method not available')) {
          return;
        }
        rethrow;
      }
      checkRuntime();
      const delay = Duration(milliseconds: 300);
      if (clock.elapsed + delay >= timeout) {
        throw unreachable();
      }
      await Future<void>.delayed(delay);
      checkRuntime();
    }
  }

  /// RPC call for sessions - uses session-specific encryption.
  Future<dynamic> sessionRPC(
    String sessionId,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final override = testSessionRPCOverride;
    if (override != null) {
      return override(sessionId, method, params);
    }

    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message:
                'fetchMessages: encryption null, '
                'awaiting sessions',
            category: 'sync.messages',
            data: {'sessionId': sessionId},
          ),
        ),
      );
      // Encryption may not be initialized yet — wait for pending fetch.
      await sessionsSync.invalidateAndAwait();
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        // Force a full fetch in case changedSince race skipped the session.
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        throw StateError('Session encryption not found for $sessionId');
      }
    }

    final requestId = _createRpcRequestId('srpc');
    final encrypted = await sessionEncryption.encryptRaw(params);
    // emitWithAck now throws SocketNotConnectedException or
    // SocketAckTimeoutException instead of returning null.
    final result = await socketIoClient.emitWithAck('rpc-call', {
      'method': '$sessionId:$method',
      'params': encrypted,
      'requestId': requestId,
    }, timeout: timeout);

    if (result is Map && result['ok'] == true) {
      final encryptedResult = result['result'] as String?;
      if (encryptedResult == null) return null;
      final decrypted = await sessionEncryption.decryptRaw(encryptedResult);
      _throwIfRpcError(decrypted, fallbackMethod: method);
      return decrypted;
    }
    // Log the failure reason if available
    throw RpcException.fromWire(
      result is Map ? result : <String, dynamic>{'error': result},
      fallbackMethod: method,
    );
  }

  void _throwIfRpcError(dynamic value, {required String fallbackMethod}) {
    if (value is! Map || value['error'] == null) return;
    final isTyped = value['code'] != null;
    final isExplicitFailure = value['ok'] == false;
    final isLegacyEnvelope = value.length == 1;
    if (!isTyped && !isExplicitFailure && !isLegacyEnvelope) return;
    throw RpcException.fromWire(value, fallbackMethod: fallbackMethod);
  }

  /// Typed wrapper around [machineRPC] that deserialises the response.
  Future<Resp> _typedMachineRPC<Resp>(
    String machineId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final override = testMachineRPCOverride;
    final generation = _runtimeGeneration;
    final clock = Stopwatch()..start();
    void checkRuntime({bool checkSuspension = true}) {
      if (generation != _runtimeGeneration) {
        throw StateError('Machine RPC runtime changed');
      }
      if (checkSuspension &&
          method == 'spawn-happy-session' &&
          InvalidateSync.isBackgrounded) {
        throw StateError('Machine RPC suspended');
      }
    }

    checkRuntime();
    if (method == 'spawn-happy-session') {
      // Readiness is safe to retry; the spawn itself is never replayed after
      // an ambiguous response. Include readiness in the original RPC budget.
      await ensureMachineReachable(machineId, timeout: timeout);
    }
    checkRuntime();
    final capabilityTimeout = timeout - clock.elapsed;
    if (capabilityTimeout <= Duration.zero) {
      throw const SocketAckTimeoutException('rpc-call');
    }
    if (override == null) {
      await ensureMachineRPCSupported(machineId, method).timeout(
        capabilityTimeout,
        onTimeout: () => throw const SocketAckTimeoutException('rpc-call'),
      );
    }
    checkRuntime();
    final remaining = timeout - clock.elapsed;
    if (remaining <= Duration.zero) {
      throw const SocketAckTimeoutException('rpc-call');
    }
    final raw = override != null
        ? await override(machineId, method, params).timeout(remaining)
        : await machineRPC(machineId, method, params, timeout: remaining);
    // Once dispatched, a confirmed spawn must survive backgrounding. The
    // account generation still fences the result across logout/replacement.
    checkRuntime(checkSuspension: false);
    // machineRPC now throws on null — this check is only needed for the
    // test override path which may return null.
    if (raw == null) {
      throw StateError(
        'Machine RPC $method returned null — '
        'test override may be misconfigured',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Machine RPC $method returned unexpected type: ${raw.runtimeType} '
        '(value: $raw)',
      );
    }
    final error = raw['error'];
    if (method == 'spawn-happy-session' &&
        error is String &&
        error.contains('provider_model_mismatch')) {
      throw IncompatibleProviderAndModelError(
        error.replaceFirst('provider_model_mismatch: ', ''),
      );
    }
    return fromJson(raw);
  }

  /// Typed wrapper around [sessionRPC] that deserialises the response.
  Future<Resp> _typedSessionRPC<Resp>(
    String sessionId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson,
  ) async {
    if (testSessionRPCOverride == null) {
      await ensureSessionRPCSupported(sessionId, method);
    }
    final raw = await sessionRPC(sessionId, method, params);
    // Handle null or non-Map responses gracefully
    if (raw == null) {
      throw StateError(
        'Session RPC $method returned null - encryption may have failed',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Session RPC $method returned unexpected type: ${raw.runtimeType} '
        '(value: $raw)',
      );
    }
    return fromJson(raw);
  }

  /// Checks whether the session's CLI process is running.
  ///
  /// If the session is already online or starting/running, returns
  /// `false` (no restore needed).  If the session is offline and has
  /// `machineId`/`path` metadata, sends `spawn-happy-session` to
  /// revive it and returns `true` to signal that a **new** process
  /// was spawned (meaning old in-flight state like pending permissions
  /// is gone).
  ///
  /// Returns `false` when no restore was attempted (session was
  /// already ready, or metadata was missing).
  Future<bool> _ensureSessionProcess(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) return false;

    final lifecycleState = session.effectiveLifecycleState;
    // Guard against stale lifecycleState
    // (same logic as _resolveSendTargetSession).
    final lifecycleStateSince = session.metadata?.lifecycleStateSince;
    final lifecycleRecent =
        lifecycleStateSince != null &&
        DateTime.now().millisecondsSinceEpoch - lifecycleStateSince < 120000;
    final agentIsStartingOrRunning =
        lifecycleState == 'starting' || lifecycleState == 'running';
    final isArchived = lifecycleState == 'archived';
    final hasLifecycleError = session.hasLifecycleError;
    final looksReady =
        !isArchived &&
        !hasLifecycleError &&
        (session.isOnline || (agentIsStartingOrRunning && lifecycleRecent));

    // Grace period for recently-spawned sessions — same threshold as
    // _resolveSendTargetSession. Prevents premature auto-restore for
    // permission actions while the daemon is still booting the agent.
    final recentlySpawned =
        _sessionSpawnedAt[sessionId] != null &&
        DateTime.now().millisecondsSinceEpoch - _sessionSpawnedAt[sessionId]! <
            120000;

    if (looksReady || (recentlySpawned && !hasLifecycleError)) return false;

    final machineId = session.metadata?.machineId;
    final path = session.metadata?.path;
    if (machineId == null ||
        machineId.isEmpty ||
        path == null ||
        path.isEmpty) {
      return false;
    }

    logger.info(
      '[permission] session=$sessionId appears offline '
      '(presence=${session.presence}, '
      'lifecycleState=$lifecycleState); '
      'attempting auto-restore',
    );

    try {
      // Resolve profile env vars for this session before spawning.
      final spawnResult = await _getSpawnEnvVarsForSession(sessionId);
      final sessionAgent =
          session.metadata?.flavor ??
          _sessionSpawnedAgent[sessionId] ??
          'claude';
      final normalizedModelMode = _normalizeModelModeForAgent(
        session.modelMode,
        sessionAgent,
        profile: spawnResult.profile,
      );
      // Drop incompatible model overrides (e.g. a Claude model alias paired
      // with a third-party Anthropic-compatible base URL). The daemon rejects
      // that combination with `provider_model_mismatch`, so mirror the
      // createSession guard here to keep auto-restore from failing.
      final spawnProfileResolution = _resolveEffectiveProfileForSpawn(
        profile: spawnResult.profile,
        modelMode: normalizedModelMode,
        agent: sessionAgent,
        // The session's stored model is what the previous process was
        // running; restoring with the profile default instead would silently
        // switch providers under a permission answer.
        explicitModelPick:
            normalizedModelMode != null && normalizedModelMode != 'default',
      );
      final effectiveModelMode = spawnProfileResolution.modelMode;
      final effectiveEnvVars = spawnProfileResolution.profile != null
          ? _spawnEnvForModel(
              spawnResult.envVars,
              agent: sessionAgent,
              profile: spawnProfileResolution.profile,
              modelMode: effectiveModelMode,
            )
          : <String, String>{};
      final req = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: path,
        sessionId: sessionId,
        isRestore: true,
        agent: sessionAgent,
        permissionMode: session.permissionMode,
        spawnBackend: _spawnBackendForExistingSession(
          session,
          _machines[machineId],
        ),
        repoUrl: session.metadata?.repoUrl,
        repoRef: session.metadata?.repoRef,
        repoCommit: session.metadata?.repoCommit,
        model: _getModelOverride(
          agent: sessionAgent,
          profile: spawnProfileResolution.profile,
          modelMode: effectiveModelMode,
        ),
        environmentVariables: effectiveEnvVars,
      );
      final result = await _spawnHappySessionRPC(
        machineId,
        req,
        timeout: const Duration(seconds: 60),
      );
      if (result.type == 'success') {
        final restoredSession = _sessions[sessionId];
        final restoredMetadata = restoredSession?.metadata;
        if (restoredSession != null && restoredMetadata != null) {
          _sessions[sessionId] = restoredSession.copyWith(
            metadata: _metadataWithSpawnResult(restoredMetadata, result),
          );
        }
        _registerSpawn(
          result.sessionId ?? sessionId,
          profileId: spawnResult.profile?.id,
          modelMode: effectiveModelMode,
          agent: sessionAgent,
        );
        logger.info(
          '[permission] auto-restore succeeded '
          'session=$sessionId',
        );
        return true;
      }
      logger.warning(
        '[permission] auto-restore not successful '
        'session=$sessionId type=${result.type ?? 'null'} '
        'error=${result.errorMessage ?? 'unknown'}',
      );
    } catch (error, stack) {
      if (Sync._isTransientRpcError(error) ||
          Sync._isRpcMethodNotAvailable(error)) {
        final reason = Sync._isRpcMethodNotAvailable(error)
            ? 'RPC unavailable'
            : Sync._isRpcReplicaTimeout(error)
            ? 'RPC replica timeout'
            : 'transient';
        logger.info(
          '[permission] auto-restore failed ($reason) '
          'session=$sessionId: $error',
        );
      } else {
        logger.error(
          '[permission] auto-restore failed '
          'session=$sessionId',
          error,
          stack,
        );
      }
    }
    return false;
  }

  /// Fire local notifications for any newly-detected pending
  /// permission requests that the user hasn't seen yet.
  ///
  /// Called after [fetchSessions] merges updated sessions and
  /// after inline socket updates apply new agent state.
  void _checkForNewPermissionRequests(Iterable<Session> sessions) {
    for (final session in sessions) {
      // Don't notify for the session the user is viewing — they
      // can see the permission footer already.
      if (session.id == _visibleSessionId) continue;

      final requests = session.agentState?.requests;
      if (requests == null || requests.isEmpty) continue;

      for (final entry in requests.entries) {
        final permId = entry.key;
        if (_notifiedPermissionIds.contains(permId)) continue;
        // Evict oldest entries when the cap is reached to bound memory.
        if (_notifiedPermissionIds.length >= Sync._maxNotifiedPermissionIds) {
          _notifiedPermissionIds.remove(_notifiedPermissionIds.first);
        }
        _notifiedPermissionIds.add(permId);

        final request = entry.value;
        Map<String, dynamic>? toolInput;
        if (request.arguments is Map) {
          toolInput = Map<String, dynamic>.from(request.arguments as Map);
        }

        final sessionName =
            session.metadata?.summary?.text ??
            session.metadata?.path?.split('/').last;

        unawaited(
          NotificationService.instance.showPermissionNotification(
            sessionId: session.id,
            permissionId: permId,
            toolName: request.tool,
            toolInput: toolInput,
            sessionName: sessionName,
          ),
        );
      }
    }
  }

  /// Locally clear stale permission requests from a session's
  /// [AgentState] so the UI immediately unlocks the input box
  /// and hides the "permission required" banner.
  void _clearStalePermissionRequests(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;
    final hadRequests =
        session.agentState?.requests != null &&
        session.agentState!.requests!.isNotEmpty;
    if (hadRequests) {
      // Cancel any pending permission notifications for this session.
      for (final permId in session.agentState!.requests!.keys) {
        _notifiedPermissionIds.remove(permId);
        unawaited(
          NotificationService.instance.cancelPermissionNotification(permId),
        );
      }
      _sessions[sessionId] = session.copyWith(
        agentState: AgentState(
          controlledByUser: session.agentState?.controlledByUser,
          completedRequests: session.agentState?.completedRequests,
        ),
      );
    }
    // Also cancel any pending permissions on tool-call messages so
    // the UI stops showing Allow/Deny buttons that will always fail.
    final messages = _sessionMessages[sessionId];
    if (messages != null) {
      var changed = false;
      final updated = List<Map<String, dynamic>>.from(messages);
      for (var i = 0; i < updated.length; i++) {
        final msg = updated[i];
        if (msg['kind'] != 'tool-call') continue;
        final perm = WireParsers.asMap(msg['permission']);
        if (perm == null || perm['status'] != 'pending') continue;
        updated[i] = {
          ...msg,
          'permission': {...perm, 'status': 'canceled'},
        };
        changed = true;
      }
      if (changed) {
        _sessionMessages[sessionId] = updated;
        _invalidateMessageCaches(sessionId);
        _notifySessionMessagesChanged(sessionId);
      }
    }
    if (hadRequests || messages != null) {
      _notifyDataChanged({SyncDomain.messages, SyncDomain.sessions});
    }
  }

  /// Allow a permission request for a session.
  ///
  /// The server acknowledges with `ok: true` but the response
  /// payload shape varies — the RN app ignores it entirely, so
  /// we just fire-and-forget the RPC without deserialising.
  Future<PermissionResponse> sessionAllow(
    String sessionId,
    String permissionId, {
    String? mode,
    List<String>? allowTools,
    String? decision,
    Map<String, dynamic>? updatedInput,
  }) async {
    final restored = await _ensureSessionProcess(sessionId);
    if (restored) {
      _clearStalePermissionRequests(sessionId);
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
      throw StateError(
        'Session was restarted — this permission has expired. '
        'The agent will re-request it if still needed.',
      );
    }
    try {
      if (testSessionRPCOverride == null) {
        await ensureSessionRPCSupported(sessionId, 'permission');
      }
      final response = await sessionRPC(
        sessionId,
        'permission',
        PermissionRequest(
          id: permissionId,
          approved: true,
          mode: mode,
          allowTools: allowTools,
          decision: decision,
          updatedInput: updatedInput,
        ).toJson(),
      );
      _throwIfPermissionRpcFailed(response, 'allow');
      return response is Map
          ? PermissionResponse.fromJson(Map<String, dynamic>.from(response))
          : const PermissionResponse(success: true);
    } on StateError {
      // Permission was rejected by the server — clear stale local
      // state so the UI unlocks.
      _clearStalePermissionRequests(sessionId);
      rethrow;
    } finally {
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
    }
  }

  /// Deny a permission request for a session.
  ///
  /// See [sessionAllow] — response payload is ignored.
  Future<PermissionResponse> sessionDeny(
    String sessionId,
    String permissionId, {
    String? decision,
  }) async {
    final restored = await _ensureSessionProcess(sessionId);
    if (restored) {
      _clearStalePermissionRequests(sessionId);
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
      throw StateError(
        'Session was restarted — this permission has expired. '
        'The agent will re-request it if still needed.',
      );
    }
    try {
      if (testSessionRPCOverride == null) {
        await ensureSessionRPCSupported(sessionId, 'permission');
      }
      final response = await sessionRPC(
        sessionId,
        'permission',
        PermissionRequest(
          id: permissionId,
          approved: false,
          decision: decision,
        ).toJson(),
      );
      _throwIfPermissionRpcFailed(response, 'deny');
      return response is Map
          ? PermissionResponse.fromJson(Map<String, dynamic>.from(response))
          : const PermissionResponse(success: true);
    } on StateError {
      _clearStalePermissionRequests(sessionId);
      rethrow;
    } finally {
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
    }
  }

  void _throwIfPermissionRpcFailed(dynamic response, String action) {
    if (response is! Map) return;
    final success = response['success'];
    final ok = response['ok'];
    final isFailure = success == false || ok == false;
    if (!isFailure) return;
    final error = response['error'];
    throw StateError(
      'Permission $action failed: ${error?.toString() ?? 'unknown error'}',
    );
  }

  /// Kill a session's agent process.
  Future<KillSessionResponse> killSession(String sessionId) async {
    return _typedSessionRPC(
      sessionId,
      'killSession',
      const {},
      KillSessionResponse.fromJson,
    );
  }

  /// Stops the daemon-owned process or pod for a session and waits for the
  /// daemon to confirm that the runtime has disappeared.
  Future<StopSessionResponse> stopSessionProcess(String sessionId) async {
    final session = _sessions[sessionId];
    final machineId = session?.metadata?.machineId;
    if (machineId == null || machineId.isEmpty) {
      throw StateError('Session has no owning machine');
    }
    return _typedMachineRPC(machineId, 'stop-session', <String, dynamic>{
      'sessionId': sessionId,
    }, StopSessionResponse.fromJson);
  }

  /// Abort the current agent turn without killing the session.
  Future<AbortResponse> abortSession(
    String sessionId, {
    String reason = '',
  }) async {
    return _typedSessionRPC(sessionId, 'abort', {
      'reason': reason,
    }, AbortResponse.fromJson);
  }

  /// Refresh purchases data
  Future<void> refreshPurchases() async {
    await settingsManager?.refreshPurchases();
  }

  /// Evict stale messagesSync entries that haven't been used recently.
  /// Each InvalidateSync holds Timers, Completer, and closures capturing
  /// the Sync singleton — unbounded growth for 500+ sessions would leak
  /// memory across long-lived app sessions.
  static const int _messagesSyncEvictThresholdMs = 5 * 60 * 1000;
  void _evictStaleMessagesSync() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stale = messagesSync.entries
        .where((e) {
          final entry = e.value;
          final lastRunEnd = entry.lastRunEndMs;
          return lastRunEnd != null &&
              now - lastRunEnd > _messagesSyncEvictThresholdMs;
        })
        .map((e) => e.key)
        .toList();
    for (final id in stale) {
      messagesSync[id]?.dispose();
      messagesSync.remove(id);
    }
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    await settingsManager?.refreshProfile();
  }

  /// Get authentication credentials
  AuthCredentials getCredentials() {
    return credentials;
  }

  /// Synchronously transfers routing ownership to [sessionId] and creates its
  /// message queue. ChatScreen calls this during initState, then waits for its
  /// first frame before starting [onSessionVisible]'s heavier cache/regroup/
  /// network work.
  void prepareSessionVisibility(String sessionId) {
    final previousVisibleSessionId = _visibleSessionId;
    if (previousVisibleSessionId != sessionId) _clearMessageStreams();
    _visibleSessionId = sessionId;
    // Both ends of a chat switch count as activity for the idle-window
    // shrink sweep — the session just left keeps its full window for
    // another idle period so an immediate back-navigation is cheap.
    final touchNowMs =
        testIdleShrinkNowMsOverride ?? DateTime.now().millisecondsSinceEpoch;
    _sessionMessagesTouchedAtMs[sessionId] = touchNowMs;
    if (previousVisibleSessionId != null) {
      _sessionMessagesTouchedAtMs[previousVisibleSessionId] = touchNowMs;
    }
    // When the user switches chats, tear down the previous session's
    // message-sync timer.  Otherwise the old session's InvalidateSync
    // keeps firing (every 500ms minInterval) for every pending socket
    // event that arrived while it was visible, causing the fetch storm
    // seen in the logs where multiple non-visible sessions fetch forever.
    if (previousVisibleSessionId != null &&
        previousVisibleSessionId != sessionId) {
      messagesSync[previousVisibleSessionId]?.dispose();
      messagesSync.remove(previousVisibleSessionId);
    }

    // Keep this lightweight registration synchronous. Session creation and
    // optimistic send rely on the queue existing as soon as visibility is
    // requested; only the expensive cache/regroup/network work belongs after
    // the first-frame yield below.
    if (isInitialized && !messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId] = _createMessagesSync(sessionId);
    }
  }

  /// On session visible handler
  Future<void> onSessionVisible(String sessionId) async {
    prepareSessionVisibility(sessionId);

    // Non-widget callers still receive an asynchronous boundary. ChatScreen
    // provides the stronger end-of-frame barrier before invoking this method.
    await Future<void>.delayed(Duration.zero);
    if (!isInitialized || _visibleSessionId != sessionId) return;

    _sessionUnreadCounts.remove(sessionId);
    _sessionUnreadLastIncrementMs.remove(sessionId);
    // Clear any residual failed Future from the inline queue so that
    // new messages can enter the inline fast path immediately.
    _inlineProcessor.clearSession(sessionId);

    // Populate _sessionSpawnedProfile from MMKV so that profile switches
    // are detected in _resolveSendTargetSession.  Without this, pre-existing
    // sessions (loaded from server, not spawned in this app instance) are
    // not tracked and profile changes are silently ignored — only the model
    // string changes while the session keeps running with the old profile's
    // env vars (API keys, base URLs).
    if (!_sessionSpawnedProfile.containsKey(sessionId)) {
      unawaited(
        MMKVStorage().getSessionProfile(sessionId).then((storedProfileId) {
          if (!_sessionSpawnedProfile.containsKey(sessionId)) {
            _sessionSpawnedProfile[sessionId] = storedProfileId;
          }
        }),
      );
    }

    final needsVisibleRegroup = _sessionsNeedingVisibleRegroup.remove(
      sessionId,
    );
    // Also run deferred sidechain grouping from cold-start cache restore.
    final needsSidechainRegroup = _sessionsNeedingSidechainRegroup.remove(
      sessionId,
    );
    if (needsVisibleRegroup || needsSidechainRegroup) {
      final messages = _sessionMessages[sessionId];
      if (messages != null &&
          messages.any((message) => message['isSidechain'] == true)) {
        _groupSidechainMessages(sessionId);
        _notifySessionMessagesChanged(sessionId);
        _notifyDataChanged({SyncDomain.messages});
        // Orphan walk-back was deferred while this session was in the
        // background (the background trim cap discards fetched pages).
        // Now that the session is visible the larger cap applies —
        // grant a fresh budget and schedule a sweep so the deferred
        // recovery actually runs.
        _orphanWalkbackOrphanIds.remove(sessionId);
        _orphanWalkbackParentKeys.remove(sessionId);
        _orphanFetchOlderNoProgressCount.remove(sessionId);
        _orphanSuppressedUntilMs.remove(sessionId);
        _scheduleSidechainRegroup(sessionId);
      }
    }

    // Evict stale messagesSync entries that haven't been used in 5 minutes.
    // Each InvalidateSync holds Timers, a Completer, and closures that
    // capture the Sync singleton — unbounded growth for 500+ sessions.
    _evictStaleMessagesSync();

    // Reclaim resident transcripts eagerly on switch. The throttled 5-minute
    // idle-shrink sweep alone lets a fast navigator pile up one full ~200-row
    // decrypted transcript per session for minutes before reclaim — the peak
    // heap a heavy user feels as lag mid-session. Now that visibility moved,
    // any full session outside the residency budget shrinks to the preview
    // window immediately (visible + unsettled-send sessions stay full).
    enforceResidentSessionBudgetNow();
    unawaited(
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'onSessionVisible',
          category: 'sync.messages',
          data: {
            'sessionId': sessionId,
            'hasPending': _sessionsWithPendingSocketMessages.contains(
              sessionId,
            ),
            'hasMessagesInMemory':
                _sessionMessages[sessionId]?.isNotEmpty ?? false,
            'cursorSeq': _sessionLastSeq[sessionId] ?? 0,
            'serverLastSeq': _sessions[sessionId]?.lastSeq ?? 0,
          },
        ),
      ),
    );

    // If this session received socket messages while non-visible, we MUST
    // fetch from the server to verify the burst. Embedded messages are
    // processed inline, but a dropped/out-of-order event can sit below the
    // newer high-water cursor. [_sessionSocketCatchUpAfterSeq] preserves the
    // pre-burst floor so fetchMessages overlaps that window.
    final hasPendingSocketMessages = _sessionsWithPendingSocketMessages.remove(
      sessionId,
    );
    if (hasPendingSocketMessages) {
      // The session.lastSeq hint can be stale when background socket events
      // arrived without an embedded message. Bypass fetchMessages()'s
      // cursor==server skip once so the message API is authoritative.
      _requestMessageFetchProbe(sessionId);
    }
    if (!isInitialized) return;
    if (!messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId] = _createMessagesSync(sessionId);
    }

    var shouldProbeAfterSessionsRefresh = false;
    try {
      shouldProbeAfterSessionsRefresh = sessionsSync.isPending;
    } on Error {
      // Some widget tests exercise ChatScreen with only in-memory sync state
      // and do not initialize the global network sync queues.
      return;
    }
    final deferredProbeIntent = shouldProbeAfterSessionsRefresh
        ? _captureMessageFetchProbeIntent(sessionId)
        : null;

    // Only tail-refresh when we have no messages in memory for this session
    // (first open or after restart).  When messages are already loaded the
    // incremental delta path (afterSeq = _sessionLastSeq) is sufficient and
    // avoids re-downloading the last 200 messages on every navigation.
    var hasMessages =
        _sessionMessages.containsKey(sessionId) &&
        (_sessionMessages[sessionId]?.isNotEmpty ?? false);

    if (logger.shouldLog(LogLevel.debug)) {
      logger.debug(
        '[onSessionVisible] sessionId=$sessionId '
        'hasPendingSocketMessages=$hasPendingSocketMessages '
        'hasMessagesInMemory=$hasMessages '
        'cursorSeq=${_sessionLastSeq[sessionId] ?? 0} '
        'serverLastSeq=${_sessions[sessionId]?.lastSeq ?? 0}',
      );
    }

    if (!hasMessages) {
      // Restore from MMKV cache so the UI shows messages immediately
      // while the HTTP fetch is in flight.  Even when
      // hasPendingSocketMessages is true, show the (possibly stale)
      // cache as a starting point — the user sees *something* instead
      // of a loading spinner for 5-15s while the server fetch runs.
      // The incremental delta fetch will fill in any missing messages.
      try {
        final cached = await MessageCacheService().getMessagesAsync(sessionId);
        if (logger.shouldLog(LogLevel.debug)) {
          logger.debug(
            '[onSessionVisible] cacheRestore: ${cached.length} '
            'cached messages '
            '(hasPendingSocket=$hasPendingSocketMessages)',
          );
        }
        if (cached.isNotEmpty) {
          _sessionMessages[sessionId] = cached;
          _sessionsRestoredFromMessageCache.add(sessionId);
          // Seed the content signatures for the restored window, exactly as
          // the cold-start restore in `_restoreRecentCachedMessagesAsync`
          // does. Without this the signature map is empty, so the next tail
          // refresh's pre-filter matches nothing and re-decrypts the whole
          // restored window.
          _rebuildSessionContentSignatures(sessionId);
          _invalidateMessageCaches(sessionId);
          final maxSeq = _maxCachedMessageSeq(cached);
          if (maxSeq != null) {
            _seedSeqCursorFromCache(sessionId, maxSeq);
          }
          hasMessages = true;
          // Re-run the sidechain grouper so cached sidechain messages
          // are correctly re-parented into their parent Task messages.
          if (cached.any((m) => m['isSidechain'] == true)) {
            _groupSidechainMessages(sessionId);
          }
          // Notify UI immediately so it can render cached messages.
          _notifySessionMessagesChanged(sessionId);
          _notifyDataChanged({SyncDomain.messages});
          // Recalculate the older-messages boundary from the cache
          // so hasOlderMessages() returns the correct value even if
          // _restoreAllCachedMessagesAsync hasn't run yet or the
          // session grew since the persisted boundary was saved.
          _ensureFirstLoadedSeq(sessionId);
        }
      } catch (error, stack) {
        logger.warning(
          'Failed to restore cached messages for session $sessionId '
          'in onSessionVisible — falling back to server fetch',
          error,
          stack,
        );
        hasMessages = false;
      }
      // Only request a tail refresh when there are NO messages to show.
      // When cache was restored, the incremental delta path (afterSeq =
      // _sessionLastSeq) is sufficient and avoids a destructive
      // gap-recovery that clears the cached messages the user already
      // sees.  The delta fetch will pick up newer messages and merge
      // them with the cache.
      if (!hasMessages) {
        _requestTailRefresh(sessionId);
        if (logger.shouldLog(LogLevel.debug)) {
          logger.debug(
            '[onSessionVisible] tailRefresh requested '
            '(hasMessages=$hasMessages '
            'hasPendingSocket=$hasPendingSocketMessages)',
          );
        }
      }
    } else {
      // Messages are in memory (from cache or previous load). Check if the
      // server has newer messages that we're missing. This handles the case
      // where the app was closed and new messages arrived — delta sync may
      // not update session.lastSeq if only messages changed (no metadata).
      final cursorSeq = _sessionLastSeq[sessionId] ?? 0;
      final serverLastSeq = _sessions[sessionId]?.lastSeq ?? 0;
      final hadPendingUpdates = _sessionsWithPendingUpdates.remove(sessionId);

      if (logger.shouldLog(LogLevel.debug)) {
        logger.debug(
          '[onSessionVisible] hasMessages path: cursorSeq=$cursorSeq '
          'serverLastSeq=$serverLastSeq hadPendingUpdates=$hadPendingUpdates',
        );
      }

      // Check for gap: server is ahead of our cursor
      if (cursorSeq > 0 && serverLastSeq > cursorSeq) {
        // Server has messages we haven't seen. Let fetchMessages handle it
        // via the normal incremental delta path.
        if (logger.shouldLog(LogLevel.debug)) {
          logger.debug(
            '[onSessionVisible] gap detected: '
            'server($serverLastSeq) > cursor($cursorSeq) — will fetch delta',
          );
        }
      } else if (hadPendingUpdates) {
        // Socket events arrived while the session was non-visible. The
        // pre-burst catch-up floor makes the normal fetch overlap those
        // events even when the high-water cursor appears caught up. Only
        // request the broader tail path when cursor data is truly invalid.
        if (cursorSeq <= 0 || serverLastSeq <= 0) {
          _requestTailRefresh(sessionId);
          if (logger.shouldLog(LogLevel.debug)) {
            logger.debug(
              '[onSessionVisible] tailRefresh '
              '(pending updates, invalid cursor)',
            );
          }
        }
      }
    }
    if (hasMessages) {
      _scheduleLegacySocketGapRepair(sessionId);
    }
    messagesSync[sessionId]?.invalidate();

    // On cold start the chat can restore cached rows and run fetchMessages()
    // before the startup sessions sync has refreshed Session.lastSeq. If the
    // stale cached cursor equals the stale cached lastSeq, fetchMessages()
    // skips the HTTP request and messages that arrived while the app was
    // closed stay hidden. Probe once after the sessions sync settles so the
    // message API is authoritative for the visible chat.
    if (shouldProbeAfterSessionsRefresh) {
      unawaited(
        sessionsSync.awaitQueue().then((_) {
          if (!isInitialized || _visibleSessionId != sessionId) return;
          _requestMessageFetchProbe(sessionId, intent: deferredProbeIntent);
          messagesSync[sessionId]?.invalidate();
        }),
      );
    }
  }

  /// Called when the user leaves a chat screen entirely (not just switches
  /// to another chat).  Clears the visible-session pointer and tears down
  /// the message-sync timer so background sessions stop fetching.
  Future<void> onSessionInvisible(String sessionId) async {
    // Only clear _visibleSessionId if it still points to the session
    // being left. When switching chats, the new screen's onSessionVisible
    // may have already run before the old screen's dispose reaches here
    // (Flutter calls initState before dispose), so _visibleSessionId
    // may already be the new session.
    if (_visibleSessionId == sessionId) {
      _clearMessageStreams();
      _visibleSessionId = null;
    }
    messagesSync[sessionId]?.dispose();
    messagesSync.remove(sessionId);
  }

  void _requestTailRefresh(String sessionId) {
    _sessionsNeedingTailRefresh.add(sessionId);
    onTailRefreshRequested?.call(sessionId);
  }

  bool _shouldForceTailRefreshForPendingSession(String sessionId) {
    final hasMessages =
        _sessionMessages.containsKey(sessionId) &&
        (_sessionMessages[sessionId]?.isNotEmpty ?? false);
    if (!hasMessages) {
      return true;
    }

    final cursorSeq = _sessionLastSeq[sessionId] ?? 0;
    final serverLastSeq = _sessions[sessionId]?.lastSeq ?? 0;
    return cursorSeq <= 0 || serverLastSeq <= 0;
  }

  /// Whether a session's agent is connected enough to receive messages.
  /// Checks both ephemeral presence and lifecycle metadata.
  /// Guards against stale lifecycleState by requiring a recent timestamp.
  bool _isSessionReady(Session s) {
    // Prefer lifecycleState == 'running' when available: the agent sets
    // this after connecting to Socket.IO, which confirms push delivery
    // independent of ephemeral keep-alive traffic.  Without this, an
    // agent that's been thinking for >90 s (and so has stopped emitting
    // ephemeral events) would be wrongly treated as not-ready, forcing
    // waitForAgentReady to wait the full sessionReadyTimeoutMs.
    final lc = s.effectiveLifecycleState;
    if (s.hasLifecycleError) return false;
    if (lc == 'running') {
      final since = s.metadata?.lifecycleStateSince;
      if (since != null &&
          DateTime.now().millisecondsSinceEpoch - since < 120000) {
        return true;
      }
    }
    // Fallback: cross-check presence with a recent ephemeral event —
    // same logic as _resolveSendTargetSession to avoid trusting stale
    // 'online' presence after a daemon restart.
    final lastEphemeral = _lastEphemeralAt[s.id];
    final recentEphemeral =
        lastEphemeral != null &&
        DateTime.now().millisecondsSinceEpoch - lastEphemeral < 90000;
    return s.isOnline && recentEphemeral;
  }

  /// Whether the session currently looks reachable for incoming messages.
  ///
  /// This cross-checks ephemeral keep-alives with lifecycle metadata instead
  /// of trusting raw `presence == 'online'` by itself.
  bool isSessionReadyForMessages(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return false;
    return _isSessionReady(session);
  }

  /// Release outbox entries that were waiting for a session to become
  /// reachable. The outbox exposes only sessions with deferred entries, so
  /// this remains cheap even when the account has a large session catalog.
  void _wakeReadyOutboxSessions() {
    for (final sessionId in messageOutbox.readinessDeferredSessionIds) {
      final session = _sessions[sessionId];
      if (session?.hasLifecycleError == true) {
        messageOutbox.notifySessionUnavailable(sessionId);
        continue;
      }
      final lifecycle = session?.effectiveLifecycleState?.toLowerCase();
      // Match _deliverOutboxEntry's readiness gate. Presence can become
      // online before the encrypted lifecycle patch says running; waking in
      // that window would simply defer again on every session update.
      if (lifecycle == 'starting' || lifecycle == 'connecting') continue;
      if (isSessionReadyForMessages(sessionId)) {
        messageOutbox.notifySessionReady(sessionId);
      }
    }
  }

  /// Wait for agent to be ready.
  ///
  /// Returns `true` when the session's presence becomes `'online'`
  /// (set by `handleEphemeralUpdate` when the daemon sends
  /// `session-alive` keep-alives — typically within 2 seconds),
  /// or when `lifecycleState` becomes `'running'` (set by the agent
  /// after connecting to Socket.IO — confirms push delivery).
  /// Returns `false` immediately when the backend has already marked the
  /// session lifecycle as terminally errored.
  ///
  /// Note: `agentStateVersion` is intentionally NOT checked here
  /// because it persists across daemon restarts and would cause
  /// stale sessions to appear ready when the daemon is offline.
  Future<bool> waitForAgentReady(
    String sessionId, [
    int timeoutMs = Sync.sessionReadyTimeoutMs,
  ]) async {
    // Fast path: already online or lifecycle running
    final session = _sessions[sessionId];
    if (session != null && _isSessionReady(session)) return true;
    final initialFailure = _sessionLifecycleFailure(session);
    if (initialFailure != null) {
      logger.warning(
        '[sendMessage] waitForAgentReady terminal lifecycle error '
        'session=$sessionId error=$initialFailure',
      );
      return false;
    }

    logger.info(
      '[sendMessage] waitForAgentReady waiting '
      'session=$sessionId isOnline=${session?.isOnline} '
      'lifecycleState=${session?.effectiveLifecycleState}',
    );

    // Event-driven: resolve as soon as the sessions domain changes
    // and the target session is ready, or after timeoutMs.  We listen
    // on [onDomainChanged] (filtered to sessions) instead of the
    // global [onDataChanged] firehose because session-state changes
    // are now scoped to SyncDomain.sessions; the firehose only fires
    // for truly-everything notifications.
    final completer = Completer<bool>();
    StreamSubscription<SyncDomain>? sub;
    Timer? timer;

    timer = Timer(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) completer.complete(false);
      sub?.cancel();
    });

    sub = onDomainChanged.where((d) => d == SyncDomain.sessions).listen((_) {
      final s = _sessions[sessionId];
      final failure = _sessionLifecycleFailure(s);
      if (failure != null && !completer.isCompleted) {
        completer.complete(false);
        timer?.cancel();
        sub?.cancel();
        return;
      }
      if (s != null && _isSessionReady(s) && !completer.isCompleted) {
        completer.complete(true);
        timer?.cancel();
        sub?.cancel();
      }
    });

    final ready = await completer.future;
    logger.info(
      '[sendMessage] waitForAgentReady done '
      'session=$sessionId ready=$ready',
    );
    return ready;
  }

  String? _sessionLifecycleFailure(Session? session) {
    if (session == null || !session.hasLifecycleError) return null;
    final detail = session.metadata?.lifecycleStateError?.trim();
    if (detail != null && detail.isNotEmpty) return detail;
    return 'session lifecycle state is ${session.effectiveLifecycleState}';
  }
}
