part of 'sync_service.dart';

/// Remote management of a machine's Claude Code MCP servers.
///
/// The daemon owns the files (`~/.claude.json`, `<project>/.mcp.json`,
/// `settings*.json`); these RPCs are the only way the app touches them. Every
/// mutation returns the fresh snapshot, so callers replace their state from
/// the response instead of issuing a follow-up list.
///
/// Failures are surfaced as an unsuccessful [McpConfigResponse] rather than an
/// exception: a machine that is offline, running an older daemon, or rejecting
/// a bad server definition is an expected UI state, not a crash.
extension SyncMcpOperations on Sync {
  /// Read the merged MCP configuration from [machineId].
  ///
  /// [projectDir] scopes the read: omitted (or empty) returns the machine-wide
  /// scopes plus the list of known project directories; a directory adds that
  /// project's `local`, `project`, and settings-file scopes.
  Future<McpConfigResponse> machineListMcpServers({
    required String machineId,
    String? projectDir,
  }) => _mcpRpc(
    machineId: machineId,
    method: 'mcp-list',
    params: <String, dynamic>{
      if (projectDir != null && projectDir.isNotEmpty) 'projectDir': projectDir,
    },
    label: 'machineListMcpServers',
  );

  /// Create or replace one server declaration.
  ///
  /// The daemon replaces the known keys wholesale (so clearing `args` really
  /// clears them) while preserving keys it does not manage, such as `timeout`.
  Future<McpConfigResponse> machineSetMcpServer({
    required String machineId,
    required McpServerScope scope,
    required String name,
    required McpTransport transport,
    String? projectDir,
    String? command,
    List<String> args = const [],
    Map<String, String> env = const {},
    String? url,
    Map<String, String> headers = const {},
  }) => _mcpRpc(
    machineId: machineId,
    method: 'mcp-set',
    params: <String, dynamic>{
      'scope': scope.wire,
      'name': name,
      'transport': transport.wire,
      if (projectDir != null && projectDir.isNotEmpty) 'projectDir': projectDir,
      if (transport == McpTransport.stdio) ...<String, dynamic>{
        'command': command ?? '',
        'args': args,
        'env': env,
      } else ...<String, dynamic>{
        'url': url ?? '',
        'headers': headers,
      },
    },
    label: 'machineSetMcpServer',
    // Config writes are quick, but they read-modify-write ~/.claude.json,
    // which can be tens of megabytes on a long-lived machine.
    timeout: const Duration(seconds: 20),
  );

  /// Delete one server declaration from its scope.
  Future<McpConfigResponse> machineRemoveMcpServer({
    required String machineId,
    required McpServerScope scope,
    required String name,
    String? projectDir,
  }) => _mcpRpc(
    machineId: machineId,
    method: 'mcp-remove',
    params: <String, dynamic>{
      'scope': scope.wire,
      'name': name,
      if (projectDir != null && projectDir.isNotEmpty) 'projectDir': projectDir,
    },
    label: 'machineRemoveMcpServer',
    timeout: const Duration(seconds: 20),
  );

  /// Enable or disable one server.
  ///
  /// For `project` scope this writes Claude's own approval lists and leaves the
  /// shared `.mcp.json` untouched. For every other scope the daemon parks the
  /// declaration in its own sidecar file and restores it on enable.
  Future<McpConfigResponse> machineToggleMcpServer({
    required String machineId,
    required McpServerScope scope,
    required String name,
    required bool enabled,
    String? projectDir,
  }) => _mcpRpc(
    machineId: machineId,
    method: 'mcp-toggle',
    params: <String, dynamic>{
      'scope': scope.wire,
      'name': name,
      'enabled': enabled,
      if (projectDir != null && projectDir.isNotEmpty) 'projectDir': projectDir,
    },
    label: 'machineToggleMcpServer',
    timeout: const Duration(seconds: 20),
  );

  /// Shared transport + error mapping for the MCP RPCs.
  Future<McpConfigResponse> _mcpRpc({
    required String machineId,
    required String method,
    required Map<String, dynamic> params,
    required String label,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        method,
        params,
        McpConfigResponse.fromJson,
        timeout: timeout,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('$label: machine offline');
        return const McpConfigResponse(
          success: false,
          error: 'machine offline',
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info('$label: RPC method not available (daemon too old)');
        return const McpConfigResponse(
          success: false,
          error: 'MCP management requires a newer machine agent',
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('$label: transient RPC failure — $error');
      } else {
        logger.error('$label error', error, stackTrace);
      }
    }
    return const McpConfigResponse(success: false, error: 'RPC call failed');
  }
}
