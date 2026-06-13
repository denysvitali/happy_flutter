import 'package:riverpod/riverpod.dart';

import '../models/artifact.dart';
import '../services/sync_service.dart' show sync;
import '../sync/artifact_manager.dart';

/// Repository layer for artifacts. Wraps [ArtifactManager] and provides
/// the public surface used by notifiers and screens.
class ArtifactsRepository {
  const ArtifactsRepository(this._manager);

  final ArtifactManager _manager;

  /// All artifacts currently held in memory.
  List<DecryptedArtifact> get artifacts => _manager.artifacts;

  /// Fetch the artifacts list from the server.
  Future<void> fetchArtifactsList() => _manager.fetchArtifactsList();

  /// Fetch a single artifact with its body decrypted.
  Future<DecryptedArtifact?> fetchArtifactWithBody(String id) =>
      _manager.fetchArtifactWithBody(id);

  /// Create a new artifact and return its ID.
  Future<String> createArtifact(String? title, String? body) =>
      _manager.createArtifact(title, body);

  /// Update an existing artifact's title and/or body.
  Future<void> updateArtifact(
    String id, {
    String? title,
    String? body,
  }) =>
      _manager.updateArtifact(id, title, body);

  /// Delete an artifact by ID.
  Future<void> deleteArtifact(String id) => _manager.deleteArtifact(id);
}

/// Provider for the artifact manager managed by the sync singleton.
final artifactManagerProvider = Provider<ArtifactManager>(
  (ref) => sync.artifactManager!,
);

/// Provider for the artifacts repository.
final artifactsRepositoryProvider = Provider<ArtifactsRepository>(
  (ref) => ArtifactsRepository(ref.read(artifactManagerProvider)),
);