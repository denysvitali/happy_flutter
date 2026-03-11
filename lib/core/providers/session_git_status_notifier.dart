import 'package:riverpod/riverpod.dart';

import '../models/machine.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';
import '_shared.dart';

class SessionGitStatusNotifier extends Notifier<Map<String, GitStatus>> {
  int _lastDataChangeCounter = 0;

  @override
  Map<String, GitStatus> build() => {};

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.dataChangeCounter;
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.sessionGitStatus;
    if (mapEquals(state, next)) return;
    state = Map<String, GitStatus>.from(next);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    try {
      await sync.sessionGitStatusSync.invalidateAndAwait();
    } catch (e) {
      logger.warning('Failed to refresh git status: $e');
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
