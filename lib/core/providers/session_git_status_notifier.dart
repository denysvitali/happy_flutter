import 'package:riverpod/riverpod.dart';

import '../models/machine.dart';
import '../services/sync_service.dart';
import '_shared.dart';

class SessionGitStatusNotifier extends Notifier<Map<String, GitStatus>> {
  int _lastDataChangeCounter = -1;

  @override
  Map<String, GitStatus> build() => {};

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.domainChangeCounter(SyncDomain.gitStatus);
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.sessionGitStatus;
    if (mapValuesIdentical(state, next)) return;
    state = Map<String, GitStatus>.from(next);
  }

  Future<void> refreshFromSync() => refreshSyncDomain(
        invalidate: () => sync.sessionGitStatusSync,
        name: 'git status',
        reload: loadFromSync,
      );

  void setGitStatus(String sessionId, GitStatus status) {
    if (identical(state[sessionId], status)) return;
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
