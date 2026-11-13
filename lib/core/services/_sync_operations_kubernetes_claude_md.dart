part of 'sync_service.dart';

/// Per-machine user instructions for newly created Kubernetes Pods.
extension SyncKubernetesClaudeMdOperations on Sync {
  static const Duration _claudeMdTimeout = Duration(seconds: 15);

  Future<KubernetesClaudeMdResponse> machineGetKubernetesClaudeMd({
    required String machineId,
  }) => _retryIdempotentMachineRPC(
    machineId,
    'kubernetes-claude-md-get',
    const <String, dynamic>{},
    KubernetesClaudeMdResponse.fromJson,
    timeout: _claudeMdTimeout,
  );

  /// An empty string clears the instructions. Do not trim Markdown content.
  /// Repeating an identical replacement is safe after a routing failure.
  Future<KubernetesClaudeMdResponse> machineSetKubernetesClaudeMd({
    required String machineId,
    required String content,
  }) => _retryIdempotentMachineRPC(
    machineId,
    'kubernetes-claude-md-set',
    <String, dynamic>{'content': content},
    KubernetesClaudeMdResponse.fromJson,
    timeout: _claudeMdTimeout,
  );
}
