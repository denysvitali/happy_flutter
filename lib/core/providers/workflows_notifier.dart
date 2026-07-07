import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../models/workflow_run.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

/// Per-session workflow run state mirrored from the daemon.
///
/// Listens to [Sync.onWorkflowsChanged] and exposes the in-memory map via
/// [state]. Mutations call through to the Sync RPC wrappers and rely on the
/// resulting `workflow-list` refresh to update local state.
class WorkflowsNotifier extends Notifier<Map<String, List<WorkflowRun>>> {
  StreamSubscription<String>? _sub;
  int _lastChangeCounter = -1;

  @override
  Map<String, List<WorkflowRun>> build() {
    _sub = sync.onWorkflowsChanged.listen(_handleWorkflowsChanged);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    return <String, List<WorkflowRun>>{};
  }

  void _handleWorkflowsChanged(String sessionId) {
    loadFromSync();
  }

  /// Instant read from in-memory sync state.
  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.domainChangeCounter(SyncDomain.workflows);
    if (counter == _lastChangeCounter) return;
    _lastChangeCounter = counter;
    final next = sync.workflowsBySession;
    if (_mapsIdentical(state, next)) return;
    state = Map<String, List<WorkflowRun>>.from(
      next.map(
        (key, value) => MapEntry(
          key,
          List<WorkflowRun>.unmodifiable(value),
        ),
      ),
    );
  }

  /// Hydrate in-memory workflow state from MMKV and publish to listeners.
  bool hydrateFromCache() {
    if (!sync.isInitialized) return false;
    sync.hydrateAllWorkflowsFromCache();
    loadFromSync();
    return sync.workflowsBySession.values.any((w) => w.isNotEmpty);
  }

  /// Server-fetch + read. Best-effort — failures are logged and ignored.
  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) return;
    try {
      await sync.refreshAllWorkflows();
    } catch (e, st) {
      logger.warning('WorkflowsNotifier.refreshFromSync failed: $e', e, st);
    }
    loadFromSync();
  }

  /// Returns the workflow runs for [sessionId] (empty list if none).
  List<WorkflowRun> workflowsForSession(String sessionId) =>
      state[sessionId] ?? const <WorkflowRun>[];

  /// Returns the count of workflow runs for [sessionId].
  int countForSession(String sessionId) {
    final list = state[sessionId];
    return list?.length ?? 0;
  }

  /// Fetch a single workflow snapshot by [runId].
  Future<WorkflowRun?> fetchWorkflowSnapshot(
    String sessionId,
    String runId,
  ) {
    return sync.fetchWorkflowSnapshot(sessionId, runId);
  }

  /// Per-session map identity check that ignores outer wrapper
  /// differences (e.g. `Map.unmodifiable`).
  bool _mapsIdentical(
    Map<String, List<WorkflowRun>> a,
    Map<String, List<WorkflowRun>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) return false;
      if (other.length != entry.value.length) return false;
      for (var i = 0; i < entry.value.length; i++) {
        if (entry.value[i] != other[i]) return false;
      }
    }
    return true;
  }
}

final workflowsNotifierProvider =
    NotifierProvider<WorkflowsNotifier, Map<String, List<WorkflowRun>>>(
  WorkflowsNotifier.new,
);
