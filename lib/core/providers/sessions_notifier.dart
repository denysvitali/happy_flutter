import 'package:riverpod/riverpod.dart';

import '../models/session.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';
import '_shared.dart';

class SessionsNotifier extends Notifier<Map<String, Session>> {
  int _lastDataChangeCounter = 0;

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
    if (identical(state, next)) return;
    if (mapEquals(state, next)) return;
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
}

final sessionsNotifierProvider =
    NotifierProvider<SessionsNotifier, Map<String, Session>>(() {
      return SessionsNotifier();
    });
