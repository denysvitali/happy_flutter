import 'package:riverpod/riverpod.dart';

import '../models/machine.dart';
import '../models/session.dart';
import 'machines_notifier.dart';
import 'sessions_notifier.dart';

final sessionByIdProvider = Provider.family<Session?, String>((ref, id) {
  return ref.watch(sessionsNotifierProvider.select((sessions) => sessions[id]));
});

final machineByIdProvider = Provider.family<Machine?, String>((ref, id) {
  return ref.watch(machinesNotifierProvider.select((machines) => machines[id]));
});

final recentSessionIdsProvider = Provider<List<String>>((ref) {
  final sessions = ref.watch(sessionsNotifierProvider);
  final sessionList = sessions.values.toList(growable: false)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sessionList.map((session) => session.id).toList(growable: false);
});

final recentMachineIdsProvider = Provider<List<String>>((ref) {
  final sessions = ref.watch(sessionsNotifierProvider);
  final seen = <String>{};
  final ids = <String>[];
  final sortedSessions = sessions.values.toList(growable: false)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  for (final session in sortedSessions) {
    final machineId = session.metadata?.machineId;
    if (machineId == null || seen.contains(machineId)) continue;
    seen.add(machineId);
    ids.add(machineId);
  }
  return ids;
});

final recentPathsForMachineProvider = Provider.family<List<String>, String>((
  ref,
  machineId,
) {
  final sessions = ref.watch(sessionsNotifierProvider);
  final seen = <String>{};
  final paths = <String>[];
  final sortedSessions = sessions.values.toList(growable: false)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  for (final session in sortedSessions) {
    if (session.metadata?.machineId != machineId) continue;
    final path = session.metadata?.path;
    if (path == null || path.isEmpty || seen.contains(path)) continue;
    seen.add(path);
    paths.add(path);
  }
  return paths;
});
