import 'package:riverpod/riverpod.dart';

import '../models/session.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

class SessionsNotifier extends Notifier<Map<String, Session>> {
  int _lastDataChangeCounter = -1;

  @override
  Map<String, Session> build() => {};

  void setSessions(List<Session> sessions) {
    state = {for (final session in sessions) session.id: session};
  }

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.dataChangeCounter;
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.sessions;
    // sync.sessions returns Map.unmodifiable() which creates a new wrapper
    // each time, so identical() check is skipped. Direct map comparison is
    // more efficient than mapEquals() for most cases.
    if (state.length == next.length) {
      var changed = false;
      next.forEach((key, value) {
        if (!identical(state[key], value)) {
          changed = true;
        }
      });
      if (!changed) return;
    }
    state = Map<String, Session>.from(next);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    try {
      await sync.refreshSessions();
    } catch (e) {
      logger.warning('Failed to refresh sessions: $e');
    }
    loadFromSync();
  }

  void clear() {
    state = {};
  }

  Session? getSession(String id) => state[id];

  /// Removes [id] from state immediately, then confirms with the server.
  /// Rolls back on failure and logs a warning. Returns whether the server
  /// accepted the deletion.
  Future<bool> optimisticDelete(String id) async {
    final snapshot = state;
    state = Map<String, Session>.from(state)..remove(id);
    try {
      final ok = await sync.deleteSession(id);
      if (!ok) {
        state = snapshot;
        return false;
      }
      return true;
    } catch (e) {
      state = snapshot;
      logger.warning(
        'OptimisticMutation: deleteSession($id) failed,'
        ' rolled back — error: $e',
      );
      return false;
    }
  }

  /// Optimistically removes all [ids] from state immediately, then confirms
  /// each with the server. Restores any that failed. Returns the number of
  /// sessions that failed to delete.
  Future<int> optimisticBatchDelete(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final snapshot = state;
    state = Map<String, Session>.from(state)
      ..removeWhere((id, _) => ids.contains(id));
    final results = await Future.wait(ids.map(sync.deleteSession));
    var failCount = 0;
    for (var i = 0; i < ids.length; i++) {
      if (!results[i]) failCount++;
    }
    if (failCount > 0) {
      // Restore only the ones that failed.
      for (var i = 0; i < ids.length; i++) {
        if (!results[i] && snapshot.containsKey(ids[i])) {
          state = {...state, ids[i]: snapshot[ids[i]]!};
        }
      }
    }
    if (failCount > 0) {
      logger.warning(
        'OptimisticMutation: batchDelete($ids) —'
        ' $failCount failed, rolled back',
      );
    }
    return failCount;
  }
}

final sessionsNotifierProvider =
    NotifierProvider<SessionsNotifier, Map<String, Session>>(() {
      return SessionsNotifier();
    });
