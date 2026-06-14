import 'package:riverpod/riverpod.dart';

import '../models/machine.dart';
import '../rpc/rpc_types.dart' show
    BashResponse, CodexModelsResponse, ReadFileResponse;
import '../services/sync_service.dart' show sync;
import '../sync/machine_manager.dart';

/// Repository layer for machines. Wraps [MachineManager] and provides
/// the public surface used by notifiers and screens.
class MachinesRepository {
  const MachinesRepository(this._manager);

  final MachineManager _manager;

  /// All machines currently held in memory.
  Map<String, Machine> get machines => _manager.machines;

  /// Refreshes the machine catalog.
  void refreshMachines() => _manager.scheduleMachinesRefresh();

  /// Runs a bash command on [machineId].
  Future<BashResponse> machineBash({
    required String machineId,
    required String command,
    required String cwd,
  }) =>
      _manager.machineBash(
        machineId: machineId,
        command: command,
        cwd: cwd,
      );

  /// Reads a file from [machineId] at [filePath].
  Future<ReadFileResponse> machineReadFile({
    required String machineId,
    required String filePath,
  }) =>
      _manager.machineReadFile(
        machineId: machineId,
        filePath: filePath,
      );

  /// Creates a new session on [machineId].
  Future<String> createSession({
    required String machineId,
    required String path,
    required String agent,
    String? profileId,
    String? modelMode,
  }) =>
      _manager.createSession(
        machineId: machineId,
        path: path,
        agent: agent,
        profileId: profileId,
        modelMode: modelMode,
      );

  /// Creates a git worktree on [machineId] under [basePath].
  Future<String> createWorktree({
    required String machineId,
    required String basePath,
  }) =>
      _manager.createWorktree(
        machineId: machineId,
        basePath: basePath,
      );

  /// Fetches the Codex model catalog from [machineId].
  Future<CodexModelsResponse> machineGetCodexModels({
    required String machineId,
  }) =>
      _manager.machineGetCodexModels(machineId: machineId);
}

/// Provider for the machine manager managed by the sync singleton.
final machineManagerProvider = Provider<MachineManager>(
  (ref) => sync.machineManager!,
);

/// Provider for the machines repository.
final machinesRepositoryProvider = Provider<MachinesRepository>(
  (ref) => MachinesRepository(ref.read(machineManagerProvider)),
);
