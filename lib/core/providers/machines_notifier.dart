import 'package:riverpod/riverpod.dart';

import '../models/machine.dart';
import '../rpc/rpc_types.dart' show BashResponse, ReadFileResponse;
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';
import '_shared.dart';

class MachinesNotifier extends Notifier<Map<String, Machine>> {
  int _lastDataChangeCounter = -1;
  Future<void>? _refreshInFlight;

  @override
  Map<String, Machine> build() => {};

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.domainChangeCounter(SyncDomain.machines);
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.machines;
    if (mapValuesIdentical(state, next)) return;
    state = Map<String, Machine>.from(next);
  }

  Future<void> refreshFromSync() {
    if (!sync.isInitialized) {
      return Future<void>.value();
    }
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = () async {
      try {
        await sync.refreshMachines();
      } catch (e, stack) {
        logger.warning('Failed to refresh machines', e, stack);
      }
      loadFromSync();
    }().whenComplete(() {
      _refreshInFlight = null;
    });
    _refreshInFlight = future;
    return future;
  }

  void remove(String machineId) {
    if (!state.containsKey(machineId)) {
      return;
    }
    state = Map<String, Machine>.from(state)..remove(machineId);
  }

  void clear() {
    state = {};
  }

  /// Runs a bash command on [machineId].
  Future<BashResponse> bash({
    required String machineId,
    required String command,
    required String cwd,
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    try {
      return await sync.machineBash(
        machineId: machineId,
        command: command,
        cwd: cwd,
      );
    } catch (e, stack) {
      logger.warning(
        'MachinesNotifier.bash($machineId, $command) failed',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Reads a file from [machineId] at [filePath].
  Future<ReadFileResponse> readFile({
    required String machineId,
    required String filePath,
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    try {
      return await sync.machineReadFile(
        machineId: machineId,
        filePath: filePath,
      );
    } catch (e, stack) {
      logger.warning(
        'MachinesNotifier.readFile($machineId, $filePath) failed',
        e,
        stack,
      );
      rethrow;
    }
  }
}

final machinesNotifierProvider =
    NotifierProvider<MachinesNotifier, Map<String, Machine>>(() {
      return MachinesNotifier();
    });
