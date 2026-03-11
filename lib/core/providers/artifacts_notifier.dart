import 'package:riverpod/riverpod.dart';

import '../models/artifact.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

class ArtifactsNotifier extends Notifier<Map<String, DecryptedArtifact>> {
  int _lastDataChangeCounter = 0;

  @override
  Map<String, DecryptedArtifact> build() => {};

  void addArtifact(DecryptedArtifact artifact) {
    state = {...state, artifact.id: artifact};
  }

  void updateArtifact(
    String id,
    DecryptedArtifact Function(DecryptedArtifact) update,
  ) {
    if (state.containsKey(id)) {
      state = {...state, id: update(state[id]!)};
    }
  }

  void removeArtifact(String id) {
    state = Map<String, DecryptedArtifact>.from(state)..remove(id);
  }

  void setArtifacts(List<DecryptedArtifact> artifacts) {
    state = {for (final artifact in artifacts) artifact.id: artifact};
  }

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.dataChangeCounter;
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.artifacts;
    if (next.length == state.length &&
        next.every((a) => state.containsKey(a.id) && state[a.id] == a)) {
      return;
    }
    state = {for (final a in next) a.id: a};
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    try {
      await sync.artifactsSync.invalidateAndAwait();
    } catch (e) {
      logger.warning('Failed to refresh artifacts: $e');
    }
    loadFromSync();
  }

  void clear() {
    state = {};
  }
}

final artifactsNotifierProvider =
    NotifierProvider<ArtifactsNotifier, Map<String, DecryptedArtifact>>(() {
      return ArtifactsNotifier();
    });
