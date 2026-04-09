part of 'sync_service.dart';

extension SyncTestHelpers on Sync {
  @visibleForTesting
  Map<String, Session> get testSessions => _sessions;

  @visibleForTesting
  Map<String, Machine> get testMachines => _machines;

  @visibleForTesting
  void testNotifyDataChanged() => _notifyDataChanged();

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
    _sessionMessagesCache = null;
    _sessionMessagesViewCache.remove(sessionId);
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

  @visibleForTesting
  void testGroupSidechainMessages(String sessionId) {
    _groupSidechainMessages(sessionId);
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
    if (!_sessionMessageChangeController.isClosed) {
      _sessionMessageChangeController.add(sessionId);
    }
  }

  /// Sets the in-memory seq cursor for a session (bypasses the normal
  /// inline-processing path that normally updates this from socket
  /// events).
  @visibleForTesting
  void testSetSessionLastSeq(String sessionId, int seq) {
    _sessionLastSeq[sessionId] = seq;
  }

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
  String? testGetModelOverride({AIBackendProfile? profile}) =>
      _getModelOverride(profile: profile);

  /// Test helper: set [_settingsSnapshot] for model override tests.
  @visibleForTesting
  set testSettingsSnapshot(Settings value) => _settingsSnapshot = value;
}
