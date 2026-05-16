part of 'sync_service.dart';

extension SyncSessions on Sync {
  void _scheduleSessionsRefresh() {
    _sessionsRefreshDebounceTimer?.cancel();
    _sessionsRefreshDebounceTimer = Timer(
      Sync._sessionsRefreshDebounce,
      () => unawaited(_flushScheduledSessionsRefresh()),
    );
  }

  Future<void> _flushScheduledSessionsRefresh() async {
    _sessionsRefreshDebounceTimer?.cancel();
    _sessionsRefreshDebounceTimer = null;
    _pendingUpdateSessionIds.clear();

    await sessionsSync.invalidateAndAwait();

    if (_pendingNewSessionIds.isEmpty) {
      return;
    }

    final sessionIdsNeedingFullFetch = _pendingNewSessionIds
        .where(
          (sessionId) => encryption.getSessionEncryption(sessionId) == null,
        )
        .toList();
    _pendingNewSessionIds.clear();

    if (sessionIdsNeedingFullFetch.isEmpty) {
      return;
    }

    // A newly created session can miss the first delta fetch due to clock skew
    // or replication lag. Retry once with a full fetch so its encryption key is
    // initialized before the user opens it.
    _forceFullFetchNext = true;
    await sessionsSync.invalidateAndAwait();
  }

  /// Handle account update — debounced to collapse rapid-fire
  /// duplicate events (server can send 20+ in < 10ms).
  ///
  /// NOTE: Using debounce Timer breaks the `awaitQueue()` pattern used
  /// in tests. The debounce delays `invalidate()` by 500ms, but tests
  /// call `awaitQueue()` synchronously and expect invalidation to have
  /// already occurred.
  /// For now, call invalidate() synchronously — the InvalidateSync's own
  /// cooldown/debounce mechanism provides adequate protection against
  /// duplicate-event storms at the sync layer.
  void _handleUpdateAccount(Map<String, dynamic> data) {
    // Suppress the socket echo when we just POSTed settings — the
    // server broadcasts an update-account event immediately after
    // committing the POST.  Without this filter, every local profile
    // or model switch triggers a redundant GET that can return stale
    // data during replication lag, causing "profile no longer exists"
    // fallout that triggers another POST (null), creating a feedback
    // loop.
    if (_lastSettingsPostAtMs != null) {
      final msSincePost =
          DateTime.now().millisecondsSinceEpoch - _lastSettingsPostAtMs!;
      if (msSincePost < Sync._settingsEchoFilterWindowMs) {
        logger.debug(
          '[Sync] suppressing account-update echo '
          '(settings POSTed ${msSincePost}ms ago)',
        );
        return;
      }
    }
    logger.info('Account update received');
    profileSync.invalidate();
    settingsSync.invalidate();
  }

  /// Handle machine update
  void _handleUpdateMachine(Map<String, dynamic> data) {
    final machineId = data['id'] as String?;
    if (machineId == null) return;

    // Apply delta patch directly to the in-memory machine for unencrypted
    // fields (active, activeAt).  This updates the UI immediately without
    // waiting for a debounced HTTP fetch, which fixes the "Machine is offline"
    // false-positive when createSession is called shortly after a machine
    // comes online.
    final machine = _machines[machineId];
    if (machine != null) {
      final active = data['active'] as bool?;
      final activeAt = data['activeAt'] is int
          ? data['activeAt'] as int
          : data['activeAt'] is double
          ? (data['activeAt'] as double).toInt()
          : null;
      final updatedAt = data['updatedAt'] is int
          ? data['updatedAt'] as int
          : data['updatedAt'] is double
          ? (data['updatedAt'] as double).toInt()
          : null;
      final seq = data['seq'] is int
          ? data['seq'] as int
          : data['seq'] is double
          ? (data['seq'] as double).toInt()
          : null;

      if (active != null || activeAt != null) {
        _machines[machineId] = machine.copyWith(
          active: active ?? machine.active,
          activeAt: activeAt ?? machine.activeAt,
          updatedAt: updatedAt ?? machine.updatedAt,
          seq: seq ?? machine.seq,
        );
        _notifyDataChanged({SyncDomain.machines});
      }
    }

    // Schedule a debounced refresh as a safety net for encrypted fields
    // (metadata, daemonState) that we can't decrypt inline here.
    _scheduleMachinesRefresh();

    logger.info('Machine update received: $machineId');
  }

  void _scheduleMachinesRefresh() {
    _machinesRefreshDebounceTimer?.cancel();
    _machinesRefreshDebounceTimer = Timer(
      Sync._machinesRefreshDebounce,
      () => unawaited(_flushScheduledMachinesRefresh()),
    );
  }

  Future<void> _flushScheduledMachinesRefresh() async {
    _machinesRefreshDebounceTimer?.cancel();
    _machinesRefreshDebounceTimer = null;
    _pendingUpdateMachineIds.clear();
    await machinesSync.invalidateAndAwait();
  }

  /// Handle new artifact update
  void _handleNewArtifact(Map<String, dynamic> data) {
    logger.info('New artifact received');
    _scheduleArtifactsSyncRefresh();
  }

  /// Handle artifact update
  void _handleUpdateArtifact(Map<String, dynamic> data) {
    logger.info('Artifact update received');
    _scheduleArtifactsSyncRefresh();
  }

  /// Handle artifact deletion
  void _handleDeleteArtifact(Map<String, dynamic> data) {
    logger.info('Artifact deletion received');
    _scheduleArtifactsSyncRefresh();
  }

  void _scheduleArtifactsSyncRefresh() {
    _artifactsSyncDebounceTimer?.cancel();
    _artifactsSyncDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _artifactsSyncDebounceTimer = null;
      artifactsSync.invalidate();
    });
  }

}
