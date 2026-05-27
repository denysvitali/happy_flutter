import 'package:riverpod/riverpod.dart';

import '../models/artifact.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';
import '_shared.dart';

class ArtifactsNotifier extends Notifier<Map<String, DecryptedArtifact>> {
  int _lastDataChangeCounter = -1;

  @override
  Map<String, DecryptedArtifact> build() => {};

  void addArtifact(DecryptedArtifact artifact) {
    // Short-circuit when the slot already holds an identical reference —
    // common when a refresh path replays the same artifact.
    if (identical(state[artifact.id], artifact)) return;
    state = Map<String, DecryptedArtifact>.from(state)
      ..[artifact.id] = artifact;
  }

  void updateArtifact(
    String id,
    DecryptedArtifact Function(DecryptedArtifact) update,
  ) {
    final current = state[id];
    if (current == null) return;
    final next = update(current);
    if (identical(current, next)) return;
    state = Map<String, DecryptedArtifact>.from(state)..[id] = next;
  }

  void removeArtifact(String id) {
    state = Map<String, DecryptedArtifact>.from(state)..remove(id);
  }

  void setArtifacts(List<DecryptedArtifact> artifacts) {
    state = {for (final artifact in artifacts) artifact.id: artifact};
  }

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.domainChangeCounter(SyncDomain.artifacts);
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.artifacts;
    if (next.length == state.length &&
        next.every((a) => state.containsKey(a.id) && state[a.id] == a)) {
      return;
    }
    state = {for (final a in next) a.id: a};
  }

  Future<void> refreshFromSync() => refreshSyncDomain(
        invalidate: () => sync.artifactsSync,
        name: 'artifacts',
        reload: loadFromSync,
      );

  void clear() {
    state = {};
  }

  /// Removes [id] from state immediately, then confirms with the server.
  /// Rolls back on failure and logs a warning. Returns whether the server
  /// accepted the deletion.
  Future<bool> optimisticRemove(String id) async {
    final snapshot = state;
    state = Map<String, DecryptedArtifact>.from(state)..remove(id);
    try {
      await sync.deleteArtifact(id);
      return true;
    } catch (e, stack) {
      state = snapshot;
      logger.warning(
        'OptimisticMutation: deleteArtifact($id) failed, rolled back',
        e,
        stack,
      );
      return false;
    }
  }
}

final artifactsNotifierProvider =
    NotifierProvider<ArtifactsNotifier, Map<String, DecryptedArtifact>>(() {
      return ArtifactsNotifier();
    });
