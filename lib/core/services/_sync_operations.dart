part of 'sync_service.dart';

extension SyncOperations on Sync {
  /// Forward settings sync to [SettingsManager].
  Future<void> syncSettings() async {
    await settingsManager?.syncSettings();
  }

  /// Forward purchases sync to [SettingsManager].
  Future<void> syncPurchases() async {
    await settingsManager?.syncPurchases();
  }

  /// Forward profile fetch to [SettingsManager].
  Future<void> fetchProfile() async {
    await settingsManager?.fetchProfile();
  }

  /// Forward native update fetch to [SettingsManager].
  Future<void> fetchNativeUpdate() async {
    await settingsManager?.fetchNativeUpdate();
  }

  /// Forward push-token sync to [SettingsManager].
  Future<void> syncPushToken() async {
    await settingsManager?.syncPushToken();
  }

  /// Refresh machines from server
  Future<void> refreshMachines() async {
    // Route through machinesSync so concurrent calls are coalesced rather
    // than firing two parallel GET /v1/machines requests.
    await machinesSync.invalidateAndAwait();
  }

  /// Refresh sessions from server
  Future<void> refreshSessions() async {
    await sessionsSync.invalidateAndAwait();
  }

  /// Refreshes session-list domain syncs in one bounded operation.
  ///
  /// `sessions` is always refreshed because it is needed for the Sessions
  /// tab's primary data model. `machines` is optional and intentionally
  /// deferred to avoid competing with the first session paint when called
  /// during screen init.
  Future<void> refreshSessionsListData({
    bool includeMachines = false,
    bool deferMachineRefresh = true,
  }) {
    if (!isInitialized) {
      return Future.value();
    }

    final inFlight = _sessionListRefreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final futures = <Future<void>>[sessionsSync.invalidateAndAwait()];
    if (includeMachines) {
      if (deferMachineRefresh) {
        futures.add(
          Future<void>.delayed(
            Sync._sessionListMachineRefreshDelay,
            () => machinesSync.invalidateAndAwait(),
          ),
        );
      } else {
        futures.add(machinesSync.invalidateAndAwait());
      }
    }

    final task = Future.wait(futures).whenComplete(() {
      _sessionListRefreshInFlight = null;
    });

    _sessionListRefreshInFlight = task;
    return task;
  }

  /// Mark a session as optimistically archived.
  ///
  /// Call this after a successful archive API call. The session will be
  /// filtered from the active list until the server confirms with
  /// `active: false`. This prevents the "archive then reappear" bug caused
  /// by server replication lag.
  void markSessionArchived(String sessionId) {
    _optimisticallyArchivedSessions.add(sessionId);
    _notifyDataChanged({SyncDomain.sessions});
  }

  /// Mark a session as optimistically unarchived.
  ///
  /// Call this after a successful unarchive API call. Removes the session
  /// from the optimistic archive filter so it can appear in the active
  /// list.
  void markSessionUnarchived(String sessionId) {
    _optimisticallyArchivedSessions.remove(sessionId);
    _notifyDataChanged({SyncDomain.sessions});
  }

  /// Returns whether a session is optimistically archived.
  ///
  /// Use this to filter sessions from the active list.
  bool isSessionOptimisticallyArchived(String sessionId) {
    return _optimisticallyArchivedSessions.contains(sessionId);
  }

  /// Returns a copy of all optimistically archived session IDs.
  ///
  /// Use this for filtering in widget build methods.
  Set<String> getOptimisticallyArchivedIds() {
    return Set<String>.from(_optimisticallyArchivedSessions);
  }

  /// Delete a session.
  Future<bool> deleteSession(String sessionId) async {
    try {
      final api = ApiClient();
      final response = await api.delete('/v1/sessions/$sessionId');
      if (!api.isSuccess(response)) {
        return false;
      }

      _handleDeleteSession(<String, dynamic>{'sid': sessionId});
      return true;
    } catch (error, stack) {
      logger.error('Failed to delete session $sessionId', error, stack);
      return false;
    }
  }
}
