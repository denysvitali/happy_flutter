part of 'sync_service.dart';

enum _RpcCapabilityNegativeKind { legacy, transient }

extension SyncCapabilities on Sync {
  static const Duration _defaultCapabilityProbeTimeout = Duration(seconds: 4);
  static const Duration _defaultCapabilityLegacyTtl = Duration(minutes: 5);
  static const Duration _defaultCapabilityTransientBackoffBase = Duration(
    seconds: 10,
  );
  static const Duration _maxCapabilityTransientBackoff = Duration(minutes: 2);

  RpcException _unsupportedCapabilityError(
    RpcCapabilities capabilities,
    String method,
  ) {
    final status = capabilities.statusFor(method);
    final protocolMismatch =
        status == RpcCapabilityStatus.protocolTooOld ||
        status == RpcCapabilityStatus.protocolTooNew;
    return RpcException(
      code: protocolMismatch
          ? RpcErrorCode.protocolUnsupported
          : RpcErrorCode.methodUnsupported,
      message: protocolMismatch
          ? 'RPC protocol ${capabilities.protocolVersion} is outside the '
                'supported range $minSupportedRpcProtocol–'
                '$maxSupportedRpcProtocol'
          : 'RPC method is not advertised by the connected handler',
      retryable: false,
      scope: capabilities.scope,
      method: method,
      minProtocol: minSupportedRpcProtocol,
    );
  }

  RpcException _offlineCapabilityError(String scopeId, String method) =>
      RpcException(
        code: RpcErrorCode.handlerOffline,
        message: 'RPC handler is offline',
        retryable: true,
        scope: scopeId,
        method: method,
      );

  /// Returns the live machine RPC manifest. Positive manifests are scoped to
  /// the socket generation; legacy and transient negatives have a bounded
  /// cross-generation TTL so reconnect loops cannot recreate probe storms.
  Future<RpcCapabilities?> machineCapabilities(String machineId) =>
      _capabilitiesFor(scope: 'machine', id: machineId);

  /// Returns the live session RPC manifest under the same bounded policy as
  /// [machineCapabilities].
  Future<RpcCapabilities?> sessionCapabilities(String sessionId) =>
      _capabilitiesFor(scope: 'session', id: sessionId);

  Future<RpcCapabilities?> _capabilitiesFor({
    required String scope,
    required String id,
  }) async {
    final scopeKey = '$scope:$id';
    final identityKey = _rpcCapabilityIdentity(scope, id);
    final cacheKey = _rpcCapabilityCacheKey(identityKey);
    _pruneRpcCapabilityManifests(scopeKey, cacheKey);
    final cached = _rpcCapabilitiesCache[cacheKey];
    if (cached != null) {
      _recordRpcCapabilityPolicy(scope, 'positive_cache');
      return cached;
    }

    final nowMs = _rpcCapabilityNowMs();
    _purgeExpiredRpcCapabilityNegatives(nowMs, currentIdentityKey: identityKey);
    final negativeUntil = _rpcCapabilityNegativeUntil[identityKey];
    if (negativeUntil != null) {
      if (negativeUntil > nowMs) {
        _recordRpcCapabilityPolicy(scope, 'negative_cache');
        return null;
      }
      _rpcCapabilityNegativeUntil.remove(identityKey);
    }

    if (_rpcCapabilityOwningMachineOffline(scope, id) ||
        (testRpcCapabilitiesOverride == null && !_isSocketConnected())) {
      _recordRpcCapabilityPolicy(scope, 'offline_short_circuit');
      return null;
    }

    final existing = _rpcCapabilityProbesInFlight[identityKey];
    if (existing != null) {
      _recordRpcCapabilityPolicy(scope, 'shared_in_flight');
      return existing;
    }

    final probe = _probeRpcCapabilities(
      scope: scope,
      id: id,
      scopeKey: scopeKey,
      identityKey: identityKey,
      cacheKey: cacheKey,
      policyEpoch: _rpcCapabilityPolicyEpoch,
    );
    _rpcCapabilityProbesInFlight[identityKey] = probe;
    try {
      return await probe;
    } finally {
      if (identical(_rpcCapabilityProbesInFlight[identityKey], probe)) {
        _rpcCapabilityProbesInFlight.remove(identityKey);
      }
    }
  }

  Future<RpcCapabilities?> _probeRpcCapabilities({
    required String scope,
    required String id,
    required String scopeKey,
    required String identityKey,
    required String cacheKey,
    required int policyEpoch,
  }) async {
    final timeout =
        testRpcCapabilityProbeTimeout ?? _defaultCapabilityProbeTimeout;
    _recordRpcCapabilityPolicy(scope, 'transport_started');
    try {
      final raw = await _invokeRpcCapabilityTransport(
        scope: scope,
        id: id,
        timeout: timeout,
      ).timeout(timeout);
      if (!_isRpcCapabilityProbeCurrent(scope, id, cacheKey, policyEpoch)) {
        _recordRpcCapabilityPolicy(scope, 'stale_result');
        return null;
      }
      if (raw is! Map) {
        _rememberRpcCapabilityNegative(
          identityKey,
          _RpcCapabilityNegativeKind.legacy,
        );
        _recordRpcCapabilityPolicy(scope, 'legacy_unknown');
        return null;
      }
      final capabilities = RpcCapabilities.tryFromJson(
        Map<String, dynamic>.from(raw),
      );
      if (capabilities == null) {
        _rememberRpcCapabilityNegative(
          identityKey,
          _RpcCapabilityNegativeKind.legacy,
        );
        _recordRpcCapabilityPolicy(scope, 'legacy_unknown');
        return null;
      }
      _clearRpcCapabilityNegatives(scopeKey);
      _rpcCapabilitiesCache
        ..removeWhere((key, _) => key.contains(':$scopeKey:'))
        ..[cacheKey] = capabilities;
      _recordRpcCapabilityPolicy(scope, 'manifest');
      return capabilities;
    } on RpcException catch (error) {
      if (!_isRpcCapabilityProbeCurrent(scope, id, cacheKey, policyEpoch)) {
        _recordRpcCapabilityPolicy(scope, 'stale_result');
        return null;
      }
      if (error.code == RpcErrorCode.methodUnsupported) {
        _rememberRpcCapabilityNegative(
          identityKey,
          _RpcCapabilityNegativeKind.legacy,
        );
        _recordRpcCapabilityPolicy(scope, 'legacy_unknown');
        return null;
      }
      if (!_isRpcCapabilityTransportFailure(error)) rethrow;
      return _handleRpcCapabilityTransportFailure(
        scope: scope,
        identityKey: identityKey,
        error: error,
      );
    } catch (error) {
      if (!_isRpcCapabilityProbeCurrent(scope, id, cacheKey, policyEpoch)) {
        _recordRpcCapabilityPolicy(scope, 'stale_result');
        return null;
      }
      if (!_isRpcCapabilityTransportFailure(error)) rethrow;
      return _handleRpcCapabilityTransportFailure(
        scope: scope,
        identityKey: identityKey,
        error: error,
      );
    }
  }

  Future<dynamic> _invokeRpcCapabilityTransport({
    required String scope,
    required String id,
    required Duration timeout,
  }) {
    final override = testRpcCapabilitiesOverride;
    if (override != null) {
      return override(scope, id, timeout);
    }
    if (scope == 'machine') {
      return machineRPC(
        id,
        'rpc-capabilities',
        const <String, dynamic>{},
        timeout: timeout,
      );
    }
    return sessionRPC(
      id,
      'rpc-capabilities',
      const <String, dynamic>{},
      timeout: timeout,
    );
  }

  RpcCapabilities? _handleRpcCapabilityTransportFailure({
    required String scope,
    required String identityKey,
    required Object error,
  }) {
    _rememberRpcCapabilityNegative(
      identityKey,
      _RpcCapabilityNegativeKind.transient,
    );
    _recordRpcCapabilityPolicy(scope, 'transport_backoff');
    logger.info(
      '[rpc-capabilities] transient probe failure; '
      'scope=$scope backoff=active error=${error.runtimeType}',
    );
    // Capability discovery is advisory. Falling back to optimistic legacy
    // semantics lets the requested feature RPC provide the authoritative
    // result instead of failing solely because its pre-flight probe timed out.
    return null;
  }

  bool _isRpcCapabilityTransportFailure(Object error) {
    if (error is TimeoutException ||
        error is SocketAckTimeoutException ||
        error is SocketNotConnectedException) {
      return true;
    }
    if (error is RpcException) {
      return error.retryable ||
          error.code == RpcErrorCode.handlerOffline ||
          error.code == RpcErrorCode.forwardingFailed;
    }
    return Sync._isTransientRpcError(error);
  }

  void _rememberRpcCapabilityNegative(
    String identityKey,
    _RpcCapabilityNegativeKind kind,
  ) {
    final nowMs = _rpcCapabilityNowMs();
    late final int ttlMs;
    if (kind == _RpcCapabilityNegativeKind.legacy) {
      ttlMs = (testRpcCapabilityLegacyTtl ?? _defaultCapabilityLegacyTtl)
          .inMilliseconds;
      _rpcCapabilityFailureCount.remove(identityKey);
    } else {
      final failures = (_rpcCapabilityFailureCount[identityKey] ?? 0) + 1;
      _rpcCapabilityFailureCount[identityKey] = failures;
      final baseMs =
          (testRpcCapabilityTransientBackoffBase ??
                  _defaultCapabilityTransientBackoffBase)
              .inMilliseconds;
      final multiplier = 1 << min(failures - 1, 4);
      ttlMs = min(
        baseMs * multiplier,
        _maxCapabilityTransientBackoff.inMilliseconds,
      );
    }
    _rpcCapabilityNegativeUntil[identityKey] = nowMs + ttlMs;
  }

  void _clearRpcCapabilityNegatives(String scopeKey) {
    _rpcCapabilityNegativeUntil.removeWhere(
      (key, _) => key.startsWith('$scopeKey:'),
    );
    _rpcCapabilityFailureCount.removeWhere(
      (key, _) => key.startsWith('$scopeKey:'),
    );
  }

  void _purgeExpiredRpcCapabilityNegatives(
    int nowMs, {
    required String currentIdentityKey,
  }) {
    final expiredKeys = _rpcCapabilityNegativeUntil.entries
        .where(
          (entry) => entry.key != currentIdentityKey && entry.value <= nowMs,
        )
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in expiredKeys) {
      _rpcCapabilityNegativeUntil.remove(key);
      _rpcCapabilityFailureCount.remove(key);
    }
  }

  void _pruneRpcCapabilityManifests(String scopeKey, String currentCacheKey) {
    _rpcCapabilitiesCache.removeWhere(
      (key, _) => key != currentCacheKey && key.contains(':$scopeKey:'),
    );
  }

  String _rpcCapabilityCacheKey(String identityKey) =>
      '${socketIoClient.connectionGeneration}:$identityKey';

  bool _isRpcCapabilityProbeCurrent(
    String scope,
    String id,
    String cacheKey,
    int policyEpoch,
  ) =>
      policyEpoch == _rpcCapabilityPolicyEpoch &&
      !_rpcCapabilityOwningMachineOffline(scope, id) &&
      _rpcCapabilityCacheKey(_rpcCapabilityIdentity(scope, id)) == cacheKey;

  void _clearRpcCapabilityPolicyState() {
    _rpcCapabilityPolicyEpoch++;
    _rpcCapabilitiesCache.clear();
    _rpcCapabilityProbesInFlight.clear();
    _rpcCapabilityNegativeUntil.clear();
    _rpcCapabilityFailureCount.clear();
  }

  String _rpcCapabilityIdentity(String scope, String id) {
    if (scope == 'machine') {
      return '$scope:$id:${_rpcCapabilityMachineVersion(id)}';
    }
    final session = _sessions[id];
    final machineId = session?.metadata?.machineId;
    final version = machineId == null || machineId.isEmpty
        ? _rpcCapabilityVersion(session?.metadata?.version)
        : _rpcCapabilityMachineVersion(machineId);
    return '$scope:$id:$version';
  }

  String _rpcCapabilityMachineVersion(String machineId) {
    final machine = _machines[machineId];
    return _rpcCapabilityVersion(machine?.metadata?.happyCliVersion);
  }

  String _rpcCapabilityVersion(String? value) {
    final version = value?.trim();
    return version == null || version.isEmpty ? 'unknown' : version;
  }

  bool _rpcCapabilityOwningMachineOffline(String scope, String id) {
    if (scope == 'machine') {
      final machine = _machines[id];
      return machine != null && !machine.isOnline;
    }
    final session = _sessions[id];
    if (session == null) return false;
    final machineId = session.metadata?.machineId;
    if (machineId != null && machineId.isNotEmpty) {
      final machine = _machines[machineId];
      if (machine != null && !machine.isOnline) return true;
    }
    return false;
  }

  int _rpcCapabilityNowMs() =>
      testRpcCapabilityNowMs?.call() ?? DateTime.now().millisecondsSinceEpoch;

  void _recordRpcCapabilityPolicy(String scope, String outcome) {
    OpenTelemetryService().recordCount(
      'app.rpc_capability_probe',
      attributes: <String, Object?>{'scope': scope, 'outcome': outcome},
      description: 'RPC capability discovery policy outcomes',
    );
  }

  Future<bool?> machineSupportsRPC(String machineId, String method) async =>
      (await machineCapabilities(machineId))?.supports(method);

  Future<bool?> sessionSupportsRPC(String sessionId, String method) async =>
      (await sessionCapabilities(sessionId))?.supports(method);

  /// Enforces a machine manifest when present. Legacy daemons and temporarily
  /// unreachable capability handlers remain optimistic for compatibility.
  Future<void> ensureMachineRPCSupported(
    String machineId,
    String method,
  ) async {
    if (_rpcCapabilityOwningMachineOffline('machine', machineId)) {
      throw _offlineCapabilityError(machineId, method);
    }
    final capabilities = await machineCapabilities(machineId);
    if (capabilities == null) return;
    if (!capabilities.supports(method)) {
      throw _unsupportedCapabilityError(capabilities, method);
    }
  }

  /// Session-scoped counterpart to [ensureMachineRPCSupported].
  Future<void> ensureSessionRPCSupported(
    String sessionId,
    String method,
  ) async {
    if (_rpcCapabilityOwningMachineOffline('session', sessionId)) {
      throw _offlineCapabilityError(sessionId, method);
    }
    final capabilities = await sessionCapabilities(sessionId);
    if (capabilities == null) return;
    if (!capabilities.supports(method)) {
      throw _unsupportedCapabilityError(capabilities, method);
    }
  }
}
