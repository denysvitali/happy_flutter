import 'package:riverpod/riverpod.dart';

import '../models/workflow_run.dart';
import '../services/sync_service.dart';

abstract interface class WorkflowsRepository {
  Map<String, List<WorkflowRun>> get workflows;

  Future<void> refreshRelevantSessions();

  Future<void> refreshSession(String sessionId);

  Future<WorkflowRun?> fetchSnapshot(String sessionId, String runId);

  /// Whether the daemon for [sessionId] has reported it does not support
  /// listing workflow runs.
  bool isWorkflowListUnsupportedForSession(String sessionId);
}

class SyncWorkflowsRepository implements WorkflowsRepository {
  const SyncWorkflowsRepository(this._sync);

  final Sync _sync;

  @override
  Map<String, List<WorkflowRun>> get workflows => _sync.workflowsBySession;

  @override
  Future<void> refreshRelevantSessions() => _sync.refreshAllWorkflows();

  @override
  Future<void> refreshSession(String sessionId) =>
      _sync.refreshWorkflowsForSession(sessionId);

  @override
  Future<WorkflowRun?> fetchSnapshot(String sessionId, String runId) =>
      _sync.fetchWorkflowSnapshot(sessionId, runId);

  @override
  bool isWorkflowListUnsupportedForSession(String sessionId) =>
      _sync.isWorkflowListUnsupportedForSession(sessionId);
}

final workflowsRepositoryProvider = Provider<WorkflowsRepository>(
  (ref) => SyncWorkflowsRepository(sync),
);
