import 'package:riverpod/riverpod.dart';

import '../models/artifact.dart';
import '../repositories/artifacts_repository.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart' show SyncDomain, sync;
import '_shared.dart';

class ArtifactsNotifier extends Notifier<Map<String, DecryptedArtifact>> {
  int _lastDataChangeCounter = -1;

  @override
  Map<String, DecryptedArtifact> build() => {};

  ArtifactsRepository get _repository => ref.read(artifactsRepositoryProvider);

  void addArtifact(DecryptedArtifact artifact) {
    // Short-circuit when the slot already holds an identical reference —
    // common when a refresh path replays the same artifact.
    if (identical(state[artifact.id], artifact)) return;
    state = Map<String, DecryptedArtifact>.from(state)
      ..[artifact.id] = artifact;
  }

  void updateArtifactInState(
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
    final next = _repository.artifacts;
    if (next.length == state.length &&
        next.every((a) => state.containsKey(a.id) && state[a.id] == a)) {
      return;
    }
    state = {for (final a in next) a.id: a};
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) return;
    try {
      await _repository.fetchArtifactsList();
    } catch (e, stack) {
      logger.warning('Failed to refresh artifacts', e, stack);
    }
    loadFromSync();
  }

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
      await _repository.deleteArtifact(id);
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

  /// Creates a new artifact on the server and returns its ID.
  Future<String> createArtifact(String? title, String? body) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    try {
      return await _repository.createArtifact(title, body);
    } catch (e, stack) {
      logger.warning(
        'ArtifactsNotifier.createArtifact($title) failed',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Updates an existing artifact's title and/or body on the server.
  Future<void> saveArtifact(
    String id, {
    String? title,
    String? body,
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    try {
      await _repository.updateArtifact(id, title: title, body: body);
    } catch (e, stack) {
      logger.warning(
        'ArtifactsNotifier.saveArtifact($id) failed',
        e,
        stack,
      );
      rethrow;
    }
  }
}

final artifactsNotifierProvider =
    NotifierProvider<ArtifactsNotifier, Map<String, DecryptedArtifact>>(() {
      return ArtifactsNotifier();
    });
