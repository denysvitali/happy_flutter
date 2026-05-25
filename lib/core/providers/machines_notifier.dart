import 'package:riverpod/riverpod.dart';

import '../models/machine.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

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
    // Fast path: check length first, then use identical() for each value
    if (state.length == next.length) {
      var changed = false;
      next.forEach((key, value) {
        if (!identical(state[key], value)) {
          changed = true;
        }
      });
      if (!changed) return;
    }
    state = Map<String, Machine>.from(next);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    try {
      final future = sync.refreshMachines().then((_) {
        loadFromSync();
      }).catchError((e, stack) {
        logger.warning('Failed to refresh machines', e, stack);
      }).whenComplete(() {
        _refreshInFlight = null;
      });
      _refreshInFlight = future;
      await future;
    } catch (e, stack) {
      logger.warning('Failed to refresh machines', e, stack);
      _refreshInFlight = null;
    }
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
}

final machinesNotifierProvider =
    NotifierProvider<MachinesNotifier, Map<String, Machine>>(() {
      return MachinesNotifier();
    });
