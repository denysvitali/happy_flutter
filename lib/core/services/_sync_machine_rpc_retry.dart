part of 'sync_service.dart';

extension SyncMachineRpcRetry on Sync {
  /// Only explicit idempotent operations opt into replay. Spawn and generic
  /// Bash calls must never be retried automatically after an uncertain ACK.
  Future<T> _retryIdempotentMachineRPC<T>(
    String machineId,
    String method,
    Map<String, dynamic> params,
    T Function(Map<String, dynamic>) decode, {
    required Duration timeout,
  }) async {
    final generation = _runtimeGeneration;
    final clock = Stopwatch()..start();
    for (var attempt = 0; ; attempt++) {
      if (generation != _runtimeGeneration) {
        throw StateError('Machine RPC runtime changed');
      }
      final remaining = timeout - clock.elapsed;
      if (remaining <= Duration.zero) {
        throw const SocketAckTimeoutException('rpc-call');
      }
      try {
        return await _typedMachineRPC(
          machineId,
          method,
          params,
          decode,
          timeout: remaining,
        );
      } on RpcException catch (error) {
        if (attempt >= 1 ||
            !error.retryable ||
            (error.code != RpcErrorCode.handlerOffline &&
                error.code != RpcErrorCode.forwardingFailed)) {
          rethrow;
        }
        final delay = const Duration(milliseconds: 500);
        if (clock.elapsed + delay >= timeout) rethrow;
        await Future<void>.delayed(delay);
      }
    }
  }
}
