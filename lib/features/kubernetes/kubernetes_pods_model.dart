import 'package:flutter/foundation.dart' show immutable;

import '../../core/models/machine.dart';
import '../../core/models/session.dart';
import '../../core/providers/pod_operations_notifier.dart';
import '../../core/rpc/rpc_types.dart';
import '../../core/utils/session_utils.dart' show getSessionName;
import 'kubernetes_pod_state.dart';

/// One Kubernetes session pod on the pods screen: the daemon's live pod
/// report, the catalog session it belongs to, or both.
@immutable
class KubernetesPodEntry {
  const KubernetesPodEntry({
    required this.machineId,
    this.session,
    this.pod,
    this.live = true,
    this.operation,
  }) : assert(session != null || pod != null);

  final String? machineId;
  final Session? session;
  final SessionPod? pod;

  /// False when the owning daemon could not be asked; the entry then shows
  /// the last state the session metadata recorded.
  final bool live;

  /// The app-local pod operation recorded for this pod, if any. While it is
  /// pending or succeeded-but-unconfirmed its effect is drawn over the
  /// daemon's report; a failed one only adds its error.
  final PodOperation? operation;

  KubernetesPodEntry withOperation(PodOperation? operation) =>
      KubernetesPodEntry(
        machineId: machineId,
        session: session,
        pod: pod,
        live: live,
        operation: operation,
      );

  /// The state the daemon (or session metadata) last reported.
  SessionPodDisplayState get reportedState =>
      pod?.displayState ?? session!.podDisplayState;

  String get key {
    final id = pod?.sessionId ?? session?.id ?? '';
    return id.isNotEmpty ? '$machineId/$id' : '$machineId/pod:$podName';
  }

  /// Displayed state: a succeeded pause/resume shows its target state until
  /// the daemon's report catches up.
  SessionPodDisplayState get state {
    final op = operation;
    if (op != null && op.isSucceeded && op.expectedState != null) {
      return op.expectedState!;
    }
    return reportedState;
  }

  /// Whether an operation for this pod is still syncing.
  bool get busy => operation?.isPending ?? false;

  String get podName {
    final reported = pod?.podName ?? '';
    return reported.isNotEmpty ? reported : session?.metadata?.podName ?? '';
  }

  String get namespace {
    final reported = pod?.namespace ?? '';
    return reported.isNotEmpty ? reported : session?.metadata?.namespace ?? '';
  }

  String get repoUrl {
    final reported = pod?.repoUrl ?? '';
    return reported.isNotEmpty ? reported : session?.metadata?.repoUrl ?? '';
  }

  String get repoRef {
    final reported = pod?.repoRef ?? '';
    return reported.isNotEmpty ? reported : session?.metadata?.repoRef ?? '';
  }

  /// Reason/message the daemon reported, e.g. `CrashLoopBackOff · ...`.
  String get detail {
    final current = pod;
    if (current == null) return '';
    return [
      current.reason,
      current.message,
    ].where((value) => value.isNotEmpty).join(' · ');
  }

  /// Session the pod belongs to, from the daemon report or the catalog;
  /// empty for a pod with no session label.
  String get sessionId {
    final reported = pod?.sessionId ?? '';
    return reported.isNotEmpty ? reported : session?.id ?? '';
  }

  /// Whether pod actions (pause, resume, kill) can be sent: they are keyed
  /// by session on the owning daemon.
  bool get canControl =>
      live && !busy && sessionId.isNotEmpty && (machineId?.isNotEmpty ?? false);

  /// The live pod report when the pod is actually running; null for paused,
  /// archived, or last-known entries, whose usage would be meaningless.
  SessionPod? get runningPod {
    final current = pod;
    if (current == null || !live || current.paused || current.archived) {
      return null;
    }
    // A pause that succeeded but is not reported yet.
    if (state == SessionPodDisplayState.paused) return null;
    return current;
  }

  /// Title of the owning session, or null for an untracked pod.
  String? get sessionTitle {
    final owner = session;
    return owner == null ? null : getSessionName(owner);
  }
}

/// Machines whose daemon should be asked for session pods: online machines
/// that advertise the Kubernetes spawn backend or own a live Kubernetes
/// session.
List<String> kubernetesPodMachineIds({
  required Map<String, Machine> machines,
  required Map<String, Session> sessions,
  required int nowMs,
}) {
  final ids = <String>{
    for (final machine in machines.values)
      if (machine.isOnlineAt(nowMs) &&
          (machine.metadata?.spawnBackends?.contains('kubernetes') ?? false))
        machine.id,
  };
  for (final session in sessions.values) {
    if (!isLiveKubernetesSession(session)) continue;
    final machineId = session.metadata?.machineId;
    if (machineId == null || machineId.isEmpty) continue;
    if (machines[machineId]?.isOnlineAt(nowMs) ?? false) ids.add(machineId);
  }
  return ids.toList()..sort();
}

int _stateRank(SessionPodDisplayState state) => switch (state) {
  SessionPodDisplayState.failed => 0,
  SessionPodDisplayState.scheduling => 1,
  SessionPodDisplayState.ready => 2,
  SessionPodDisplayState.paused => 3,
  SessionPodDisplayState.archived => 4,
};

/// Merges the daemons' live pod lists with the session catalog.
///
/// A daemon that answered is authoritative for its machine: every pod it
/// reports is listed (including pods whose session left the catalog), and
/// a session it did not report has no pod. Live Kubernetes sessions on
/// machines that were not reachable fall back to their metadata and are
/// marked not [KubernetesPodEntry.live]. Archived pods are omitted.
List<KubernetesPodEntry> mergeKubernetesPods({
  required Map<String, Session> sessions,
  required Map<String, List<SessionPod>> podsByMachine,
}) {
  final entries = <KubernetesPodEntry>[];
  final seenSessionIds = <String>{};
  for (final MapEntry(key: machineId, value: pods) in podsByMachine.entries) {
    for (final pod in pods) {
      if (pod.archived) continue;
      final session = pod.sessionId.isEmpty ? null : sessions[pod.sessionId];
      if (pod.sessionId.isNotEmpty) seenSessionIds.add(pod.sessionId);
      entries.add(
        KubernetesPodEntry(machineId: machineId, session: session, pod: pod),
      );
    }
  }
  for (final session in sessions.values) {
    if (seenSessionIds.contains(session.id)) continue;
    if (!isLiveKubernetesSession(session)) continue;
    final machineId = session.metadata?.machineId;
    if (podsByMachine.containsKey(machineId)) continue;
    entries.add(
      KubernetesPodEntry(machineId: machineId, session: session, live: false),
    );
  }
  entries.sort(_compareEntries);
  return entries;
}

int _compareEntries(KubernetesPodEntry a, KubernetesPodEntry b) {
  final rank = _stateRank(a.state).compareTo(_stateRank(b.state));
  if (rank != 0) return rank;
  final title = (a.sessionTitle ?? a.podName).toLowerCase().compareTo(
    (b.sessionTitle ?? b.podName).toLowerCase(),
  );
  return title != 0 ? title : a.key.compareTo(b.key);
}

/// Draws app-local pod [operations] over merged daemon [entries].
///
/// Each entry picks up its operation; a kill that succeeded hides the entry
/// (the pod is gone, even if the daemon is still terminating it), and the
/// list is re-sorted because a succeeded pause/resume changes the state.
List<KubernetesPodEntry> applyPodOperations(
  List<KubernetesPodEntry> entries,
  Map<String, PodOperation> operations,
) {
  if (operations.isEmpty) return entries;
  final result = <KubernetesPodEntry>[];
  for (final entry in entries) {
    final operation = operations[entry.key];
    if (operation == null) {
      result.add(entry);
      continue;
    }
    if (operation.isSucceeded && operation.action == KubernetesPodAction.kill) {
      continue;
    }
    result.add(entry.withOperation(operation));
  }
  result.sort(_compareEntries);
  return result;
}

/// The state each operation's pod is reported in by daemons that answered
/// ([podsByMachine]); null when the daemon listed no pod for it. Operations
/// on machines that did not answer are omitted. Feeds
/// [PodOperationsNotifier.reconcile].
Map<String, SessionPodDisplayState?> observedPodOperationStates({
  required Map<String, PodOperation> operations,
  required Map<String, List<SessionPod>> podsByMachine,
}) => {
  for (final operation in operations.values)
    if (podsByMachine[operation.machineId] case final pods?)
      operation.key: pods
          .where((pod) => pod.sessionId == operation.sessionId)
          .firstOrNull
          ?.displayState,
};
