import 'package:riverpod/riverpod.dart';

import '../models/loop.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';
import 'machines_notifier.dart';

/// Goal loops across every known machine.
///
/// Unlike [LoopsNotifier], this holds no cache of its own: the daemon
/// mirrors its loop list into the machine's `daemonState`, which the app
/// already receives and persists on the machines channel. So the state here
/// is a projection, recomputed whenever the machines domain changes — there
/// is no separate refresh to get wrong, and a loop's progress updates on
/// screen as soon as the daemon publishes it.
class GoalLoopsNotifier extends Notifier<List<Loop>> {
  @override
  List<Loop> build() {
    // Machines carry the loop list, so watching them is the whole
    // subscription: every daemonState publish rebuilds this projection.
    ref.watch(machinesNotifierProvider);
    return _read();
  }

  List<Loop> _read() => sync.isInitialized ? sync.goalLoops : const <Loop>[];

  /// Recompute from sync state. Cheap — it walks the machine map.
  void loadFromSync() {
    final next = _read();
    if (_listsEqual(state, next)) return;
    state = next;
  }

  /// The goal loops owned by [machineId], newest first.
  List<Loop> forMachine(String machineId) =>
      state.where((l) => l.machineId == machineId).toList(growable: false);

  /// Loops that are still working towards their goal.
  List<Loop> get active => state.where((l) => !l.isTerminal).toList();

  /// Loops that stopped — reached, blocked, stalled, or out of iterations.
  List<Loop> get finished => state.where((l) => l.isTerminal).toList();

  /// Start a goal loop. Returns the daemon's response so the caller can
  /// surface the error text rather than a generic failure.
  Future<MachineLoopResponse> create({
    required String machineId,
    required String goal,
    required String directory,
    String? agent,
    String? model,
    String? permissionMode,
    String? progressFile,
    int? maxIterations,
    String? extraInstructions,
  }) async {
    final res = await sync.createGoalLoop(
      machineId: machineId,
      goal: goal,
      directory: directory,
      agent: agent,
      model: model,
      permissionMode: permissionMode,
      progressFile: progressFile,
      maxIterations: maxIterations,
      extraInstructions: extraInstructions,
    );
    if (res.success && res.loop != null) {
      // Show it immediately rather than waiting for the daemon's next
      // daemonState publish, which can lag the RPC ack by seconds.
      final created = res.loop!.machineId.isEmpty
          ? res.loop!.copyWith(machineId: machineId)
          : res.loop!;
      if (!state.any((l) => l.id == created.id)) {
        state = <Loop>[created, ...state];
      }
    } else {
      logger.warning('[goal-loops] create failed: ${res.error}');
    }
    return res;
  }

  Future<MachineLoopResponse> delete({
    required String machineId,
    required String loopId,
  }) async {
    // Optimistic: drop it now so the list responds to the tap. A later
    // daemonState publish is authoritative either way.
    state = state.where((l) => l.id != loopId).toList(growable: false);
    final res = await sync.deleteMachineLoop(
      machineId: machineId,
      loopId: loopId,
    );
    if (!res.success) {
      logger.warning('[goal-loops] delete failed: ${res.error}');
      loadFromSync();
    }
    return res;
  }

  Future<MachineLoopResponse> setPaused({
    required String machineId,
    required String loopId,
    required bool paused,
  }) async {
    _patch(loopId, (l) => l.copyWith(paused: paused));
    final res = await sync.pauseMachineLoop(
      machineId: machineId,
      loopId: loopId,
      paused: paused,
    );
    if (!res.success) {
      logger.warning('[goal-loops] pause failed: ${res.error}');
      loadFromSync();
    }
    return res;
  }

  /// Restart a loop that stopped in a terminal state.
  Future<MachineLoopResponse> resume({
    required String machineId,
    required String loopId,
    int? extraIterations,
  }) async {
    _patch(
      loopId,
      (l) => l.copyWith(status: 'running', statusDetail: '', paused: false),
    );
    final res = await sync.resumeMachineLoop(
      machineId: machineId,
      loopId: loopId,
      extraIterations: extraIterations,
    );
    if (!res.success) {
      logger.warning('[goal-loops] resume failed: ${res.error}');
      loadFromSync();
    }
    return res;
  }

  void _patch(String loopId, Loop Function(Loop) update) {
    final idx = state.indexWhere((l) => l.id == loopId);
    if (idx < 0) return;
    final next = List<Loop>.from(state);
    next[idx] = update(next[idx]);
    state = List<Loop>.unmodifiable(next);
  }

  bool _listsEqual(List<Loop> a, List<Loop> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final goalLoopsNotifierProvider =
    NotifierProvider<GoalLoopsNotifier, List<Loop>>(GoalLoopsNotifier.new);
