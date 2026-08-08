/// RPC manifest versions this app can interpret without guessing semantics.
const int minSupportedRpcProtocol = 2;
const int maxSupportedRpcProtocol = 2;

enum RpcCapabilityStatus {
  supported,
  methodUnsupported,
  protocolTooOld,
  protocolTooNew,
}

/// Capability manifest reported by the live RPC handler map.
class RpcCapabilities {
  const RpcCapabilities({
    required this.protocolVersion,
    required this.scope,
    required this.methods,
  });

  factory RpcCapabilities.fromJson(Map<String, dynamic> json) {
    final rawMethods = json['methods'];
    return RpcCapabilities(
      protocolVersion: (json['protocolVersion'] as num?)?.toInt() ?? 1,
      scope: json['scope']?.toString() ?? '',
      methods: rawMethods is List
          ? Set<String>.unmodifiable(rawMethods.whereType<String>())
          : const <String>{},
    );
  }

  static RpcCapabilities? tryFromJson(Map<String, dynamic> json) {
    final protocol = json['protocolVersion'];
    if (protocol is! num || json['methods'] is! List) return null;
    return RpcCapabilities.fromJson(json);
  }

  final int protocolVersion;
  final String scope;
  final Set<String> methods;

  RpcCapabilityStatus statusFor(String method) {
    if (protocolVersion < minSupportedRpcProtocol) {
      return RpcCapabilityStatus.protocolTooOld;
    }
    if (protocolVersion > maxSupportedRpcProtocol) {
      return RpcCapabilityStatus.protocolTooNew;
    }
    return methods.contains(method)
        ? RpcCapabilityStatus.supported
        : RpcCapabilityStatus.methodUnsupported;
  }

  bool supports(String method) =>
      statusFor(method) == RpcCapabilityStatus.supported;
}
