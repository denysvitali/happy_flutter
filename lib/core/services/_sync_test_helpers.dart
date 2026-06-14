part of 'sync_service.dart';

extension SyncTestHelpers on Sync {
  @visibleForTesting
  Map<String, Session> get testSessions => _sessions;

  @visibleForTesting
  bool testIsPermanentSendFailure(Object error) =>
      SyncMessagingSend._isPermanentSendFailure(error);

  @visibleForTesting
  bool testIsRetryableSendFailure(Object error) =>
      SyncMessagingSend._isRetryableSendFailure(error);

  @visibleForTesting
  Map<String, Machine> get testMachines => _machines;

  @visibleForTesting
  void testNotifyDataChanged() => _notifyDataChanged();

  @visibleForTesting
  List<String> testSortedSessionIdsForCacheWarmup() {
    final entries = _sessions.entries.toList()
      ..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    return [for (final entry in entries) entry.key];
  }

  @visibleForTesting
  int? get testLastSessionsFetchedAt => _lastSessionsFetchedAt;

  @visibleForTesting
  set testLastSessionsFetchedAt(int? value) => _lastSessionsFetchedAt = value;

  @visibleForTesting
  bool get testForceFullFetchNext => _forceFullFetchNext;

  @visibleForTesting
  set testForceFullFetchNext(bool value) => _forceFullFetchNext = value;

  @visibleForTesting
  int? get testLastInvalidateAllSyncsAtMs => _lastInvalidateAllSyncsAtMs;

  @visibleForTesting
  set testLastInvalidateAllSyncsAtMs(int? value) =>
      _lastInvalidateAllSyncsAtMs = value;

  @visibleForTesting
  bool get testIsInitialized => isInitialized;

  @visibleForTesting
  set testIsInitialized(bool value) => isInitialized = value;

  @visibleForTesting
  void testInvalidateAllSyncs({
    bool force = false,
    bool resetSessionDeltaCursor = false,
  }) => _invalidateAllSyncs(
    force: force,
    resetSessionDeltaCursor: resetSessionDeltaCursor,
  );

  @visibleForTesting
  void testSetSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    _sessionMessages[sessionId] = List<Map<String, dynamic>>.from(messages);
    _invalidateMessageCaches(sessionId);
  }

  @visibleForTesting
  void testClearSessionMessageState(String sessionId) {
    _postSendCatchUpTimers.remove(sessionId)?.cancel();
    _sidechainRegroupTimers[sessionId]?.cancel();
    _sidechainRegroupTimers.remove(sessionId);
    _sidechainRegroupFirstRequestMs.remove(sessionId);
    messagesSync.remove(sessionId)?.dispose();
    _sessionMessages.remove(sessionId);
    _sessionLastSeq.remove(sessionId);
    _sessionFirstLoadedSeq.remove(sessionId);
    _sessionContentSignatures.remove(sessionId);
    _sessionsNeedingFetchProbe.remove(sessionId);
    _lastNoEmbedEventCursorSeq.remove(sessionId);
    _sessionsNeedingTailRefresh.remove(sessionId);
    _sessionsNeedingVisibleRegroup.remove(sessionId);
    _sessionsWithPendingUpdates.remove(sessionId);
    _sessionsWithPendingSocketMessages.remove(sessionId);
    _invalidateMessageCaches(sessionId);
    _previewCache.remove(sessionId);
    _previewCacheVersion.remove(sessionId);
    _sidechainRegroupSweepCount.remove(sessionId);
    _orphanFetchOlderAttemptedMs.remove(sessionId);
    _orphanFetchOlderNoProgressCount.remove(sessionId);
    _orphanWalkbackSignature.remove(sessionId);
    _orphanSuppressedUntilMs.remove(sessionId);
  }

  /// Test helper: clear the throttle timestamp for orphan-recovery
  /// fetchOlder attempts so the next sweep can call fetchOlderMessages
  /// again without waiting for the real wall clock.
  @visibleForTesting
  void testClearOrphanFetchOlderAttemptedMs(String sessionId) {
    _orphanFetchOlderAttemptedMs.remove(sessionId);
  }

  /// Test helper: read the last orphan-recovery fetchOlder attempt
  /// timestamp (epoch ms) for a session. 0 means the path has never
  /// fired for this session.
  @visibleForTesting
  int testOrphanFetchOlderAttemptedMs(String sessionId) {
    return _orphanFetchOlderAttemptedMs[sessionId] ?? 0;
  }

  @visibleForTesting
  Future<void> testPrimeSessionFromSpawnResult({
    required String requestedSessionId,
    required String restoredSessionId,
    required Session seedSession,
    required SpawnSessionResponse result,
  }) => _primeSessionFromSpawnResult(
    requestedSessionId: requestedSessionId,
    restoredSessionId: restoredSessionId,
    seedSession: seedSession,
    result: result,
  );

  /// Test helper: set the orphan-recovery no-progress counter directly.
  /// Used to exercise the hard cap without waiting for real wall-clock
  /// throttle windows.
  @visibleForTesting
  void testSetOrphanFetchOlderNoProgressCount(
    String sessionId,
    int count,
  ) {
    _orphanFetchOlderNoProgressCount[sessionId] = count;
  }

  /// Test helper: read the orphan-recovery no-progress counter.
  @visibleForTesting
  int testOrphanFetchOlderNoProgressCount(String sessionId) {
    return _orphanFetchOlderNoProgressCount[sessionId] ?? 0;
  }

  /// Test helper: prime the orphan walk-back signature from the current
  /// persisting orphan set, as if a sweep had already seen it. Lets
  /// tests exercise the no-progress caps directly without the sweep's
  /// signature check granting a fresh budget on first sight.
  @visibleForTesting
  void testPrimeOrphanWalkbackSignature(String sessionId) {
    final messages =
        _sessionMessages[sessionId] ?? const <Map<String, dynamic>>[];
    final orphans = messages
        .where(isVisibleSidechainOrphan)
        .map((m) => m['id'] as String?)
        .whereType<String>()
        .toSet();
    _orphanWalkbackSignature[sessionId] = Object.hashAllUnordered(orphans);
  }

  @visibleForTesting
  void testGroupSidechainMessages(String sessionId) {
    _groupSidechainMessages(sessionId);
  }

  /// Test helper: directly invoke the deferred regroup sweep.  This
  /// bypasses the 300ms debounce timer and runs the full sweep
  /// including orphan detection and the fetchOlder retry path.
  /// Orphans that remain after grouping are left in the message list
  /// (no synthetic absorption) so tests can assert they are
  /// preserved for inline rendering.
  @visibleForTesting
  void testRunDeferredRegroupSweep(String sessionId) {
    _runDeferredRegroupSweep(sessionId);
  }

  /// Test helper: get the current consecutive no-progress sweep count
  /// for a session.  Used to verify that premature absorb is blocked
  /// until the minimum sweep threshold is reached.
  @visibleForTesting
  int testGetSidechainRegroupSweepCount(String sessionId) {
    return _sidechainRegroupSweepCount[sessionId] ?? 0;
  }

  /// Test helper: reset the consecutive sweep counter for a session.
  /// Simulates a new message arriving to interrupt a stuck grouping.
  @visibleForTesting
  void testResetSidechainRegroupSweepCount(String sessionId) {
    _resetSidechainRegroupSweepCount(sessionId);
  }

  /// Test helper: invoke the cache-write transformation that strips
  /// `_orphanRecovery: true` synthetic Tasks before MMKV save.
  /// Synthetics are replaced with their flattened sidechain children
  /// so a future cold-start gets a clean slate rather than restoring
  /// the synthetic shape.
  @visibleForTesting
  static List<Map<String, dynamic>> testStripOrphanSynthetics(
    List<Map<String, dynamic>> messages,
  ) {
    return MessageCacheService.stripOrphanSynthetics(messages);
  }

  /// Test helper: directly set usage data for a session.
  @visibleForTesting
  void testSetSessionUsage(
    String sessionId,
    Map<String, dynamic> usage,
  ) {
    _sessionUsage[sessionId] = usage;
  }

  @visibleForTesting
  List<Map<String, dynamic>> testGetSessionMessages(String sessionId) {
    return _sessionMessages[sessionId] ?? const <Map<String, dynamic>>[];
  }

  @visibleForTesting
  void testApplyToolResults(
    String sessionId,
    List<Map<String, dynamic>> toolResults,
  ) {
    _applyToolResults(sessionId, toolResults);
  }

  @visibleForTesting
  Set<String> get testSessionsWithPendingUpdates => _sessionsWithPendingUpdates;

  @visibleForTesting
  set testVisibleSessionId(String? value) => _visibleSessionId = value;

  @visibleForTesting
  void testNotifySessionMessagesChanged(String sessionId) {
    // Mirror production: a real message-change notification bumps the
    // per-session revision (see _notifySessionMessagesChanged) so the
    // chat UI can detect the change even when the tail fingerprint is
    // unchanged.
    _bumpMessagesRevision(sessionId);
    if (!_sessionMessageChangeController.isClosed) {
      _sessionMessageChangeController.add(sessionId);
    }
  }

  /// Test helper: invoke [_scheduleSaveMessages] directly so the
  /// debounce/max-delay behaviour can be asserted without spinning
  /// the full streaming pipeline.
  @visibleForTesting
  void testScheduleSaveMessages(String sessionId) {
    _scheduleSaveMessages(sessionId);
  }

  /// Test helper: read the active per-session save debounce timer
  /// count.  Returns 0 if there is no pending save for the session.
  @visibleForTesting
  bool testHasPendingSaveTimer(String sessionId) =>
      _saveMsgsDebounceTimers.containsKey(sessionId);

  /// Test helper: invoke [_flushPendingMessageSaves] so the lifecycle
  /// flush behaviour can be asserted in isolation.
  @visibleForTesting
  void testFlushPendingMessageSaves() {
    _flushPendingMessageSaves();
  }

  /// Sets the in-memory seq cursor for a session (bypasses the normal
  /// inline-processing path that normally updates this from socket
  /// events).
  @visibleForTesting
  void testSetSessionLastSeq(String sessionId, int seq) {
    _sessionLastSeq[sessionId] = seq;
  }

  /// Returns the in-memory seq cursor for a session, or 0 if none exists.
  @visibleForTesting
  int testGetSessionLastSeq(String sessionId) =>
      _sessionLastSeq[sessionId] ?? 0;

  /// Test helper: directly set _sessionsWithPendingSocketMessages.
  @visibleForTesting
  void testSetPendingSocketMessages(Set<String> sessionIds) {
    _sessionsWithPendingSocketMessages.addAll(sessionIds);
  }

  @visibleForTesting
  void testAddFetchProbe(String sessionId) {
    _sessionsNeedingFetchProbe.add(sessionId);
  }

  @visibleForTesting
  bool testHasFetchProbe(String sessionId) =>
      _sessionsNeedingFetchProbe.contains(sessionId);

  /// Test helper: check if a session has pending socket messages.
  @visibleForTesting
  bool testHasPendingSocketMessage(String sessionId) =>
      _sessionsWithPendingSocketMessages.contains(sessionId);

  /// Test helper: check if a session has pending updates (session list
  /// UI refresh needed).
  @visibleForTesting
  bool testHasPendingUpdate(String sessionId) =>
      _sessionsWithPendingUpdates.contains(sessionId);

  /// Test helper: clear _sessionsWithPendingSocketMessages.
  @visibleForTesting
  void testClearSessionsWithPendingSocketMessages() =>
      _sessionsWithPendingSocketMessages.clear();

  /// Test helper: reset _lastResumeAtMs to bypass resume debounce in
  /// tests.
  @visibleForTesting
  void testResetLastResumeAtMs() => _lastResumeAtMs = null;

  /// Test helper: set _lastSuspendedAtMs to simulate a long background.
  @visibleForTesting
  set testLastSuspendedAtMs(int? value) => _lastSuspendedAtMs = value;

  /// Test helper: check if _pendingUpdateSessionIds is empty.
  @visibleForTesting
  bool testPendingUpdateSessionIdsEmpty() => _pendingUpdateSessionIds.isEmpty;

  /// Test helper: get _visibleSessionId.
  @visibleForTesting
  String? testGetVisibleSessionId() => _visibleSessionId;

  /// Test helper: set _visibleSessionId without triggering
  /// onSessionVisible side effects (message fetches, MMKV reads, etc).
  @visibleForTesting
  void testSetVisibleSessionId(String? id) => _visibleSessionId = id;

  /// Test helper: check if inline queue contains a session.
  @visibleForTesting
  bool testInlineQueueContains(String sessionId) =>
      _inlineProcessor.contains(sessionId);

  /// Test helper: get pending tool results for a session.
  @visibleForTesting
  List<Map<String, dynamic>> testPendingToolResults(String sessionId) =>
      _pendingToolResults[sessionId] ?? [];

  /// Test helper: get _sessionsNeedingTailRefresh as a set.
  @visibleForTesting
  Set<String> testSessionsNeedingTailRefresh() =>
      Set<String>.from(_sessionsNeedingTailRefresh);

  /// Test helper: add a session to _sessionsNeedingTailRefresh.
  @visibleForTesting
  void testAddSessionsNeedingTailRefresh(String sessionId) {
    _sessionsNeedingTailRefresh.add(sessionId);
  }

  /// Test helper: get _sessionMessages for a session (null if none).
  @visibleForTesting
  List<Map<String, dynamic>>? testSessionMessages(String sessionId) =>
      _sessionMessages[sessionId];

  /// Test helper: get the first loaded seq for a session
  /// (null if not set).
  @visibleForTesting
  int? testSessionFirstLoadedSeq(String sessionId) =>
      _sessionFirstLoadedSeq[sessionId];

  /// Test helper: set the first loaded seq for a session.
  @visibleForTesting
  void testSetSessionFirstLoadedSeq(String sessionId, int seq) {
    _sessionFirstLoadedSeq[sessionId] = seq;
  }

  /// Test helper: get _sessionSpawnedAt map.
  @visibleForTesting
  Map<String, int> get testSessionSpawnedAt => _sessionSpawnedAt;

  /// Test helper: set a spawn timestamp for a session.
  @visibleForTesting
  void testSetSessionSpawnedAt(String sessionId, int epochMs) {
    _sessionSpawnedAt[sessionId] = epochMs;
  }

  /// Test helper: clear all spawn timestamps.
  @visibleForTesting
  void testClearSessionSpawnedAt() {
    _sessionSpawnedAt.clear();
    _sessionSpawnedProfile.clear();
  }

  /// Test helper: get _sessionSpawnedProfile map.
  @visibleForTesting
  Map<String, String?> get testSessionSpawnedProfile => _sessionSpawnedProfile;

  /// Test helper: set the profile used when spawning a session.
  @visibleForTesting
  void testSetSessionSpawnedProfile(String sessionId, String? profileId) {
    _sessionSpawnedProfile[sessionId] = profileId;
  }

  /// Test helper: get _sessionSpawnedModel map.
  @visibleForTesting
  Map<String, String?> get testSessionSpawnedModel => _sessionSpawnedModel;

  /// Test helper: set the modelMode used when spawning a session.
  @visibleForTesting
  void testSetSessionSpawnedModel(String sessionId, String? modelMode) {
    _sessionSpawnedModel[sessionId] = modelMode;
  }

  /// Test helper: record a recent ephemeral event for a session so
  /// that [_isSessionReady] trusts its 'online' presence.
  @visibleForTesting
  void testSetLastEphemeralAt(String sessionId, int epochMs) {
    _lastEphemeralAt[sessionId] = epochMs;
  }

  /// Test helper: invoke [_checkForNewPermissionRequests].
  @visibleForTesting
  void testCheckForNewPermissionRequests(Iterable<Session> sessions) =>
      _checkForNewPermissionRequests(sessions);

  /// Test helper: read [_notifiedPermissionIds].
  @visibleForTesting
  Set<String> get testNotifiedPermissionIds => _notifiedPermissionIds;

  /// Test helper: get _autoRestoreInFlight set.
  @visibleForTesting
  Set<String> get testAutoRestoreInFlight => _autoRestoreInFlight;

  /// Test helper: set the _isReady flag.
  @visibleForTesting
  set testIsReady(bool value) => _isReady = value;

  /// Test helper: invoke [_getModelOverride] which is private.
  @visibleForTesting
  String? testGetModelOverride({
    String? agent,
    AIBackendProfile? profile,
    String? modelMode,
  }) => _getModelOverride(agent: agent, profile: profile, modelMode: modelMode);

  /// Test helper: invoke [_normalizeModelModeForAgent] which is private.
  @visibleForTesting
  String? testNormalizeModelModeForAgent(String? modelMode, String? agent) =>
      _normalizeModelModeForAgent(modelMode, agent);

  /// Test helper: set [_settingsSnapshot] for model override tests.
  @visibleForTesting
  set testSettingsSnapshot(Settings value) {
    _testSettingsSnapshot = value;
    settingsManager?.settingsSnapshot = value;
  }

  /// Test helper: invoke [_deliverOutboxEntry] through the real retry path.
  @visibleForTesting
  Future<bool> testDeliverOutboxEntry(OutboxEntry entry) =>
      _deliverOutboxEntry(entry);

  /// Test helper: start the resume conversation progress with [total]
  /// pending sessions. Mirrors what `resume()` calls internally.
  @visibleForTesting
  void testStartResumeConversationProgress(int total) =>
      _startResumeConversationProgress(total);

  /// Test helper: advance the resume conversation progress by [count]
  /// completed sessions. Mirrors what `resume()` calls after a batch.
  @visibleForTesting
  void testAdvanceResumeConversationProgress(int count) =>
      _advanceResumeConversationProgress(count);

  /// Test helper: read the current resume-progress totals (completed,
  /// total). Returns `(0, 0)` when the progress indicator is idle.
  @visibleForTesting
  (int, int) get testResumeConversationProgress =>
      (_resumeConversationRefreshCompleted, _resumeConversationRefreshTotal);

  /// Test helper: whether the safety timer is currently scheduled.
  @visibleForTesting
  bool get testResumeConversationProgressSafetyTimerActive =>
      _resumeConversationProgressSafetyTimer != null;

  /// Test helper: read [_syncProgress] directly (vs the public getter,
  /// which is identical but kept symmetrical with the other helpers).
  @visibleForTesting
  SyncProgress? get testSyncProgress => _syncProgress;

  /// Test helper: invoke the dropped-reason summarizer with a fabricated
  /// reason list so we can assert the info-vs-warning split that
  /// quiets known-skip categories (see
  /// `_isKnownSkipDroppedReason`).
  @visibleForTesting
  static void testLogDroppedReasonSummary(
    String context,
    List<String> reasons,
  ) {
    final counts = <String, int>{};
    _accumulateDroppedReasons(counts, reasons);
    _logDroppedReasonSummary(context, counts, captureToSentry: false);
  }

  /// Test helper: classify a normalized dropped-reason string as
  /// "known skip" (info-level) vs "true drift" (warning-level).
  @visibleForTesting
  static bool testIsKnownSkipDroppedReason(String normalized) =>
      _isKnownSkipDroppedReason(normalized);

  /// Test helper: expose the normalizer so callers can pin its
  /// stripping of seq/id prefixes when constructing expectations.
  @visibleForTesting
  static String testNormalizeDroppedReason(String reason) =>
      _normalizeDroppedReason(reason);

  /// Test helper: expose the predicate used by fetchMessages to decide
  /// whether a seq jump that produced no UI is composed entirely of
  /// expected invisible content.
  @visibleForTesting
  static bool testAreAllKnownSkipDrops(List<String> reasons) =>
      _areAllKnownSkipDrops(reasons);

  /// Test helper: build the synthetic visible event used when a fetched
  /// seq range advances without any renderable messages or auxiliary state.
  @visibleForTesting
  static Map<String, dynamic> testBuildDroppedSeqJumpEvent({
    required String sessionId,
    required int fromSeq,
    required int toSeq,
    required int rawCount,
    required List<String> droppedReasons,
  }) => _buildDroppedSeqJumpEvent(
    sessionId: sessionId,
    fromSeq: fromSeq,
    toSeq: toSeq,
    rawCount: rawCount,
    droppedReasons: droppedReasons,
  );
}
