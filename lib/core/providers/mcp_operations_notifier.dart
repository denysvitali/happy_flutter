/// App-local MCP server operations (enable, disable, remove) on a machine's
/// config, synced to the daemon in the background on the shared
/// [OperationStore] machine.
///
/// The servers screen draws [applyMcpOperations] over its last snapshot, so a
/// switch flips (or a removed server leaves) the moment the user acts. The
/// daemon answers with a full config snapshot, which the screen adopts; a
/// failure drops the overlay and is reported app-wide.
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod/riverpod.dart';

import '../models/mcp_server.dart';
import '../operations/operation_store.dart';
import '../services/sync_service.dart';

enum McpOperationAction { enable, disable, remove }

@immutable
class McpRequest {
  const McpRequest({
    required this.machineId,
    required this.server,
    required this.action,
    this.projectDir,
  });

  final String machineId;
  final McpServer server;
  final McpOperationAction action;

  /// Project the screen had selected; used when the server has none.
  final String? projectDir;
}

typedef McpOperation = Operation<McpRequest>;

String mcpOperationKey(String machineId, McpServer server) =>
    '$machineId|${server.identity}';

/// A refused MCP change; keeps the daemon's response for localization.
class McpOperationFailed implements Exception {
  const McpOperationFailed(this.response);
  final McpConfigResponse response;
  @override
  String toString() => 'MCP change refused (${response.failureKind})';
}

extension McpOperationView on McpOperation {
  /// The daemon's config snapshot after a successful change.
  McpConfigResponse? get snapshot => switch (result) {
    final McpConfigResponse response => response,
    _ => null,
  };
}

/// Sends an MCP change; override in tests.
typedef McpChangeRunner = Future<McpConfigResponse> Function(McpRequest);

Future<McpConfigResponse> _runViaSync(McpRequest request) {
  final projectDir = request.server.projectDir ?? request.projectDir;
  return switch (request.action) {
    McpOperationAction.remove => Sync().machineRemoveMcpServer(
      machineId: request.machineId,
      scope: request.server.scope,
      name: request.server.name,
      projectDir: projectDir,
    ),
    _ => Sync().machineToggleMcpServer(
      machineId: request.machineId,
      scope: request.server.scope,
      name: request.server.name,
      enabled: request.action == McpOperationAction.enable,
      projectDir: projectDir,
    ),
  };
}

final mcpChangeRunnerProvider = Provider<McpChangeRunner>((ref) => _runViaSync);

class McpOperationsNotifier extends OperationStore<McpRequest> {
  @override
  String get logName => 'MCP';

  @override
  String keyOf(McpRequest request) =>
      mcpOperationKey(request.machineId, request.server);

  @override
  Future<Object?> perform(McpRequest request) async {
    final response = await ref.read(mcpChangeRunnerProvider)(request);
    if (!response.success) throw McpOperationFailed(response);
    return response;
  }
}

/// MCP changes made this app session, keyed by `machineId|serverIdentity`.
final mcpOperationsNotifierProvider =
    NotifierProvider<McpOperationsNotifier, Map<String, McpOperation>>(
      McpOperationsNotifier.new,
    );

/// [servers] as they will be once in-flight changes on [machineId] apply.
List<McpServer> applyMcpOperations(
  String machineId,
  List<McpServer> servers,
  Map<String, McpOperation> operations,
) {
  if (operations.isEmpty) return servers;
  final result = <McpServer>[];
  for (final server in servers) {
    final operation = operations[mcpOperationKey(machineId, server)];
    if (operation == null || !operation.isPending) {
      result.add(server);
      continue;
    }
    switch (operation.request.action) {
      case McpOperationAction.remove:
        break;
      case McpOperationAction.enable:
        result.add(server.enabled ? server : server.copyWith(enabled: true));
      case McpOperationAction.disable:
        result.add(server.enabled ? server.copyWith(enabled: false) : server);
    }
  }
  return result;
}
