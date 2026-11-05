part of 'sync_service.dart';

/// One catalog row whose metadata and/or agent state must be decrypted.
typedef _CatalogDecodeJob = ({
  String sessionId,
  SessionEncryption sessionEncryption,
  int metadataVersion,
  String metadataCipher,
  CatalogBlobKey metadataKey,
  CatalogMetadataDecode? memoMetadata,
  int agentStateVersion,
  String? agentStateCipher,
  CatalogBlobKey agentStateKey,
  ({AgentState? value})? memoAgentState,
});

extension SyncCatalogDecode on Sync {
  /// Decrypt and parse every session's `metadata` + `agentState`.
  ///
  /// Rows whose ciphertext matches the last read come straight from
  /// [_catalogDecodeMemo] without crypto, JSON or model parsing. The rest
  /// decode in [catalogDecodeBatchSize] slices that yield to the event loop:
  /// the native decrypt is synchronous, so one `Future.wait` over the whole
  /// catalog used to run every row back to back and froze the UI isolate
  /// for ~550 ms at 1,258 sessions. Metadata and agent state of a row still
  /// decrypt concurrently.
  ///
  /// Returns a sessionId-keyed map; sessions whose payload is invalid or
  /// which lack a registered encryptor are simply absent (the caller treats
  /// that as "no decrypted content available"). Returns `null` when the
  /// runtime changed while yielding.
  Future<Map<String, _DecryptedSessionContent>?> _preDecryptSessions(
    List<dynamic> allSessions, {
    required int runtimeGeneration,
  }) async {
    final decoded = <String, _DecryptedSessionContent>{};
    final jobs = <_CatalogDecodeJob>[];
    for (final raw in allSessions) {
      if (raw is! Map<String, dynamic>) continue;
      final sessionId = WireParsers.parseString(raw['id']);
      if (sessionId == null || sessionId.isEmpty) continue;
      final sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) continue;
      final metadataVersion = _asSessionInt(raw['metadataVersion']) ?? 0;
      final agentStateVersion = _asSessionInt(raw['agentStateVersion']) ?? 0;
      final metadataCipher = WireParsers.parseString(raw['metadata']) ?? '';
      final agentStateCipher = WireParsers.parseString(raw['agentState']);
      final metadataKey = catalogBlobKey(
        sessionEncryption,
        metadataVersion,
        metadataCipher,
      );
      final agentStateKey = catalogBlobKey(
        sessionEncryption,
        agentStateVersion,
        agentStateCipher,
      );
      final memoMetadata = _catalogDecodeMemo.metadata(sessionId, metadataKey);
      final memoAgentState = _catalogDecodeMemo.agentState(
        sessionId,
        agentStateKey,
      );
      if (memoMetadata != null && memoAgentState != null) {
        decoded[sessionId] = _DecryptedSessionContent(
          metadata: memoMetadata.metadata,
          todos: memoMetadata.todos,
          agentState: memoAgentState.value,
        );
        continue;
      }
      jobs.add((
        sessionId: sessionId,
        sessionEncryption: sessionEncryption,
        metadataVersion: metadataVersion,
        metadataCipher: metadataCipher,
        metadataKey: metadataKey,
        memoMetadata: memoMetadata,
        agentStateVersion: agentStateVersion,
        agentStateCipher: agentStateCipher,
        agentStateKey: agentStateKey,
        memoAgentState: memoAgentState,
      ));
    }
    if (jobs.isEmpty) return decoded;

    final results = await runInYieldingBatches(
      jobs,
      (job) => _decodeCatalogRow(job, runtimeGeneration: runtimeGeneration),
      name: 'sessions_fetch.decrypt',
      isStale: () => runtimeGeneration != _runtimeGeneration,
    );
    if (results == null) return null;
    for (var i = 0; i < jobs.length; i++) {
      decoded[jobs[i].sessionId] = results[i];
    }
    return decoded;
  }

  Future<_DecryptedSessionContent> _decodeCatalogRow(
    _CatalogDecodeJob job, {
    required int runtimeGeneration,
  }) async {
    final sessionId = job.sessionId;
    final sessionEncryption = job.sessionEncryption;
    Future<Map<String, dynamic>?>? metadataFuture;
    Future<Map<String, dynamic>>? agentStateFuture;
    if (job.memoMetadata == null) {
      try {
        metadataFuture = sessionEncryption.decryptMetadata(
          job.metadataVersion,
          job.metadataCipher,
        );
      } catch (e) {
        logger.warning(
          'Failed to start session metadata decrypt for $sessionId',
          e,
        );
        metadataFuture = Future<Map<String, dynamic>?>.value(null);
      }
    }
    if (job.memoAgentState == null) {
      try {
        agentStateFuture = sessionEncryption.decryptAgentState(
          job.agentStateVersion,
          job.agentStateCipher,
        );
      } catch (e) {
        logger.warning(
          'Failed to start session agentState decrypt for $sessionId',
          e,
        );
        agentStateFuture = Future<Map<String, dynamic>>.value({});
      }
    }

    var metadataDecode = job.memoMetadata;
    if (metadataFuture != null) {
      Map<String, dynamic>? metadata;
      try {
        metadata = await metadataFuture;
      } catch (e) {
        logger.warning('Failed to decrypt session metadata for $sessionId', e);
      }
      Metadata? parsed;
      if (metadata != null) {
        try {
          parsed = Metadata.fromJson(metadata);
        } catch (e) {
          logger.warning('Failed to parse session metadata for $sessionId', e);
        }
      }
      final decodedMetadata = (
        metadata: parsed,
        todos: TodoItem.listFromJsonForSession(metadata?['todos'], sessionId),
      );
      metadataDecode = decodedMetadata;
      // Only a successful decrypt is remembered; a failure retries next read.
      if (metadata != null && runtimeGeneration == _runtimeGeneration) {
        _catalogDecodeMemo.putMetadata(
          sessionId,
          job.metadataKey,
          decodedMetadata,
        );
      }
    }

    var agentState = job.memoAgentState?.value;
    if (agentStateFuture != null) {
      Map<String, dynamic>? raw;
      try {
        raw = await agentStateFuture;
      } catch (e) {
        logger.warning(
          'Failed to decrypt session agentState for $sessionId',
          e,
        );
      }
      AgentState? parsed;
      if (raw != null && raw.isNotEmpty) {
        try {
          parsed = AgentState.fromJson(raw);
        } catch (e) {
          logger.warning(
            'Failed to parse session agentState for $sessionId',
            e,
          );
        }
      }
      agentState = parsed;
      // An empty result for a non-empty blob may be a failed decrypt
      // (decryptAgentState reports failure as `{}`), so it is not memoized.
      final cipher = job.agentStateCipher;
      final remember =
          (raw != null && raw.isNotEmpty) || cipher == null || cipher.isEmpty;
      if (remember && runtimeGeneration == _runtimeGeneration) {
        _catalogDecodeMemo.putAgentState(sessionId, job.agentStateKey, parsed);
      }
    }

    return _DecryptedSessionContent(
      metadata: metadataDecode?.metadata,
      todos: metadataDecode?.todos,
      agentState: agentState,
    );
  }
}

/// Parsed bundle for one session — output of [_preDecryptSessions].
class _DecryptedSessionContent {
  const _DecryptedSessionContent({
    required this.metadata,
    required this.todos,
    required this.agentState,
  });

  final Metadata? metadata;
  final List<TodoItem>? todos;
  final AgentState? agentState;
}
