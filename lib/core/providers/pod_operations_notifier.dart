/// App-local state machine for Kubernetes pod lifecycle operations.
///
/// A pod action (pause, resume, kill) is recorded here the moment the user
/// asks for it and synced to the owning daemon in the background. Screens
/// render the recorded operation over the last authoritative pod report, so
/// the UI never waits on the RPC.
///
/// The lifecycle is the shared [OperationStore] machine, keyed by
/// `machineId/sessionId`; a daemon pod report confirms a success.
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod/riverpod.dart';

import '../models/session.dart' show SessionPodDisplayState;
import '../operations/operation_store.dart';
import '../rpc/rpc_types.dart';
import '../services/sync_service.dart';

export '../operations/operation_store.dart'
    show Operation, OperationPhase, OperationRejected;

/// A pod lifecycle action sent to the owning daemon.
enum KubernetesPodAction { pause, resume, kill }

/// Sends a pod action. Injectable for tests via [podActionRunnerProvider].
typedef KubernetesPodActionRunner =
    Future<SessionPodActionResponse> Function(
      String machineId,
      String sessionId,
      KubernetesPodAction action,
    );

/// A pod action on one session's pod.
@immutable
class PodRequest {
  const PodRequest({
    required this.machineId,
    required this.sessionId,
    required this.action,
  });

  final String machineId;
  final String sessionId;
  final KubernetesPodAction action;
}

/// A recorded pod operation.
typedef PodOperation = Operation<PodRequest>;

extension PodOperationView on PodOperation {
  String get machineId => request.machineId;
  String get sessionId => request.sessionId;
  KubernetesPodAction get action => request.action;

  /// Pod report the daemon returned with a successful action, if any.
  SessionPod? get pod => switch (result) {
    final SessionPod pod => pod,
    _ => null,
  };

  /// The state the pod is expected to reach once the daemon applied the
  /// action; null for a kill (the pod disappears).
  SessionPodDisplayState? get expectedState => switch (action) {
    KubernetesPodAction.pause => SessionPodDisplayState.paused,
    KubernetesPodAction.resume => SessionPodDisplayState.scheduling,
    KubernetesPodAction.kill => null,
  };

  /// Whether an authoritative [observed] state (null = no pod listed)
  /// shows this operation's effect.
  bool isConfirmedBy(SessionPodDisplayState? observed) => switch (action) {
    KubernetesPodAction.kill =>
      observed == null || observed == SessionPodDisplayState.archived,
    KubernetesPodAction.pause => observed == SessionPodDisplayState.paused,
    KubernetesPodAction.resume =>
      observed != null &&
          observed != SessionPodDisplayState.paused &&
          observed != SessionPodDisplayState.archived,
  };
}

/// Store key for a pod operation; matches `KubernetesPodEntry.key`.
String podOperationKey(String machineId, String sessionId) =>
    '$machineId/$sessionId';

Future<SessionPodActionResponse> _syncPodActionRunner(
  String machineId,
  String sessionId,
  KubernetesPodAction action,
) => switch (action) {
  KubernetesPodAction.pause => sync.machinePauseSessionPod(
    machineId: machineId,
    sessionId: sessionId,
  ),
  KubernetesPodAction.resume => sync.machineResumeSessionPod(
    machineId: machineId,
    sessionId: sessionId,
  ),
  KubernetesPodAction.kill => sync.machineKillSessionPod(
    machineId: machineId,
    sessionId: sessionId,
  ),
};

/// Transport used by [PodOperationsNotifier]. Override in tests.
final podActionRunnerProvider = Provider<KubernetesPodActionRunner>(
  (ref) => _syncPodActionRunner,
);

class PodOperationsNotifier extends OperationStore<PodRequest> {
  @override
  String get logName => 'Pod';

  @override
  String keyOf(PodRequest request) =>
      podOperationKey(request.machineId, request.sessionId);

  @override
  Future<Object?> perform(PodRequest request) async {
    final response = await ref.read(podActionRunnerProvider)(
      request.machineId,
      request.sessionId,
      request.action,
    );
    if (!response.success) {
      throw OperationRejected(
        response.message.isEmpty ? 'rejected by daemon' : response.message,
      );
    }
    return response.pod;
  }

  /// Records [action] for the pod and syncs it in the background.
  bool submitAction({
    required String machineId,
    required String sessionId,
    required KubernetesPodAction action,
  }) => submit(
    PodRequest(machineId: machineId, sessionId: sessionId, action: action),
  );

  /// Drops succeeded operations whose effect a fresh daemon report shows.
  ///
  /// [observed] maps keys of pods the daemon was asked about to the state
  /// it reported, or null when it listed no pod for that key. Keys absent
  /// from [observed] (daemon unreachable) are left alone.
  void reconcile(Map<String, SessionPodDisplayState?> observed) => confirmWhere(
    (operation) =>
        observed.containsKey(operation.key) &&
        operation.isConfirmedBy(observed[operation.key]),
  );
}

/// Pod operations recorded this app session, keyed by `machineId/sessionId`.
final podOperationsNotifierProvider =
    NotifierProvider<PodOperationsNotifier, Map<String, PodOperation>>(
      PodOperationsNotifier.new,
    );
