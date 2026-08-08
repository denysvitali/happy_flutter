part of 'sync_service.dart';

/// Remote management of a machine's per-project sandbox policy.
///
/// The daemon wraps every session it spawns in boxy, which gives the agent
/// its project directory and the public internet and nothing else. These RPCs
/// are how the app widens that — "this project also needs ~/go/pkg/mod" — or
/// turns it off for a project that cannot work inside it.
///
/// Failures come back as an unsuccessful [SandboxPolicyResponse] rather than
/// as an exception: a machine that is offline or running a daemon from before
/// the feature existed is an expected state for this screen, not a crash.
extension SyncSandboxOperations on Sync {
  /// List every project on [machineId] that has a stored policy, along with
  /// the machine's sandbox capability.
  Future<SandboxPolicyResponse> machineListSandboxPolicies({
    required String machineId,
  }) => _sandboxRpc(
    machineId: machineId,
    method: 'sandbox-list',
    params: const <String, dynamic>{},
    label: 'machineListSandboxPolicies',
  );

  /// Read one project's policy. A project that has never been configured
  /// comes back with no grants and `effectiveEnabled` from the machine
  /// default, which is what the editor should show.
  Future<SandboxPolicyResponse> machineGetSandboxPolicy({
    required String machineId,
    required String directory,
  }) => _sandboxRpc(
    machineId: machineId,
    method: 'sandbox-get',
    params: <String, dynamic>{'directory': directory},
    label: 'machineGetSandboxPolicy',
  );

  /// Replace one project's policy.
  ///
  /// [grants] is authoritative: send the full list being shown, because a
  /// directory left out of it is revoked. [enabled] is tri-state — null puts
  /// the project back on the machine default rather than pinning it.
  Future<SandboxPolicyResponse> machineSetSandboxPolicy({
    required String machineId,
    required String directory,
    required List<SandboxGrant> grants,
    bool? enabled,
    List<String> allowHosts = const [],
  }) => _sandboxRpc(
    machineId: machineId,
    method: 'sandbox-set',
    params: <String, dynamic>{
      'directory': directory,
      'enabled': enabled,
      'grants': grants.map((g) => g.toJson()).toList(),
      'allowHosts': allowHosts,
    },
    label: 'machineSetSandboxPolicy',
    timeout: const Duration(seconds: 20),
  );

  /// Shared transport + error mapping for the sandbox RPCs.
  Future<SandboxPolicyResponse> _sandboxRpc({
    required String machineId,
    required String method,
    required Map<String, dynamic> params,
    required String label,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final supported = testMachineRPCOverride == null
          ? await machineSupportsRPC(machineId, method)
          : null;
      if (supported == false) {
        return const SandboxPolicyResponse(
          success: false,
          error: 'Sandbox management requires a newer machine agent',
          failureKind: RemoteFeatureFailureKind.unsupported,
        );
      }
      return await _typedMachineRPC(
        machineId,
        method,
        params,
        SandboxPolicyResponse.fromJson,
        timeout: timeout,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('$label: machine offline');
        return const SandboxPolicyResponse(
          success: false,
          error: 'machine offline',
          failureKind: RemoteFeatureFailureKind.offline,
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info('$label: RPC method not available (daemon too old)');
        return const SandboxPolicyResponse(
          success: false,
          error: 'Sandbox management requires a newer machine agent',
          failureKind: RemoteFeatureFailureKind.unsupported,
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('$label: transient RPC failure — $error');
        return const SandboxPolicyResponse(
          success: false,
          error: 'transient RPC failure',
          failureKind: RemoteFeatureFailureKind.transient,
        );
      } else {
        logger.error('$label error', error, stackTrace);
      }
    }
    return const SandboxPolicyResponse(
      success: false,
      error: 'RPC call failed',
      failureKind: RemoteFeatureFailureKind.unknown,
    );
  }
}
