import 'package:riverpod/riverpod.dart';

import '../models/artifact.dart';
import '../models/machine.dart';
import '../models/session.dart';
import '../services/sync_service.dart';
import 'artifacts_notifier.dart';
import 'machines_notifier.dart';
import 'session_ui_state_notifier.dart';
import 'sessions_notifier.dart';

class _RecentSessionsCache {
  int? _signature;
  List<String> _sessionIds = const [];
  List<String> _machineIds = const [];
  final Map<String, List<String>> _pathsByMachine = {};

  void update(Map<String, Session> sessions) {
    final signature = _computeSessionsSignature(sessions);
    if (_signature == signature) {
      return;
    }

    final sessionList = sessions.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _sessionIds = sessionList.map((session) => session.id).toList(
      growable: false,
    );

    final seenMachines = <String>{};
    final machineIds = <String>[];
    final pathsByMachine = <String, List<String>>{};
    final seenPathsByMachine = <String, Set<String>>{};

    for (final session in sessionList) {
      final machineId = session.metadata?.machineId;
      if (machineId == null) continue;

      if (seenMachines.add(machineId)) {
        machineIds.add(machineId);
      }

      final path = session.metadata?.path;
      if (path == null || path.isEmpty) continue;
      final seenPaths = seenPathsByMachine.putIfAbsent(machineId, () => {});
      if (!seenPaths.add(path)) continue;
      pathsByMachine.putIfAbsent(machineId, () => []).add(path);
    }

    _signature = signature;
    _machineIds = List<String>.unmodifiable(machineIds);
    _pathsByMachine
      ..clear()
      ..addAll({
        for (final entry in pathsByMachine.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      });
  }

  List<String> get sessionIds => _sessionIds;
  List<String> get machineIds => _machineIds;

  List<String> pathsForMachine(String machineId) =>
      _pathsByMachine[machineId] ?? const [];
}

int _computeSessionsSignature(Map<String, Session> sessions) {
  var signature = sessions.length;
  for (final entry in sessions.entries) {
    final session = entry.value;
    signature = Object.hash(
      signature,
      entry.key,
      session.updatedAt,
      session.activeAt,
      session.presence,
      session.active,
      session.archived,
      session.metadata?.machineId,
      session.metadata?.path,
    );
  }
  return signature;
}

final _recentSessionsCache = _RecentSessionsCache();

final sessionByIdProvider = Provider.family<Session?, String>((ref, id) {
  return ref.watch(sessionsNotifierProvider.select((sessions) => sessions[id]));
});

final machineByIdProvider = Provider.family<Machine?, String>((ref, id) {
  return ref.watch(machinesNotifierProvider.select((machines) => machines[id]));
});

final recentSessionIdsProvider = Provider<List<String>>((ref) {
  final sessions = ref.watch(sessionsNotifierProvider);
  _recentSessionsCache.update(sessions);
  return _recentSessionsCache.sessionIds;
});

final recentMachineIdsProvider = Provider<List<String>>((ref) {
  final sessions = ref.watch(sessionsNotifierProvider);
  _recentSessionsCache.update(sessions);
  return _recentSessionsCache.machineIds;
});

final recentPathsForMachineProvider = Provider.family<List<String>, String>((
  ref,
  machineId,
) {
  final sessions = ref.watch(sessionsNotifierProvider);
  _recentSessionsCache.update(sessions);
  return _recentSessionsCache.pathsForMachine(machineId);
});

/// Identity-stable list of [Machine] values. Recomputes only when the
/// upstream map identity changes (i.e. when a machine is added/removed or
/// any field on any machine changes — `MachinesNotifier.loadFromSync` uses
/// `mapValuesIdentical` to skip no-op refreshes, so this provider only
/// emits when there's a real change).
final machinesListProvider = Provider<List<Machine>>((ref) {
  final machines = ref.watch(machinesNotifierProvider);
  return List<Machine>.unmodifiable(machines.values);
});

/// Identity-stable list of all [Session] values. Same caching guarantee as
/// [machinesListProvider]: only emits when the sessions map identity
/// actually changes.
final sessionsListProvider = Provider<List<Session>>((ref) {
  final sessions = ref.watch(sessionsNotifierProvider);
  return List<Session>.unmodifiable(sessions.values);
});

/// Identity-stable list of all [DecryptedArtifact] values.
final artifactsListProvider = Provider<List<DecryptedArtifact>>((ref) {
  final artifacts = ref.watch(artifactsNotifierProvider);
  return List<DecryptedArtifact>.unmodifiable(artifacts.values);
});

// ─── Phase 2: per-session UI state (hoisted from sync.* getters) ───

/// Per-session derived UI data: lastMessageTimestamp/Preview/Role,
/// unreadCount, hasOlderMessages, isLoadingOlderMessages,
/// isSessionReadyForMessages, sessionUsage. Watch this from widget
/// `build()` instead of calling `sync.getLastMessage*(id)` etc.
final sessionUiEntryProvider =
    Provider.family<SessionUiEntry, String>((ref, sessionId) {
  final state = ref.watch(sessionUiStateNotifierProvider);
  return state.bySessionId[sessionId] ?? SessionUiEntry.empty;
});

/// Set of session ids that have been optimistically archived
/// (deletion in flight) but not yet confirmed by the server.
final optimisticallyArchivedIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(
    sessionUiStateNotifierProvider.select((s) => s.optimisticallyArchivedIds),
  );
});

/// Number of currently-loaded orphan sidechain messages in a session —
/// messages whose `isSidechain` flag is set and whose parent Task is NOT
/// in the loaded window. These can otherwise be hidden by the
/// `_visibleCount = _pageSize` clamp when the chat is dominated by
/// top-level entries. The chat screen watches this provider to drive
/// the orphan-visibility banner.
///
/// Rebuilt whenever the messages domain counter ticks
/// ([SyncDomain.messages]); the per-session scan is O(n) and bounded by
/// the [_maxCachedMessages] (200) window.
final orphanCountForSessionProvider =
    Provider.family<int, String>((ref, sessionId) {
  // Force recompute on every messages-domain change. We deliberately
  // skip a structural-equals guard here: the scan is cheap and the
  // banner needs every change to update its label, including the
  // "just absorbed into a parent Task" transition from N→0.
  ref.watch(sessionUiStateNotifierProvider
      .select((s) => s.bySessionId[sessionId] ?? SessionUiEntry.empty));
  if (!sync.isInitialized) return 0;
  return sync.orphanCountForSession(sessionId);
});
