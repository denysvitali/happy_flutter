part of 'sync_service.dart';

/// Result of a machine-scoped loop RPC.
///
/// Failures come back as an unsuccessful response rather than an exception:
/// an offline machine, or one running a daemon from before goal loops
/// existed, is an expected state for this screen and not a crash.
class MachineLoopResponse {
  const MachineLoopResponse({
    required this.success,
    this.error,
    this.loop,
    this.loops = const <Loop>[],
    this.failureKind,
  });

  final bool success;
  final String? error;
  final RemoteFeatureFailureKind? failureKind;

  /// The loop the daemon created, for `loop-create`.
  final Loop? loop;

  /// The machine's full loop list, for `loop-list`.
  final List<Loop> loops;

  static MachineLoopResponse fromJson(Map<String, dynamic> json) {
    final ok = json['ok'];
    final loopJson = json['loop'];
    final loopsJson = json['loops'];
    return MachineLoopResponse(
      success: ok != false,
      error: json['error']?.toString(),
      failureKind: ok == false ? RemoteFeatureFailureKind.rejected : null,
      loop: loopJson is Map
          ? Loop.tryFromJson(Map<String, dynamic>.from(loopJson))
          : null,
      loops: loopsJson is List
          ? loopsJson
                .whereType<Map>()
                .map((e) => Loop.tryFromJson(Map<String, dynamic>.from(e)))
                .whereType<Loop>()
                .toList(growable: false)
          : const <Loop>[],
    );
  }
}

/// Machine-scoped loops — the daemon-owned kind, including goal loops.
///
/// These differ from the session loops in `_sync_loops.dart` in both
/// ownership and transport. A session loop injects a prompt into an already
/// running session; a machine loop spawns a fresh session per run, and a goal
/// loop keeps doing that until an iteration reports the goal reached.
///
/// Reading is free and passive: the daemon mirrors its loop list into the
/// encrypted `daemonState` blob under `machineLoops`, which already rides the
/// existing update-machine channel. There is nothing to poll — [machineLoops]
/// is a projection of state the app already has. Only mutations need an RPC.
extension SyncMachineLoops on Sync {
  /// Key the daemon publishes its machine-loop list under in `daemonState`.
  static const String _daemonStateKey = 'machineLoops';

  /// Every machine loop the app knows about, newest first.
  List<Loop> get machineLoops {
    final all = <Loop>[];
    for (final machine in _machines.values) {
      all.addAll(_loopsFromDaemonState(machine));
    }
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<Loop>.unmodifiable(all);
  }

  /// Machine loops owned by [machineId], newest first.
  List<Loop> machineLoopsFor(String machineId) {
    final machine = _machines[machineId];
    if (machine == null) return const <Loop>[];
    final loops = _loopsFromDaemonState(machine).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List<Loop>.unmodifiable(loops);
  }

  /// Every goal loop across all machines, newest first. Goal loops are what
  /// the Goal Loops screen shows; plain scheduled machine loops are not
  /// interesting there.
  List<Loop> get goalLoops =>
      List<Loop>.unmodifiable(machineLoops.where((l) => l.isGoalLoop));

  /// Parses the loop list out of one machine's `daemonState`, stamping the
  /// owning machine id onto entries that predate the daemon writing it.
  Iterable<Loop> _loopsFromDaemonState(Machine machine) {
    final raw = machine.daemonState?[_daemonStateKey];
    if (raw is! List) return const <Loop>[];
    return raw.whereType<Map>().map((entry) {
      final loop = Loop.tryFromJson(Map<String, dynamic>.from(entry));
      if (loop == null) return null;
      return loop.machineId.isEmpty
          ? loop.copyWith(machineId: machine.id)
          : loop;
    }).whereType<Loop>();
  }

  // ── Mutations ──────────────────────────────────────────────────────────

  /// Create a goal loop on [machineId].
  ///
  /// The daemon starts iterating immediately: it bootstraps the progress file
  /// in [directory] and spawns the first session. The loop runs until an
  /// iteration reports the goal reached (or blocked), the iteration cap is
  /// hit, or iterations stop changing the progress file.
  Future<MachineLoopResponse> createGoalLoop({
    required String machineId,
    required String goal,
    required String directory,
    String? agent,
    String? model,
    String? permissionMode,
    String? progressFile,
    int? maxIterations,
    String? extraInstructions,
  }) => _machineLoopRpc(
    machineId: machineId,
    method: 'loop-create',
    label: 'createGoalLoop',
    params: <String, dynamic>{
      'goal': goal,
      'directory': directory,
      if (agent != null && agent.isNotEmpty) 'agent': agent,
      if (model != null && model.isNotEmpty) 'model': model,
      if (permissionMode != null && permissionMode.isNotEmpty)
        'permissionMode': permissionMode,
      if (progressFile != null && progressFile.isNotEmpty)
        'progressFile': progressFile,
      if (maxIterations != null && maxIterations > 0)
        'maxIterations': maxIterations,
      // The daemon appends this to every iteration's prompt, after the
      // goal-loop contract.
      if (extraInstructions != null && extraInstructions.isNotEmpty)
        'prompt': extraInstructions,
    },
    timeout: const Duration(seconds: 30),
  );

  /// Delete a machine loop. An iteration already in flight finishes on its
  /// own; the chain simply stops.
  Future<MachineLoopResponse> deleteMachineLoop({
    required String machineId,
    required String loopId,
  }) => _machineLoopRpc(
    machineId: machineId,
    method: 'loop-delete',
    label: 'deleteMachineLoop',
    params: <String, dynamic>{'loopId': loopId},
  );

  /// Pause or resume a machine loop. Pausing lets the in-flight iteration
  /// finish but does not chain another.
  Future<MachineLoopResponse> pauseMachineLoop({
    required String machineId,
    required String loopId,
    required bool paused,
  }) => _machineLoopRpc(
    machineId: machineId,
    method: 'loop-pause',
    label: 'pauseMachineLoop',
    params: <String, dynamic>{'loopId': loopId, 'paused': paused},
  );

  /// Restart a loop that stopped in a terminal state — typically one an
  /// iteration reported BLOCKED that the user has now unblocked.
  ///
  /// [extraIterations] raises the cap. Resuming an exhausted loop without
  /// raising it would stop again immediately, so the daemon applies a default
  /// bump in that case.
  Future<MachineLoopResponse> resumeMachineLoop({
    required String machineId,
    required String loopId,
    int? extraIterations,
  }) => _machineLoopRpc(
    machineId: machineId,
    method: 'loop-resume',
    label: 'resumeMachineLoop',
    params: <String, dynamic>{
      'loopId': loopId,
      if (extraIterations != null && extraIterations > 0)
        'extraIterations': extraIterations,
    },
  );

  /// Fetch [machineId]'s authoritative loop list.
  ///
  /// Rarely needed — `daemonState` already mirrors it passively — but useful
  /// as an explicit pull-to-refresh, and to tell "no loops" apart from "this
  /// daemon has never published any".
  Future<MachineLoopResponse> listMachineLoops({required String machineId}) =>
      _machineLoopRpc(
        machineId: machineId,
        method: 'loop-list',
        label: 'listMachineLoops',
        params: const <String, dynamic>{},
      );

  /// Shared transport + error mapping for the machine loop RPCs.
  Future<MachineLoopResponse> _machineLoopRpc({
    required String machineId,
    required String method,
    required String label,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final supported = testMachineRPCOverride == null
          ? await machineSupportsRPC(machineId, method)
          : null;
      if (supported == false) {
        return const MachineLoopResponse(
          success: false,
          error: 'Goal loops require a newer machine agent',
          failureKind: RemoteFeatureFailureKind.unsupported,
        );
      }
      return await _typedMachineRPC(
        machineId,
        method,
        params,
        MachineLoopResponse.fromJson,
        timeout: timeout,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('$label: machine offline');
        return const MachineLoopResponse(
          success: false,
          error: 'machine offline',
          failureKind: RemoteFeatureFailureKind.offline,
        );
      } else if (Sync._isRpcMethodNotAvailable(error)) {
        logger.info('$label: RPC method not available (daemon too old)');
        return const MachineLoopResponse(
          success: false,
          error: 'Goal loops require a newer machine agent',
          failureKind: RemoteFeatureFailureKind.unsupported,
        );
      } else if (Sync._isTransientRpcError(error)) {
        logger.info('$label: transient RPC failure — $error');
        return const MachineLoopResponse(
          success: false,
          error: 'transient RPC failure',
          failureKind: RemoteFeatureFailureKind.transient,
        );
      } else {
        logger.error('$label error', error, stackTrace);
      }
    }
    return const MachineLoopResponse(
      success: false,
      error: 'RPC call failed',
      failureKind: RemoteFeatureFailureKind.unknown,
    );
  }
}
