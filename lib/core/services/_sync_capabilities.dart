part of 'sync_service.dart';

extension SyncCapabilities on Sync {
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

  /// Returns the live machine RPC manifest, cached only for this socket
  /// generation. Old daemons return `null`, which means unknown/optimistic
  /// compatibility rather than unsupported.
  Future<RpcCapabilities?> machineCapabilities(String machineId) async {
    final key = '${socketIoClient.connectionGeneration}:machine:$machineId';
    if (_rpcCapabilitiesCache.containsKey(key)) {
      return _rpcCapabilitiesCache[key];
    }
    try {
      final raw = await machineRPC(
        machineId,
        'rpc-capabilities',
        const <String, dynamic>{},
      );
      if (raw is! Map) {
        _rpcCapabilitiesCache[key] = null;
        return null;
      }
      final capabilities = RpcCapabilities.tryFromJson(
        Map<String, dynamic>.from(raw),
      );
      if (capabilities == null) {
        _rpcCapabilitiesCache[key] = null;
        return null;
      }
      _rpcCapabilitiesCache
        ..removeWhere((cacheKey, _) => cacheKey.endsWith(':machine:$machineId'))
        ..[key] = capabilities;
      return capabilities;
    } on RpcException catch (error) {
      if (error.code == RpcErrorCode.methodUnsupported) {
        _rpcCapabilitiesCache[key] = null;
        return null;
      }
      rethrow;
    }
  }

  /// Returns the live session RPC manifest for feature gating.
  Future<RpcCapabilities?> sessionCapabilities(String sessionId) async {
    final key = '${socketIoClient.connectionGeneration}:session:$sessionId';
    if (_rpcCapabilitiesCache.containsKey(key)) {
      return _rpcCapabilitiesCache[key];
    }
    try {
      final raw = await sessionRPC(
        sessionId,
        'rpc-capabilities',
        const <String, dynamic>{},
      );
      if (raw is! Map) {
        _rpcCapabilitiesCache[key] = null;
        return null;
      }
      final capabilities = RpcCapabilities.tryFromJson(
        Map<String, dynamic>.from(raw),
      );
      if (capabilities == null) {
        _rpcCapabilitiesCache[key] = null;
        return null;
      }
      _rpcCapabilitiesCache
        ..removeWhere((cacheKey, _) => cacheKey.endsWith(':session:$sessionId'))
        ..[key] = capabilities;
      return capabilities;
    } on RpcException catch (error) {
      if (error.code == RpcErrorCode.methodUnsupported) {
        _rpcCapabilitiesCache[key] = null;
        return null;
      }
      rethrow;
    }
  }

  Future<bool?> machineSupportsRPC(String machineId, String method) async =>
      (await machineCapabilities(machineId))?.supports(method);

  Future<bool?> sessionSupportsRPC(String sessionId, String method) async =>
      (await sessionCapabilities(sessionId))?.supports(method);

  /// Enforces a machine manifest when present. Legacy daemons have no
  /// manifest and remain optimistic so existing installations keep working.
  Future<void> ensureMachineRPCSupported(
    String machineId,
    String method,
  ) async {
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
    final capabilities = await sessionCapabilities(sessionId);
    if (capabilities == null) return;
    if (!capabilities.supports(method)) {
      throw _unsupportedCapabilityError(capabilities, method);
    }
  }
}
