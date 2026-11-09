import '../../core/components/app_badge.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/rpc/rpc_types.dart';
import '../chat/widgets/kubernetes_startup_panel.dart'
    show kubernetesPodStartFailed;

/// Display state of a live pod reported by the daemon.
///
/// A start failure (`Failed` phase or a crash/pull back-off reason) wins
/// over `ready`, so a crash-looping container never reads as healthy.
extension SessionPodDisplay on SessionPod {
  SessionPodDisplayState get displayState {
    if (archived) return SessionPodDisplayState.archived;
    if (paused) return SessionPodDisplayState.paused;
    if (kubernetesPodStartFailed(this)) return SessionPodDisplayState.failed;
    if (ready) return SessionPodDisplayState.ready;
    return SessionPodDisplayState.scheduling;
  }
}

/// Short label for a pod state ("Ready", "Paused", ...).
String kubernetesPodStateLabel(
  AppLocalizations l10n,
  SessionPodDisplayState state,
) => switch (state) {
  SessionPodDisplayState.scheduling => l10n.sessionPodScheduling,
  SessionPodDisplayState.ready => l10n.sessionPodReady,
  SessionPodDisplayState.paused => l10n.sessionPodPaused,
  SessionPodDisplayState.archived => l10n.sessionPodArchived,
  SessionPodDisplayState.failed => l10n.sessionPodFailed,
};

/// Count label for a pod state ("3 running", "1 paused", ...).
String kubernetesPodCountLabel(
  AppLocalizations l10n,
  SessionPodDisplayState state,
  int count,
) => switch (state) {
  SessionPodDisplayState.scheduling => l10n.kubernetesCountStarting(count),
  SessionPodDisplayState.ready => l10n.kubernetesCountRunning(count),
  SessionPodDisplayState.paused => l10n.kubernetesCountPaused(count),
  SessionPodDisplayState.archived => l10n.kubernetesCountArchived(count),
  SessionPodDisplayState.failed => l10n.kubernetesCountFailed(count),
};

/// Badge tone for a pod state.
AppBadgeTone kubernetesPodStateTone(SessionPodDisplayState state) =>
    switch (state) {
      SessionPodDisplayState.scheduling => AppBadgeTone.info,
      SessionPodDisplayState.ready => AppBadgeTone.success,
      SessionPodDisplayState.paused => AppBadgeTone.warning,
      SessionPodDisplayState.archived => AppBadgeTone.neutral,
      SessionPodDisplayState.failed => AppBadgeTone.danger,
    };

/// Whether a catalog session still holds a Kubernetes pod worth showing.
///
/// Session metadata is the last state the daemon published, so it can go
/// stale once the agent disconnects. Archived sessions never count; a
/// disconnected session only counts while its pod is paused (the workspace
/// volume is kept) or failed (needs attention). An inactive "ready" or
/// "scheduling" row is a leftover, not a running container.
bool isLiveKubernetesSession(Session session) {
  if (!session.isKubernetesSession || session.archived) return false;
  final state = session.podDisplayState;
  if (state == SessionPodDisplayState.archived) return false;
  if (session.active) return true;
  return state == SessionPodDisplayState.paused ||
      state == SessionPodDisplayState.failed;
}
