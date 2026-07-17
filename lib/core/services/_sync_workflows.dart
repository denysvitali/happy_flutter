part of 'sync_service.dart';

/// Workflows are multi-agent Claude Code tasks that run inside an active
/// session. The Flutter client mirrors the daemon's workflow snapshots via
/// session-scoped RPC calls and persists them per session in MMKV.
extension SyncWorkflows on Sync {
  static const int _maxBackgroundWorkflowSessions = 3;
  static const int _initialWorkflowBackoffMs = 5000;
  static const int _maxWorkflowBackoffMs = 5 * 60 * 1000;
  static const int _workflowUnsupportedCapabilityTtlMs = 5 * 60 * 1000;

  // ── State ──────────────────────────────────────────────────────────────

  /// Fires when the workflow runs for a session change (create / update /
  /// delete). Subscribers receive the sessionId so they can refresh only the
  /// affected view.
  Stream<String> get onWorkflowsChanged => _workflowsChangeController.stream;

  /// Read-only snapshot of the in-memory workflows map.
  Map<String, List<WorkflowRun>> get workflowsBySession =>
      Map.unmodifiable(_workflowsBySession);

  /// Returns the workflow runs for [sessionId] (empty list if none).
  List<WorkflowRun> workflowsForSession(String sessionId) => List.unmodifiable(
    _workflowsBySession[sessionId] ?? const <WorkflowRun>[],
  );

  // ── Hydration ──────────────────────────────────────────────────────────

  /// Restore cached workflows for [sessionId] from MMKV into the in-memory
  /// map. Called lazily on first read so cold start doesn't pay the decode
  /// cost for every session.
  void hydrateWorkflowsForSession(String sessionId) {
    if (_workflowsBySession.containsKey(sessionId)) return;
    final cached = WorkflowStorage.instance.load(sessionId);
    if (cached.isEmpty) return;
    _workflowsBySession[sessionId] = List<WorkflowRun>.unmodifiable(cached);
  }

  /// Hydrate in-memory workflow state from MMKV for every known session,
  /// then publish so [WorkflowsNotifier] subscribers see the cached state.
  void hydrateAllWorkflowsFromCache() {
    for (final sessionId in _sessions.keys) {
      hydrateWorkflowsForSession(sessionId);
    }
    _notifyDataChanged({SyncDomain.workflows});
    if (_workflowsBySession.isNotEmpty) {
      _notifyWorkflowsChanged(_workflowsBySession.keys.first);
    }
  }

  // ── RPC wrappers ─────────────────────────────────────────────────────────

  /// Fetch the workflow runs for [sessionId] from the daemon.
  ///
  /// Updates the in-memory mirror and persists the result. Malformed entries
  /// are skipped with a warning rather than poisoning the entire batch.
  Future<void> refreshWorkflowsForSession(String sessionId) {
    if (!isInitialized) return Future<void>.value();
    if (_isWorkflowCapabilityBlocked(sessionId) ||
        _isWorkflowRefreshBackedOff(sessionId)) {
      return Future<void>.value();
    }
    final existing = _workflowRefreshesInFlight[sessionId];
    if (existing != null) return existing;

    final refresh = _runWorkflowRefresh(sessionId);
    _workflowRefreshesInFlight[sessionId] = refresh;
    return refresh.whenComplete(() {
      if (identical(_workflowRefreshesInFlight[sessionId], refresh)) {
        _workflowRefreshesInFlight.remove(sessionId);
      }
    });
  }

  Future<void> _runWorkflowRefresh(String sessionId) async {
    dynamic raw;
    try {
      raw = await sessionRPC(
        sessionId,
        'workflow-list',
        const <String, dynamic>{},
      );
    } catch (e, st) {
      if (e is StateError &&
          e.message.contains('Session encryption not found')) {
        logger.debug(
          '[workflows] refreshWorkflowsForSession($sessionId) skipped — '
          'encryption not found',
        );
        return;
      }
      if (_isWorkflowListUnsupported(e)) {
        _workflowListUnsupportedCapabilities[
          _workflowCapabilityKey(sessionId)
        ] = DateTime.now().millisecondsSinceEpoch +
            (testWorkflowUnsupportedCapabilityTtl?.inMilliseconds ??
                _workflowUnsupportedCapabilityTtlMs);
        logger.debug(
          '[workflows] refreshWorkflowsForSession($sessionId) skipped — '
          'workflow-list unsupported',
        );
        _notifyWorkflowsChanged(sessionId);
        return;
      }
      if (e is SocketNotConnectedException ||
          Sync._isTransientConnectionError(e) ||
          Sync._isTransientRpcError(e) ||
          Sync._isRpcMethodNotAvailable(e)) {
        _recordWorkflowRefreshFailure(sessionId);
        logger.debug(
          '[workflows] refreshWorkflowsForSession($sessionId) skipped — '
          'transient connection failure: $e',
        );
        return;
      }
      logger.warning(
        '[workflows] refreshWorkflowsForSession($sessionId) failed: $e',
        e,
        st,
      );
      return;
    }
    if (raw is! Map) {
      logger.warning(
        '[workflows] workflow-list returned unexpected type '
        '${raw.runtimeType}',
      );
      return;
    }
    if (raw['ok'] == false) {
      final err = raw['error']?.toString() ?? 'unknown error';
      throw StateError('workflow-list failed: $err');
    }
    _clearWorkflowRefreshFailure(sessionId);
    final workflowsJson = raw['workflows'] ?? raw['runs'];
    if (workflowsJson is! List) {
      logger.warning(
        '[workflows] refreshWorkflowsForSession($sessionId) returned '
        'non-list "workflows" payload (${workflowsJson.runtimeType}); '
        'treating as empty',
      );
      _publishWorkflowsForSession(
        sessionId,
        const <WorkflowRun>[],
        notifyDataChanged: true,
      );
      return;
    }
    final workflows = _parseWorkflowRunList(
      sessionId: sessionId,
      workflowsJson: workflowsJson,
      source: 'refreshWorkflowsForSession',
    );
    _publishWorkflowsForSession(sessionId, workflows, notifyDataChanged: true);
  }

  /// Fetch a single workflow snapshot for [runId] in [sessionId].
  ///
  /// Returns the parsed [WorkflowRun] or `null` when the snapshot is missing
  /// or malformed. The in-memory mirror is updated so the UI sees the latest
  /// state without waiting for a `workflow-list` refresh.
  Future<WorkflowRun?> fetchWorkflowSnapshot(
    String sessionId,
    String runId,
  ) async {
    if (!isInitialized) return null;
    dynamic raw;
    try {
      raw = await sessionRPC(sessionId, 'workflow-read', <String, dynamic>{
        'runId': runId,
      });
    } catch (e, st) {
      logger.warning(
        '[workflows] fetchWorkflowSnapshot($sessionId, $runId) failed: $e',
        e,
        st,
      );
      return null;
    }
    if (raw is! Map) {
      logger.warning(
        '[workflows] workflow-read returned unexpected type '
        '${raw.runtimeType}',
      );
      return null;
    }
    if (raw['ok'] == false) {
      final err = raw['error']?.toString() ?? 'unknown error';
      throw StateError('workflow-read failed: $err');
    }
    var snapshotJson = raw['snapshot'] ?? raw['snapshot_json'] ?? raw['run'];
    if (snapshotJson is String) {
      try {
        snapshotJson = jsonDecode(snapshotJson);
      } catch (e, st) {
        logger.warning('[workflows] snapshot JSON decode failed: $e', e, st);
        return null;
      }
    }
    if (snapshotJson is! Map) {
      logger.warning(
        '[workflows] fetchWorkflowSnapshot($sessionId, $runId) missing '
        'snapshot payload',
      );
      return null;
    }
    final run = WorkflowRun.tryFromJson(
      Map<String, dynamic>.from(snapshotJson),
    );
    if (run == null) {
      logger.warning(
        '[workflows] fetchWorkflowSnapshot($sessionId, $runId) snapshot '
        'malformed',
      );
      return null;
    }
    _applyWorkflowSnapshot(sessionId, run);
    return run;
  }

  /// Refresh workflows for the visible session and a bounded number of the
  /// most-recent online sessions.
  ///
  /// Best-effort — sessions whose `sessionRPC` call fails are logged and
  /// skipped. Used by [WorkflowsNotifier.refreshFromSync].
  static const Duration _refreshAllWorkflowsDeadline = Duration(seconds: 10);

  Future<void> refreshAllWorkflows() async {
    if (!isInitialized) return;
    if (!_isSocketConnected()) {
      logger.debug(
        '[workflows] refreshAllWorkflows skipped — socket not connected',
      );
      return;
    }
    final sessionIds = _workflowRefreshCandidates();
    if (sessionIds.isEmpty) return;

    final deadline =
        testRefreshAllWorkflowsDeadline ?? _refreshAllWorkflowsDeadline;
    final startedAt = DateTime.now();
    for (final sessionId in sessionIds) {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= deadline) {
        logger.debug(
          '[workflows] refreshAllWorkflows deadline exceeded — '
          'skipping ${sessionIds.length - sessionIds.indexOf(sessionId)} '
          'remaining sessions',
        );
        break;
      }
      final remaining = deadline - elapsed;
      try {
        await refreshWorkflowsForSession(sessionId).timeout(
          remaining,
          onTimeout: () {
            logger.debug(
              '[workflows] refreshWorkflowsForSession($sessionId) hit '
              'refresh deadline — breaking out of refreshAllWorkflows',
            );
            throw TimeoutException(
              'refreshAllWorkflows deadline exceeded on $sessionId',
            );
          },
        );
      } on TimeoutException {
        break;
      } on StateError catch (e) {
        if (Sync._isRpcMethodNotAvailable(e)) {
          logger.debug(
            '[workflows] refreshWorkflowsForSession($sessionId) skipped — '
            'RPC unavailable',
          );
          continue;
        }
        if (Sync._isTransientRpcError(e)) {
          logger.debug(
            '[workflows] refreshWorkflowsForSession($sessionId) skipped — '
            'transient: $e',
          );
          break;
        }
        logger.warning(
          '[workflows] refreshWorkflowsForSession($sessionId) failed: $e',
          e,
        );
      } catch (e, st) {
        if (Sync._isTransientConnectionError(e)) {
          logger.debug(
            '[workflows] refreshWorkflowsForSession($sessionId) skipped — '
            'transient: $e',
          );
          break;
        }
        logger.warning(
          '[workflows] refreshWorkflowsForSession($sessionId) failed: $e',
          e,
          st,
        );
      }
    }
  }

  List<String> _workflowRefreshCandidates() {
    final candidates = <String>[];
    final visible = _visibleSessionId;
    if (visible != null && _sessions.containsKey(visible)) {
      candidates.add(visible);
    }

    final online =
        _sessions.values
            .where((session) => session.presence == 'online')
            .where((session) => session.id != visible)
            .toList(growable: false)
          ..sort((a, b) => b.activeAt.compareTo(a.activeAt));
    candidates.addAll(
      online.take(_maxBackgroundWorkflowSessions).map((session) => session.id),
    );
    return candidates;
  }

  String _workflowCapabilityKey(String sessionId) {
    final machineId = _sessions[sessionId]?.metadata?.machineId;
    return machineId == null || machineId.isEmpty
        ? 'session:$sessionId'
        : 'machine:$machineId';
  }

  bool _isWorkflowListUnsupported(Object error) {
    if (error is! StateError) return false;
    final message = error.message.toLowerCase();
    return message.contains('workflow-list not available') ||
        message.contains('workflow-list method not found') ||
        message.contains('rpc method workflow-list not available') ||
        message.contains('unknown method workflow-list');
  }

  bool _isWorkflowCapabilityBlocked(String sessionId) {
    final key = _workflowCapabilityKey(sessionId);
    final expiresAt = _workflowListUnsupportedCapabilities[key];
    if (expiresAt == null) return false;
    if (DateTime.now().millisecondsSinceEpoch >= expiresAt) {
      _workflowListUnsupportedCapabilities.remove(key);
      return false;
    }
    return true;
  }

  /// Whether the daemon for [sessionId] has told us it does not support
  /// `workflow-list`. Used by the UI to show a "workflows unavailable"
  /// indicator instead of a generic empty state.
  bool isWorkflowListUnsupportedForSession(String sessionId) =>
      _isWorkflowCapabilityBlocked(sessionId);

  bool _isWorkflowRefreshBackedOff(String sessionId) {
    final until = _workflowRefreshBackoffUntil[sessionId];
    if (until == null) return false;
    if (DateTime.now().millisecondsSinceEpoch >= until) {
      _workflowRefreshBackoffUntil.remove(sessionId);
      return false;
    }
    return true;
  }

  void _recordWorkflowRefreshFailure(String sessionId) {
    final failures = (_workflowRefreshFailureCount[sessionId] ?? 0) + 1;
    _workflowRefreshFailureCount[sessionId] = failures;
    final exponent = (failures - 1).clamp(0, 6).toInt();
    final multiplier = 1 << exponent;
    final delayMs = (_initialWorkflowBackoffMs * multiplier)
        .clamp(_initialWorkflowBackoffMs, _maxWorkflowBackoffMs)
        .toInt();
    _workflowRefreshBackoffUntil[sessionId] =
        DateTime.now().millisecondsSinceEpoch + delayMs;
  }

  void _clearWorkflowRefreshFailure(String sessionId) {
    _workflowRefreshFailureCount.remove(sessionId);
    _workflowRefreshBackoffUntil.remove(sessionId);
  }

  // ── State mutations ─────────────────────────────────────────────────────

  void _applyWorkflowSnapshot(String sessionId, WorkflowRun run) {
    final existing = _workflowsBySession[sessionId] ?? const <WorkflowRun>[];
    final idx = existing.indexWhere((r) => r.runId == run.runId);
    final next = idx < 0
        ? <WorkflowRun>[...existing, run]
        : (<WorkflowRun>[...existing]..[idx] = run);
    _publishWorkflowsForSession(sessionId, next, notifyDataChanged: true);
  }

  List<WorkflowRun> _parseWorkflowRunList({
    required String sessionId,
    required List<dynamic> workflowsJson,
    required String source,
  }) {
    final workflows = <WorkflowRun>[];
    for (final entry in workflowsJson) {
      if (entry is Map) {
        final run = WorkflowRun.tryFromJson(Map<String, dynamic>.from(entry));
        if (run != null) {
          workflows.add(run);
        } else {
          logger.warning(
            '[workflows] $source($sessionId) skipping malformed entry',
          );
        }
      }
    }
    return workflows;
  }

  void _publishWorkflowsForSession(
    String sessionId,
    List<WorkflowRun> workflows, {
    bool notifyDataChanged = false,
  }) {
    final next = List<WorkflowRun>.unmodifiable(workflows);
    _workflowsBySession[sessionId] = next;
    WorkflowStorage.instance.save(sessionId, next);
    _notifyWorkflowsChanged(sessionId);
    if (notifyDataChanged) {
      _notifyDataChanged({SyncDomain.workflows});
    }
  }

  void _notifyWorkflowsChanged(String sessionId) {
    if (!_workflowsChangeController.isClosed) {
      _workflowsChangeController.add(sessionId);
    }
  }

  /// Clear all workflows for [sessionId] from in-memory state and MMKV.
  void clearWorkflowsForSession(String sessionId) {
    _workflowsBySession.remove(sessionId);
    WorkflowStorage.instance.clear(sessionId);
    _notifyWorkflowsChanged(sessionId);
    _notifyDataChanged({SyncDomain.workflows});
  }

  /// Clear all in-memory workflow state. Test-only.
  @visibleForTesting
  void testClearAllWorkflows() {
    _workflowsBySession.clear();
  }

  @visibleForTesting
  List<String> testWorkflowRefreshCandidates() => _workflowRefreshCandidates();

  @visibleForTesting
  bool testIsWorkflowRefreshCapabilityBlocked(String sessionId) =>
      _isWorkflowCapabilityBlocked(sessionId);

  @visibleForTesting
  void testResetWorkflowRefreshPolicy() {
    _workflowRefreshesInFlight.clear();
    _workflowListUnsupportedCapabilities.clear();
    _workflowRefreshBackoffUntil.clear();
    _workflowRefreshFailureCount.clear();
  }
}
