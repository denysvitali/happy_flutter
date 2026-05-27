import 'package:riverpod/riverpod.dart';

import '../models/session.dart';
import '../services/logger_service.dart' show logger;
import '../services/pinned_sessions_storage.dart';
import '../services/session_folders_storage.dart';
import '../services/sync_service.dart';
import '_shared.dart';

class SessionsNotifier extends Notifier<Map<String, Session>> {
  int _lastDataChangeCounter = -1;
  Future<void>? _refreshInFlight;
  final _pinnedStorage = PinnedSessionsStorage.instance;
  final _foldersStorage = SessionFoldersStorage.instance;

  @override
  Map<String, Session> build() => {};

  void setSessions(List<Session> sessions) {
    state = {for (final session in sessions) session.id: session};
    _mergeLocalState();
  }

  void _mergeLocalState() {
    final pinned = _pinnedStorage.getPinned();
    final folders = _foldersStorage.getAllFolders();
    if (pinned.isEmpty && folders.isEmpty) return;
    Map<String, Session>? nextState;
    for (final id in {...pinned, ...folders.keys}) {
      final source = nextState ?? state;
      final session = source[id];
      if (session == null) continue;
      var updated = session;
      if (pinned.contains(id) && !session.pinned) {
        updated = updated.copyWith(pinned: true);
      }
      final folder = folders[id];
      if (folder != null && session.folder != folder) {
        updated = updated.copyWith(folder: folder);
      }
      if (!identical(updated, session)) {
        nextState ??= Map<String, Session>.from(state);
        nextState[id] = updated;
      }
    }
    if (nextState != null) {
      state = nextState;
    }
  }

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.domainChangeCounter(SyncDomain.sessions);
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.sessions;
    // sync.sessions returns Map.unmodifiable() which creates a new wrapper
    // each time, so identical() on the maps themselves is useless — but
    // per-entry identical() catches the common no-op refresh.
    if (mapValuesIdentical(state, next)) return;
    state = Map<String, Session>.from(next);
    _mergeLocalState();
  }

  /// Reload session state from sync.
  /// When [includeMachines] is true, refreshes both sessions and machines
  /// through a single batched sync call.
  Future<void> refreshFromSync({bool includeMachines = false}) {
    if (!sync.isInitialized) {
      return Future<void>.value();
    }
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = () async {
      try {
        await sync.refreshSessionsListData(includeMachines: includeMachines);
      } catch (e, stack) {
        logger.warning('Failed to refresh sessions', e, stack);
      }
      loadFromSync();
    }().whenComplete(() {
      _refreshInFlight = null;
    });

    _refreshInFlight = future;
    return future;
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
    } catch (e, stack) {
      state = snapshot;
      logger.warning(
        'OptimisticMutation: deleteSession($id) failed, rolled back',
        e,
        stack,
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

  /// Pins [id] locally. No server sync.
  Future<void> pinSession(String id) async {
    final session = state[id];
    if (session == null) return;
    state = {...state, id: session.copyWith(pinned: true)};
    await _pinnedStorage.pinSession(id);
  }

  /// Unpins [id] locally. No server sync.
  Future<void> unpinSession(String id) async {
    final session = state[id];
    if (session == null) return;
    state = {...state, id: session.copyWith(pinned: false)};
    await _pinnedStorage.unpinSession(id);
  }

  /// Assigns [folder] to [id] locally. No server sync.
  Future<void> setSessionFolder(String id, String? folder) async {
    final session = state[id];
    if (session == null) return;
    state = {...state, id: session.copyWith(folder: folder)};
    if (folder != null) {
      await _foldersStorage.setFolder(id, folder);
    } else {
      await _foldersStorage.removeSession(id);
    }
  }
}

final sessionsNotifierProvider =
    NotifierProvider<SessionsNotifier, Map<String, Session>>(() {
      return SessionsNotifier();
    });
