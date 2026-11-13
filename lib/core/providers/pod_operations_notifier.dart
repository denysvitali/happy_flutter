/// App-local state machine for Kubernetes pod lifecycle operations.
///
/// A pod action (pause, resume, kill) is recorded here the moment the user
/// asks for it and synced to the owning daemon in the background. Screens
/// render the recorded operation over the last authoritative pod report, so
/// the UI never waits on the RPC:
///
/// ```text
/// submit ──▶ pending ──▶ succeeded ──(daemon report confirms | TTL)──▶ gone
///                   └──▶ failed ──(retry)──▶ pending
///                               └─(dismiss)──▶ gone
/// ```
///
/// The store is keyed by `machineId/sessionId` and lives for the app
/// session (not a widget), so leaving the screen neither cancels the
/// operation nor loses its outcome: a failure is still shown when the user
/// comes back. Only one operation per pod is in flight; a newer submission
/// for the same pod supersedes the settled one.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:riverpod/riverpod.dart';

import '../models/session.dart' show SessionPodDisplayState;
import '../rpc/rpc_types.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

/// A pod lifecycle action sent to the owning daemon.
enum KubernetesPodAction { pause, resume, kill }

/// Sends a pod action. Injectable for tests via [podActionRunnerProvider].
typedef KubernetesPodActionRunner =
    Future<SessionPodActionResponse> Function(
      String machineId,
      String sessionId,
      KubernetesPodAction action,
    );

/// Lifecycle of one recorded pod operation.
enum PodOperationPhase { pending, succeeded, failed }

/// One recorded pod operation and its sync outcome.
@immutable
class PodOperation {
  const PodOperation({
    required this.id,
    required this.machineId,
    required this.sessionId,
    required this.action,
    required this.phase,
    required this.submittedAtMs,
    this.settledAtMs,
    this.error,
    this.pod,
  });

  /// Monotonic per-store id; a completion only applies to its own record.
  final int id;
  final String machineId;
  final String sessionId;
  final KubernetesPodAction action;
  final PodOperationPhase phase;
  final int submittedAtMs;
  final int? settledAtMs;

  /// Daemon or transport error for [PodOperationPhase.failed].
  final String? error;

  /// Pod report the daemon returned with a successful action, if any.
  final SessionPod? pod;

  String get key => podOperationKey(machineId, sessionId);

  bool get isPending => phase == PodOperationPhase.pending;
  bool get isFailed => phase == PodOperationPhase.failed;
  bool get isSucceeded => phase == PodOperationPhase.succeeded;

  /// Whether the operation's effect should be drawn over the last pod
  /// report: while it is in flight and after it succeeded, until a fresh
  /// report confirms it. A failed operation leaves the report untouched.
  bool get overlaysReport => !isFailed;

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

  PodOperation _settle(
    PodOperationPhase phase,
    int nowMs, {
    String? error,
    SessionPod? pod,
  }) => PodOperation(
    id: id,
    machineId: machineId,
    sessionId: sessionId,
    action: action,
    phase: phase,
    submittedAtMs: submittedAtMs,
    settledAtMs: nowMs,
    error: error,
    pod: pod,
  );
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

class PodOperationsNotifier extends Notifier<Map<String, PodOperation>> {
  /// How long a succeeded operation keeps overlaying the pod report when no
  /// fresh report confirms it (e.g. the screen is not polling). The daemon
  /// applies some actions asynchronously, so a report taken right after the
  /// RPC returned may still show the old state.
  static const Duration confirmationTimeout = Duration(seconds: 60);

  @visibleForTesting
  static int Function() clock = () => DateTime.now().millisecondsSinceEpoch;

  int _nextId = 0;
  final Map<String, Timer> _expiry = {};

  @override
  Map<String, PodOperation> build() {
    ref.onDispose(() {
      for (final timer in _expiry.values) {
        timer.cancel();
      }
      _expiry.clear();
    });
    return const {};
  }

  /// Records [action] for the pod and syncs it in the background.
  ///
  /// Returns immediately. Returns false (and does nothing) while another
  /// operation for the same pod is still pending.
  bool submit({
    required String machineId,
    required String sessionId,
    required KubernetesPodAction action,
  }) {
    final key = podOperationKey(machineId, sessionId);
    if (state[key]?.isPending ?? false) return false;
    _expiry.remove(key)?.cancel();
    final operation = PodOperation(
      id: ++_nextId,
      machineId: machineId,
      sessionId: sessionId,
      action: action,
      phase: PodOperationPhase.pending,
      submittedAtMs: clock(),
    );
    state = {...state, key: operation};
    unawaited(_sync(operation));
    return true;
  }

  /// Resubmits a failed operation with the same action.
  bool retry(String key) {
    final operation = state[key];
    if (operation == null || !operation.isFailed) return false;
    return submit(
      machineId: operation.machineId,
      sessionId: operation.sessionId,
      action: operation.action,
    );
  }

  /// Forgets a settled operation. Pending operations cannot be dismissed:
  /// their outcome is still on its way.
  void dismiss(String key) {
    final operation = state[key];
    if (operation == null || operation.isPending) return;
    _remove(key);
  }

  /// Drops succeeded operations whose effect a fresh daemon report shows.
  ///
  /// [observed] maps keys of pods the daemon was asked about to the state
  /// it reported, or null when it listed no pod for that key. Keys absent
  /// from [observed] (daemon unreachable) are left alone.
  void reconcile(Map<String, SessionPodDisplayState?> observed) {
    final confirmed = [
      for (final MapEntry(:key, value: operation) in state.entries)
        if (operation.isSucceeded &&
            observed.containsKey(key) &&
            operation.isConfirmedBy(observed[key]))
          key,
    ];
    if (confirmed.isEmpty) return;
    final next = Map<String, PodOperation>.of(state);
    for (final key in confirmed) {
      next.remove(key);
      _expiry.remove(key)?.cancel();
    }
    state = next;
  }

  Future<void> _sync(PodOperation operation) async {
    final runner = ref.read(podActionRunnerProvider);
    PodOperation settled;
    try {
      final response = await runner(
        operation.machineId,
        operation.sessionId,
        operation.action,
      );
      if (!response.success) {
        throw _PodActionRejected(
          response.message.isEmpty ? 'rejected by daemon' : response.message,
        );
      }
      settled = operation._settle(
        PodOperationPhase.succeeded,
        clock(),
        pod: response.pod,
      );
    } catch (error, stack) {
      logger.warning(
        'Pod action failed: ${operation.action.name}',
        error,
        stack,
      );
      settled = operation._settle(
        PodOperationPhase.failed,
        clock(),
        error: error is _PodActionRejected ? error.message : '$error',
      );
    }
    if (!ref.mounted) return;
    // A newer submission or a dismissal replaced this record.
    if (state[operation.key]?.id != operation.id) return;
    state = {...state, operation.key: settled};
    if (settled.isSucceeded) {
      _expiry[operation.key] = Timer(confirmationTimeout, () {
        _expiry.remove(operation.key);
        if (state[operation.key]?.id == operation.id) _remove(operation.key);
      });
    }
  }

  void _remove(String key) {
    _expiry.remove(key)?.cancel();
    if (!state.containsKey(key)) return;
    state = Map<String, PodOperation>.of(state)..remove(key);
  }
}

class _PodActionRejected implements Exception {
  const _PodActionRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Pod operations recorded this app session, keyed by `machineId/sessionId`.
final podOperationsNotifierProvider =
    NotifierProvider<PodOperationsNotifier, Map<String, PodOperation>>(
      PodOperationsNotifier.new,
    );
