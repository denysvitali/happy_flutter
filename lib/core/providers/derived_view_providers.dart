import 'package:riverpod/riverpod.dart';

import '../models/machine.dart';
import '../models/session.dart';
import 'machines_notifier.dart';
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
