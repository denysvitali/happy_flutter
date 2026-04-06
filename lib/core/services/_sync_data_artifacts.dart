part of 'sync_service.dart';

extension SyncDataArtifacts on Sync {
  /// Fetch artifacts list from server
  Future<void> fetchArtifactsList() async {
    logger.info('Fetching artifacts...');
    try {
      final api = ApiClient();
      final response = await api.get('/v1/artifacts');
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch artifacts: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawArtifacts = (data is Map<String, dynamic>)
          ? data['artifacts']
          : data;
      if (rawArtifacts is! List) {
        _artifacts.clear();
        return;
      }

      // Phase 1: Decrypt artifact data keys on the main thread.
      // CryptoBox.decrypt is fast (single NaCl call per artifact).
      final keyedArtifacts = <({Artifact artifact, Uint8List key})>[];
      final decryptedArtifacts = <DecryptedArtifact>[];
      for (final raw in rawArtifacts) {
        await Future<void>.delayed(Duration.zero); // yield to event queue
        if (raw is! Map<String, dynamic>) continue;
        try {
          final artifact = Artifact.fromJson(raw);
          final decryptedKey = await encryption.decryptEncryptionKey(
            artifact.dataEncryptionKey,
          );
          if (decryptedKey != null) {
            _artifactDataKeys[artifact.id] = decryptedKey;
            keyedArtifacts.add((artifact: artifact, key: decryptedKey));
          } else {
            decryptedArtifacts.add(
              DecryptedArtifact(
                id: artifact.id,
                headerVersion: artifact.headerVersion,
                bodyVersion: artifact.bodyVersion,
                seq: artifact.seq,
                createdAt: artifact.createdAt,
                updatedAt: artifact.updatedAt,
                isDecrypted: false,
              ),
            );
          }
        } catch (error, stack) {
          logger.error('Failed to parse artifact key', error, stack);
        }
      }

      // Phase 2: Decrypt headers + bodies off the main thread.
      // AES-GCM pure-Dart decryption can be slow for many artifacts.
      if (keyedArtifacts.isNotEmpty) {
        final artifactIsolateItems = keyedArtifacts.map((e) {
          final encHeader = Base64Utils.decode(
            e.artifact.header,
            Encoding.base64,
          );
          final encBody = e.artifact.body != null
              ? Base64Utils.decode(e.artifact.body!, Encoding.base64)
              : null;
          return _ArtifactIsolateItem(
            id: e.artifact.id,
            secretKey: e.key,
            encryptedHeader: encHeader,
            encryptedBody: encBody,
          );
        }).toList();

        final artifactIsolateResults = await _decryptArtifactsInIsolate(
          artifactIsolateItems,
        );
        final artifactResultById = {
          for (final r in artifactIsolateResults) r.id: r,
        };

        for (final e in keyedArtifacts) {
          final artifact = e.artifact;
          final result = artifactResultById[artifact.id];
          final header = result?.header;
          final body = result?.body;
          decryptedArtifacts.add(
            DecryptedArtifact(
              id: artifact.id,
              title: header?['title'] as String?,
              sessions: (header?['sessions'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList(),
              draft: header?['draft'] as bool?,
              body: body?['body'] as String?,
              headerVersion: artifact.headerVersion,
              bodyVersion: artifact.bodyVersion,
              seq: artifact.seq,
              createdAt: artifact.createdAt,
              updatedAt: artifact.updatedAt,
              isDecrypted: header != null,
            ),
          );
        }
      }

      _artifacts
        ..clear()
        ..addAll(decryptedArtifacts);
      _notifyDataChanged({SyncDomain.artifacts});
      logger.info('Fetched artifacts: ${_artifacts.length}');
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Failed to fetch artifacts', error, stack);
    }
  }

  /// Fetch a single artifact with full body decrypted.
  Future<DecryptedArtifact?> fetchArtifactWithBody(String id) async {
    try {
      final api = ApiClient();
      final response = await api.get('/v1/artifacts/$id');
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch artifact: ${response.statusCode}');
        return null;
      }
      final raw = response.data;
      if (raw is! Map<String, dynamic>) return null;
      final artifact = Artifact.fromJson(raw);
      final decryptedKey =
          _artifactDataKeys[artifact.id] ??
          await encryption.decryptEncryptionKey(artifact.dataEncryptionKey);
      if (decryptedKey == null) return null;
      _artifactDataKeys[artifact.id] = decryptedKey;
      final artifactEncryption = ArtifactEncryption(decryptedKey);
      final header = await artifactEncryption.decryptHeader(artifact.header);
      final body = artifact.body != null
          ? await artifactEncryption.decryptBody(artifact.body!)
          : null;
      return DecryptedArtifact(
        id: artifact.id,
        title: header?['title'] as String?,
        body: body?['body'] as String?,
        headerVersion: artifact.headerVersion,
        bodyVersion: artifact.bodyVersion,
        seq: artifact.seq,
        createdAt: artifact.createdAt,
        updatedAt: artifact.updatedAt,
        isDecrypted: header != null,
      );
    } catch (error, stack) {
      logger.error('Failed to fetch artifact', error, stack);
      return null;
    }
  }

  /// Create a new artifact with optional title and body.
  /// Returns the new artifact's ID.
  Future<String> createArtifact(String? title, String? body) async {
    final dek = ArtifactEncryption.generateDataEncryptionKey();
    final artifactEncryption = ArtifactEncryption(dek);
    final encryptedDek = await encryption.encryptEncryptionKey(dek);
    final encryptedDekB64 = Base64Utils.encode(encryptedDek, Encoding.base64);
    final encryptedHeader = await artifactEncryption.encryptHeader({
      'title': title,
    });
    final encryptedBody = await artifactEncryption.encryptBody({
      'body': body ?? '',
    });
    final artifactId = encryption.generateId();
    final request = ArtifactCreateRequest(
      id: artifactId,
      header: encryptedHeader,
      body: encryptedBody,
      dataEncryptionKey: encryptedDekB64,
    );
    final api = ApiClient();
    final response = await api.post('/v1/artifacts', data: request.toJson());
    if (!api.isSuccess(response)) {
      throw StateError('Failed to create artifact: ${response.statusCode}');
    }
    _artifactDataKeys[artifactId] = dek;
    artifactsSync.invalidate();
    return artifactId;
  }

  /// Update an existing artifact's title and/or body.
  Future<void> updateArtifact(String id, String? title, String? body) async {
    final dek = _artifactDataKeys[id];
    if (dek == null) {
      throw StateError('No decryption key found for artifact $id');
    }
    final artifactEncryption = ArtifactEncryption(dek);
    final existing = _artifacts.firstWhere(
      (a) => a.id == id,
      orElse: () => throw StateError('Artifact $id not found in cache'),
    );
    final encryptedHeader = await artifactEncryption.encryptHeader({
      'title': title,
    });
    final encryptedBody = await artifactEncryption.encryptBody({
      'body': body ?? '',
    });
    final request = ArtifactUpdateRequest(
      header: encryptedHeader,
      expectedHeaderVersion: existing.headerVersion,
      body: encryptedBody,
      expectedBodyVersion: existing.bodyVersion,
    );
    final api = ApiClient();
    final response = await api.post(
      '/v1/artifacts/$id',
      data: request.toJson(),
    );
    if (!api.isSuccess(response)) {
      throw StateError('Failed to update artifact: ${response.statusCode}');
    }
    artifactsSync.invalidate();
  }

  /// Delete an artifact by ID.
  Future<void> deleteArtifact(String id) async {
    final api = ApiClient();
    final response = await api.delete('/v1/artifacts/$id');
    if (!api.isSuccess(response)) {
      throw StateError('Failed to delete artifact: ${response.statusCode}');
    }
    _artifactDataKeys.remove(id);
    _artifacts.removeWhere((a) => a.id == id);
    _notifyDataChanged({SyncDomain.artifacts});
  }
}
