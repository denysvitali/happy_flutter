import 'package:riverpod/riverpod.dart';

import '../models/machine.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';
class SessionGitStatusNotifier extends Notifier<Map<String, GitStatus>> {
  int _lastDataChangeCounter = -1;

  @override
  Map<String, GitStatus> build() => {};

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.dataChangeCounter;
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.sessionGitStatus;
    // Fast path: check length first, then use identical() for each value
    if (state.length == next.length) {
      var changed = false;
      next.forEach((key, value) {
        if (!identical(state[key], value)) {
          changed = true;
        }
      });
      if (!changed) return;
    }
    state = Map<String, GitStatus>.from(next);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    try {
      await sync.sessionGitStatusSync.invalidateAndAwait();
    } catch (e, stack) {
      logger.warning('Failed to refresh git status', e, stack);
    }
    loadFromSync();
  }

  void setGitStatus(String sessionId, GitStatus status) {
    state = {...state, sessionId: status};
  }

  void clearGitStatus(String sessionId) {
    state = Map<String, GitStatus>.from(state)..remove(sessionId);
  }

  void setAllGitStatuses(Map<String, GitStatus> statuses) {
    state = Map<String, GitStatus>.from(statuses);
  }

  GitStatus? getGitStatus(String sessionId) => state[sessionId];

  void clear() {
    state = {};
  }
}

final sessionGitStatusNotifierProvider =
    NotifierProvider<SessionGitStatusNotifier, Map<String, GitStatus>>(() {
      return SessionGitStatusNotifier();
    });
