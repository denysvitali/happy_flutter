/// App-local loop operations (pause, resume, delete), synced to the daemon in
/// the background on the shared [OperationStore] machine.
///
/// Loop lists draw [applyLoopOperations] over the daemon's loops, so a
/// paused loop reads paused and a deleted loop disappears the moment the
/// user asks. A `loops-updated` state that shows the effect confirms the
/// operation; a failure drops the overlay and the list shows the daemon's
/// state again.
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod/riverpod.dart';

import '../models/loop.dart';
import '../operations/operation_store.dart';
import 'loops_notifier.dart';

enum LoopOperationAction { pause, resume, delete }

@immutable
class LoopRequest {
  const LoopRequest({
    required this.sessionId,
    required this.loopId,
    required this.action,
  });

  final String sessionId;
  final String loopId;
  final LoopOperationAction action;
}

typedef LoopOperation = Operation<LoopRequest>;

String loopOperationKey(String sessionId, String loopId) =>
    '$sessionId/$loopId';

extension LoopOperationView on LoopOperation {
  /// Whether [loop] (null = no longer listed) shows this operation's effect.
  bool isConfirmedBy(Loop? loop) => switch (request.action) {
    LoopOperationAction.delete => loop == null,
    LoopOperationAction.pause => loop != null && loop.paused,
    LoopOperationAction.resume => loop != null && !loop.paused,
  };
}

class LoopOperationsNotifier extends OperationStore<LoopRequest> {
  @override
  String get logName => 'Loop';

  @override
  Map<String, LoopOperation> build() {
    final initial = super.build();
    ref.listen(loopsNotifierProvider, (_, loops) {
      confirmWhere((operation) {
        final request = operation.request;
        final loop = loops[request.sessionId]
            ?.where((candidate) => candidate.id == request.loopId)
            .firstOrNull;
        return operation.isConfirmedBy(loop);
      });
    });
    return initial;
  }

  @override
  String keyOf(LoopRequest request) =>
      loopOperationKey(request.sessionId, request.loopId);

  @override
  Future<Object?> perform(LoopRequest request) async {
    final loops = ref.read(loopsNotifierProvider.notifier);
    switch (request.action) {
      case LoopOperationAction.delete:
        await loops.deleteLoop(
          sessionId: request.sessionId,
          loopId: request.loopId,
        );
      case LoopOperationAction.pause || LoopOperationAction.resume:
        await loops.pauseLoop(
          sessionId: request.sessionId,
          loopId: request.loopId,
          paused: request.action == LoopOperationAction.pause,
        );
    }
    return null;
  }
}

/// Loop operations recorded this app session, keyed by `sessionId/loopId`.
final loopOperationsNotifierProvider =
    NotifierProvider<LoopOperationsNotifier, Map<String, LoopOperation>>(
      LoopOperationsNotifier.new,
    );

/// Draws pending/unconfirmed loop [operations] over the daemon's [loops]
/// for one session: deletes hide the loop, pause/resume flip `paused`.
List<Loop> applyLoopOperations(
  List<Loop> loops,
  Map<String, LoopOperation> operations,
) {
  if (operations.isEmpty || loops.isEmpty) return loops;
  var changed = false;
  final result = <Loop>[];
  for (final loop in loops) {
    final operation = operations[loopOperationKey(loop.sessionId, loop.id)];
    if (operation == null || !operation.overlays) {
      result.add(loop);
      continue;
    }
    changed = true;
    switch (operation.request.action) {
      case LoopOperationAction.delete:
        break;
      case LoopOperationAction.pause:
        result.add(loop.paused ? loop : loop.copyWith(paused: true));
      case LoopOperationAction.resume:
        result.add(loop.paused ? loop.copyWith(paused: false) : loop);
    }
  }
  return changed ? result : loops;
}
