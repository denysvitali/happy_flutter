part of 'sync_service.dart';

extension SyncDataArtifacts on Sync {
  /// Fetch artifacts list from server.
  Future<void> fetchArtifactsList() async {
    await artifactManager?.fetchArtifactsList();
  }

  /// Fetch a single artifact with full body decrypted.
  Future<DecryptedArtifact?> fetchArtifactWithBody(String id) async {
    return artifactManager?.fetchArtifactWithBody(id);
  }

  /// Create a new artifact with optional title and body.
  /// Returns the new artifact's ID.
  Future<String> createArtifact(String? title, String? body) async {
    final manager = artifactManager;
    if (manager == null) {
      throw StateError('ArtifactManager is not initialized');
    }
    return manager.createArtifact(title, body);
  }

  /// Update an existing artifact's title and/or body.
  Future<void> updateArtifact(String id, String? title, String? body) async {
    final manager = artifactManager;
    if (manager == null) {
      throw StateError('ArtifactManager is not initialized');
    }
    return manager.updateArtifact(id, title, body);
  }

  /// Delete an artifact by ID.
  Future<void> deleteArtifact(String id) async {
    final manager = artifactManager;
    if (manager == null) {
      throw StateError('ArtifactManager is not initialized');
    }
    return manager.deleteArtifact(id);
  }
}
