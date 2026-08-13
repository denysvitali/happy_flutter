import 'dart:async' show unawaited;
import 'dart:collection';

import 'package:riverpod/riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/session.dart';
import '../services/logger_service.dart' show logger;
import '../services/pinned_sessions_storage.dart';
import '../services/session_folders_storage.dart';
import '../services/sync_service.dart';
import '../utils/session_utils.dart';
import '_shared.dart';

/// Immutable sessions map with its collection/grouping fingerprint prepared
/// before widgets observe it.
///
/// Session cards select their own row by id, while the parent collection only
/// needs fields that affect membership, search, grouping, or ordering. Keeping
/// that fingerprint on the published map avoids hashing every session inside
/// the sessions-list `build` selector on unrelated row updates.
class SessionCollectionSnapshot extends UnmodifiableMapView<String, Session> {
  factory SessionCollectionSnapshot(Map<String, Session> sessions) {
    if (sessions is SessionCollectionSnapshot) return sessions;
    final values = Map<String, Session>.from(sessions);
    return SessionCollectionSnapshot._(
      values,
      _computeCollectionRevision(values),
    );
  }

  SessionCollectionSnapshot._(super.sessions, this.collectionRevision);

  final int collectionRevision;
}

int _computeCollectionRevision(Map<String, Session> sessions) {
  return Object.hash(
    sessions.length,
    Object.hashAllUnordered(
      sessions.entries.map((entry) {
        final session = entry.value;
        final metadata = session.metadata;
        return Object.hashAll([
          entry.key,
          session.archived,
          session.active,
          session.presence,
          session.activeAt,
          session.updatedAt,
          session.lastMessageAt,
          session.folder,
          session.lifecycleStateCleartext,
          metadata?.name,
          metadata?.path,
          metadata?.machineId,
          metadata?.host,
          metadata?.homeDir,
          metadata?.summary?.text,
          metadata?.lifecycleState,
          metadata?.lifecycleStateSince,
          isSessionIdle(session),
        ]);
      }),
    ),
  );
}

class SessionsNotifier extends Notifier<Map<String, Session>> {
  int _lastDataChangeCounter = -1;
  Future<void>? _refreshInFlight;
  final _pinnedStorage = PinnedSessionsStorage.instance;
  final _foldersStorage = SessionFoldersStorage.instance;

  @override
  Map<String, Session> build() => SessionCollectionSnapshot(const {});

  void _publish(Map<String, Session> sessions) {
    state = SessionCollectionSnapshot(sessions);
  }

  void setSessions(List<Session> sessions) {
    _publish({for (final session in sessions) session.id: session});
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
      // Defensive: a malformed entry from storage (e.g. a typed Map
      // that the freezed copyWith cast rejects as `_pca<String>` in
      // release) used to take down the whole merge and leave the
      // sessions list stale. Skip the offending session and warn so
      // a future release can pinpoint the shape.
      try {
        if (pinned.contains(id) && !session.pinned) {
          updated = updated.copyWith(pinned: true);
        }
        final folder = folders[id];
        if (folder != null && session.folder != folder) {
          updated = updated.copyWith(folder: folder);
        }
      } catch (e, st) {
        logger.warning(
          'SessionsNotifier._mergeLocalState: copyWith failed for $id '
          '— skipping local-state merge. $e',
          e,
          st,
        );
        continue;
      }
      if (!identical(updated, session)) {
        nextState ??= Map<String, Session>.from(state);
        nextState[id] = updated;
      }
    }
    if (nextState != null) {
      _publish(nextState);
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
    try {
      _publish(next);
      _mergeLocalState();
    } catch (e, st) {
      // A session envelope that doesn't satisfy the model (e.g. a
      // wrapped type for a String? field) used to abort the whole
      // loadFromSync and leave the sessions list stale for the rest
      // of the app lifetime. Capture the offending shape so the next
      // GlitchTip event carries the real culprit, then keep the
      // previous state intact.
      logger.warning(
        'SessionsNotifier.loadFromSync: merge failed, keeping previous state. '
        '$e',
        e,
        st,
      );
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: st,
          hint: Hint.withMap({
            'source': 'loadFromSync',
            'sessionCount': next.length,
          }),
        ),
      );
    }
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
    final future =
        () async {
          try {
            await sync.refreshSessionsListData(
              includeMachines: includeMachines,
            );
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
    _publish(const {});
  }

  Session? getSession(String id) => state[id];

  /// Removes [id] from state immediately, then confirms with the server.
  /// Rolls back on failure and logs a warning. Returns whether the server
  /// accepted the deletion.
  Future<bool> optimisticDelete(String id) async {
    final snapshot = state;
    final session = snapshot[id];
    if (session != null && !await _cleanupKubernetesSession(session)) {
      return false;
    }
    _publish(Map<String, Session>.from(state)..remove(id));
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
    final cleanupResults = await Future.wait(
      ids.map((id) async {
        final session = snapshot[id];
        return session == null || await _cleanupKubernetesSession(session);
      }),
    );
    final cleanupFailed = <String>{
      for (var i = 0; i < ids.length; i++)
        if (!cleanupResults[i]) ids[i],
    };
    final deletableIds = ids
        .where((id) => !cleanupFailed.contains(id))
        .toList();
    _publish(
      Map<String, Session>.from(state)
        ..removeWhere((id, _) => deletableIds.contains(id)),
    );
    final results = await Future.wait(deletableIds.map(sync.deleteSession));
    var failCount = cleanupFailed.length;
    for (var i = 0; i < deletableIds.length; i++) {
      if (!results[i]) failCount++;
    }
    if (failCount > 0) {
      // Restore only the ones that failed.
      for (var i = 0; i < deletableIds.length; i++) {
        final id = deletableIds[i];
        if (!results[i] && snapshot.containsKey(id)) {
          _publish({...state, id: snapshot[id]!});
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
    // Short-circuit when already pinned — avoids an unnecessary state
    // assignment and the resulting rebuild for every watcher.
    if (!session.pinned) {
      _publish(
        Map<String, Session>.from(state)..[id] = session.copyWith(pinned: true),
      );
    }
    await _pinnedStorage.pinSession(id);
  }

  /// Unpins [id] locally. No server sync.
  Future<void> unpinSession(String id) async {
    final session = state[id];
    if (session == null) return;
    if (session.pinned) {
      _publish(
        Map<String, Session>.from(state)
          ..[id] = session.copyWith(pinned: false),
      );
    }
    await _pinnedStorage.unpinSession(id);
  }

  /// Assigns [folder] to [id] locally. No server sync.
  Future<void> setSessionFolder(String id, String? folder) async {
    final session = state[id];
    if (session == null) return;
    if (session.folder != folder) {
      _publish(
        Map<String, Session>.from(state)
          ..[id] = session.copyWith(folder: folder),
      );
    }
    if (folder != null) {
      await _foldersStorage.setFolder(id, folder);
    } else {
      await _foldersStorage.removeSession(id);
    }
  }

  /// Archive a session on the server. Unarchiving is not supported by the
  /// current sync API; passing [archived] = false is a no-op.
  Future<void> markSessionArchived(String id, bool archived) async {
    if (!sync.isInitialized || !archived) return;
    final session = state[id];
    if (session != null && !await _cleanupKubernetesSession(session)) {
      throw StateError('Failed to clean up Kubernetes session resources');
    }
    sync.markSessionArchived(id);
  }

  Future<bool> _cleanupKubernetesSession(Session session) async {
    final metadata = session.metadata;
    final machineId = metadata?.machineId;
    if (!session.isKubernetesSession ||
        machineId == null ||
        machineId.isEmpty) {
      return true;
    }
    try {
      final response = await sync.machineKillSessionPod(
        machineId: machineId,
        sessionId: session.id,
      );
      return response.success;
    } catch (error, stack) {
      logger.warning(
        'Failed to clean Kubernetes resources for ${session.id}',
        error,
        stack,
      );
      return false;
    }
  }

  /// Create a new session.
  Future<String> createSession({
    required String machineId,
    required String path,
    required String agent,
    String? profileId,
    String? modelMode,
    String? spawnBackend,
    String? repoUrl,
    String? repoRef,
    String? repoCommit,
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    return sync.createSession(
      machineId: machineId,
      path: path,
      agent: agent,
      profileId: profileId,
      modelMode: modelMode,
      spawnBackend: spawnBackend,
      repoUrl: repoUrl,
      repoRef: repoRef,
      repoCommit: repoCommit,
    );
  }

  /// Create a worktree for a session.
  Future<String> createWorktree({
    required String machineId,
    required String basePath,
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    return sync.createWorktree(machineId: machineId, basePath: basePath);
  }
}

final sessionsNotifierProvider =
    NotifierProvider<SessionsNotifier, Map<String, Session>>(() {
      return SessionsNotifier();
    });
