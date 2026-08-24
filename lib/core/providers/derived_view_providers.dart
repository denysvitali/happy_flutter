import 'package:riverpod/riverpod.dart';

import '../models/artifact.dart';
import '../models/machine.dart';
import '../models/session.dart';
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

/// Per-id lookups are autoDispose: riverpod 3 keeps every non-autoDispose
/// family element alive for the process lifetime, so one element per
/// session/machine id ever rendered accumulated forever — slow heap growth
/// proportional to browsing (progressive-lag audit 2026-08-24).
final sessionByIdProvider = Provider.autoDispose.family<Session?, String>((
  ref,
  id,
) {
  return ref.watch(sessionsNotifierProvider.select((sessions) => sessions[id]));
});

final machineByIdProvider = Provider.autoDispose.family<Machine?, String>((
  ref,
  id,
) {
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

final recentPathsForMachineProvider = Provider.autoDispose
    .family<List<String>, String>((ref, machineId) {
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
    Provider.autoDispose.family<SessionUiEntry, String>((ref, sessionId) {
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
