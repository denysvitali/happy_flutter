part of 'sync_service.dart';

extension SyncOutboxRecovery on Sync {
  /// Recreate only explicitly recovered, current-owner failed rows. History
  /// and socket echoes still replace these placeholders by canonical localId.
  void _restoreRecoveredOutboxRows(String sessionId) {
    if (!isInitialized ||
        !_sessions.containsKey(sessionId) ||
        !_sessionMessages.containsKey(sessionId)) {
      return;
    }
    final rows = _sessionMessages[sessionId]!;
    final missing = messageOutbox.deadEntries
        .where(
          (entry) =>
              entry.sessionId == sessionId &&
              entry.failureReason == 'legacy_recovered' &&
              !rows.any((row) => _matchesLocalId(row, entry.localId)),
        )
        .toList();
    if (missing.isEmpty) return;
    final owner = MessageOutbox.ownerScope(
      accountId: anonID,
      serverUrl: getServerUrl(),
    );
    if (!messageOutbox.hasOwnerScope(owner)) return;
    _upsertSessionMessages(sessionId, [
      for (final entry in missing)
        <String, dynamic>{
          'id': entry.localId,
          'localId': entry.localId,
          'seq': 0,
          'createdAt': entry.queuedAt,
          'role': 'user',
          'kind': 'text',
          'content': entry.text,
          'raw': entry.rawRecord,
          'sendStatus': 'failed',
        },
    ]);
    _invalidateMessageCaches(sessionId);
    _notifySessionMessagesChanged(sessionId);
  }

  /// Only sessions in this authenticated runtime may be offered for recovery.
  /// Nothing in the legacy payload is used to discover an account or route.
  Future<LegacyOutboxPreview?> previewLegacyOutbox(String sessionId) {
    final generation = _runtimeGeneration;
    final session = _sessions[sessionId];
    if (!isInitialized || session == null) return Future.value();
    final owner = MessageOutbox.ownerScope(
      accountId: anonID,
      serverUrl: getServerUrl(),
    );
    return messageOutbox.previewLegacyRecovery(
      sessionId: sessionId,
      isCurrent: () =>
          isInitialized &&
          generation == _runtimeGeneration &&
          identical(session, _sessions[sessionId]) &&
          messageOutbox.hasOwnerScope(owner) &&
          owner ==
              MessageOutbox.ownerScope(
                accountId: anonID,
                serverUrl: getServerUrl(),
              ),
    );
  }
}
