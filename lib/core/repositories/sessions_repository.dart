import 'package:riverpod/riverpod.dart';

import '../models/session.dart';
import '../services/sync_service.dart' show sync;
import '../sync/session_manager.dart';

/// Repository layer for sessions. Wraps [SessionManager] and provides
/// the public surface used by notifiers and screens.
class SessionsRepository {
  const SessionsRepository(this._manager);

  final SessionManager _manager;

  /// All sessions currently held in memory.
  Map<String, Session> get sessions => _manager.sessions;

  /// Refreshes session-list data, optionally including machines.
  Future<void> refreshSessionsListData({
    bool includeMachines = false,
  }) =>
      _manager.refreshSessionsListData(
        machinesSync: sync.machinesSync,
        includeMachines: includeMachines,
      );

  /// Deletes a session by ID.
  Future<bool> deleteSession(String sessionId) =>
      _manager.deleteSession(sessionId);

  /// Marks a session as archived.
  void markSessionArchived(String sessionId) =>
      _manager.markSessionArchived(sessionId);

  /// Returns the set of optimistically archived session IDs.
  Set<String> get optimisticallyArchivedIds =>
      _manager.getOptimisticallyArchivedIds();
}

/// Provider for the session manager managed by the sync singleton.
final sessionManagerProvider = Provider<SessionManager>(
  (ref) => sync.sessionManager!,
);

/// Provider for the sessions repository.
final sessionsRepositoryProvider = Provider<SessionsRepository>(
  (ref) => SessionsRepository(ref.read(sessionManagerProvider)),
);
