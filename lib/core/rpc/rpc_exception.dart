/// Stable RPC failure categories shared by machine and session calls.
enum RpcErrorCode {
  methodUnsupported('method_unsupported'),
  protocolUnsupported('protocol_unsupported'),
  handlerOffline('handler_offline'),
  invalidRequest('invalid_request'),
  handlerError('handler_error'),
  forwardingFailed('forwarding_failed'),
  unknown('unknown');

  const RpcErrorCode(this.wireValue);

  final String wireValue;

  static RpcErrorCode fromWire(String? value) {
    for (final code in values) {
      if (code.wireValue == value) return code;
    }
    return unknown;
  }
}

/// A structured RPC failure that callers can handle without parsing prose.
class RpcException implements Exception {
  const RpcException({
    required this.code,
    required this.message,
    required this.retryable,
    this.scope,
    this.method,
    this.minProtocol,
  });

  factory RpcException.fromWire(
    Map<dynamic, dynamic> wire, {
    String? fallbackMethod,
  }) {
    final message =
        wire['error']?.toString() ??
        wire['message']?.toString() ??
        'RPC failed';
    var code = RpcErrorCode.fromWire(wire['code']?.toString());
    var retryable = wire['retryable'] == true;

    // Older relays only sent prose. Centralize the compatibility mapping here
    // so feature code never grows its own subtly different substring parser.
    if (code == RpcErrorCode.unknown) {
      final normalized = message.toLowerCase();
      if (normalized.contains('not registered on any reachable') ||
          normalized.contains('handler offline')) {
        code = RpcErrorCode.handlerOffline;
        retryable = true;
      } else if (normalized.contains('method not found') ||
          normalized.contains('method not available') ||
          normalized.contains('unknown method')) {
        code = RpcErrorCode.methodUnsupported;
      } else if (normalized.contains('invalid parameter') ||
          normalized.contains('invalid request')) {
        code = RpcErrorCode.invalidRequest;
      }
    }

    final minProtocolRaw = wire['minProtocol'];
    return RpcException(
      code: code,
      message: message,
      retryable: retryable,
      scope: wire['scope']?.toString(),
      method: wire['method']?.toString() ?? fallbackMethod,
      minProtocol: minProtocolRaw is num
          ? minProtocolRaw.toInt()
          : int.tryParse(minProtocolRaw?.toString() ?? ''),
    );
  }

  final RpcErrorCode code;
  final String message;
  final bool retryable;
  final String? scope;
  final String? method;
  final int? minProtocol;

  @override
  String toString() => 'RpcException(${code.wireValue}, $message)';
}
