import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/components/app_inline_row.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/rpc/rpc_types.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';

/// Container/pod reasons that mean the pod will not become ready on its own.
const _failureReasons = {
  'CrashLoopBackOff',
  'CreateContainerConfigError',
  'CreateContainerError',
  'ErrImagePull',
  'ErrImageNeverPull',
  'Evicted',
  'ImagePullBackOff',
  'InvalidImageName',
  'OOMKilled',
  'RunContainerError',
  'Unschedulable',
};

/// Whether the chat should show the live pod startup panel.
///
/// Only Kubernetes sessions that are not yet reachable and are actually
/// starting (a fresh spawn, a pending pod, or a send waiting on a restart)
/// qualify; an idle stopped pod without a pending send stays quiet.
bool shouldShowKubernetesStartup({
  required Session session,
  required bool isReady,
  required bool hasPendingRequest,
}) {
  if (!session.isKubernetesSession || isReady) return false;
  final state = session.podDisplayState;
  if (state == SessionPodDisplayState.archived ||
      state == SessionPodDisplayState.paused) {
    return false;
  }
  if (hasPendingRequest) return true;
  final lifecycle = session.effectiveLifecycleState?.toLowerCase();
  if (lifecycle == 'starting' || lifecycle == 'connecting') return true;
  return session.metadata?.podPhase?.toLowerCase() == 'pending';
}

/// Whether [pod] reports a state that will not recover without action.
bool kubernetesPodStartFailed(SessionPod? pod) {
  if (pod == null) return false;
  return pod.phase.toLowerCase() == 'failed' ||
      _failureReasons.contains(pod.reason);
}

/// Human-readable summary of the real pod status, e.g.
/// `Pending · ContainerCreating`.
String kubernetesPodStageLabel(AppLocalizations l10n, SessionPod? pod) {
  if (pod == null || (pod.phase.isEmpty && pod.reason.isEmpty)) {
    return l10n.sessionPodStageScheduling;
  }
  if (pod.ready && !kubernetesPodStartFailed(pod)) {
    return l10n.sessionPodStageAgent;
  }
  return [pod.phase, pod.reason].where((part) => part.isNotEmpty).join(' · ');
}

/// Keeps the last [maxLines] non-empty log lines.
String kubernetesLogTail(String content, {int maxLines = 200}) {
  final lines = content.trimRight().split('\n');
  final start = lines.length > maxLines ? lines.length - maxLines : 0;
  return lines.sublist(start).join('\n');
}

typedef KubernetesPodLoader = Future<SessionPod?> Function();
typedef KubernetesPodLogsLoader = Future<SessionPodLogsResponse> Function();

/// Live pod status and log tail shown above the composer while a Kubernetes
/// session is spawning, so a send never waits behind an opaque "Sending".
///
/// Polls the daemon's `get-session-pod` / `get-session-pod-logs` RPCs every
/// [pollInterval] while on screen. Polling pauses while the route is covered
/// ([TickerMode] off) and stops when the panel is removed, i.e. as soon as
/// the session becomes reachable. Presentation only: never touches delivery.
class KubernetesStartupPanel extends StatefulWidget {
  const KubernetesStartupPanel({
    required this.session,
    required this.loadPod,
    required this.loadLogs,
    super.key,
    this.pollInterval = const Duration(seconds: 2),
  });

  final Session session;
  final KubernetesPodLoader loadPod;
  final KubernetesPodLogsLoader loadLogs;
  final Duration pollInterval;

  @override
  State<KubernetesStartupPanel> createState() => _KubernetesStartupPanelState();
}

class _KubernetesStartupPanelState extends State<KubernetesStartupPanel> {
  final _logScroll = ScrollController();
  Timer? _timer;
  bool _polling = false;
  bool _active = false;
  bool _expanded = true;
  SessionPod? _pod;
  String? _logs;
  int _podFailures = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active == _active) return;
    _active = active;
    if (active) {
      unawaited(_poll());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logScroll.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling || !mounted || !_active) return;
    _polling = true;
    _timer?.cancel();
    try {
      SessionPod? pod;
      try {
        pod = await widget.loadPod();
        _podFailures = 0;
      } catch (error) {
        // Early in a spawn the daemon may not track the pod yet.
        _podFailures++;
        logger.debug('Kubernetes startup pod poll failed: $error');
      }
      if (!mounted) return;
      String? logs;
      final current = pod ?? _pod;
      if (current != null && current.podName.isNotEmpty) {
        try {
          final response = await widget.loadLogs();
          logs = kubernetesLogTail(response.content);
        } catch (error) {
          // Pending containers have no logs yet; keep the previous tail.
          logger.debug('Kubernetes startup log poll failed: $error');
        }
      }
      if (!mounted) return;
      final hadLogs = _logs;
      setState(() {
        if (pod != null) _pod = pod;
        if (logs != null && logs.isNotEmpty) _logs = logs;
      });
      if (_logs != hadLogs) _scrollLogsToEnd();
    } finally {
      _polling = false;
      if (mounted && _active) {
        _timer = Timer(widget.pollInterval, () => unawaited(_poll()));
      }
    }
  }

  void _scrollLogsToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logScroll.hasClients) return;
      _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pod = _pod;
    final failed =
        kubernetesPodStartFailed(pod) ||
        widget.session.podDisplayState == SessionPodDisplayState.failed;
    final title = failed
        ? l10n.sessionPodStartFailedTitle
        : l10n.sessionPodStartingTitle;
    final stage = _podFailures >= 3 && pod == null
        ? l10n.sessionPodLoadFailed
        : kubernetesPodStageLabel(l10n, pod);
    final podName = pod?.podName.isNotEmpty == true
        ? pod!.podName
        : widget.session.metadata?.podName;
    final message = pod?.message ?? '';
    final logs = _logs;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInlineRow(
            leading: failed
                ? const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                  )
                : Icon(Icons.cloud_sync_outlined, color: cs.primary),
            onTap: () => setState(() => _expanded = !_expanded),
            expanded: _expanded,
            semanticLabel: '$title, $stage',
            dense: true,
            trailing: Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: cs.onSurfaceVariant,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppInlineText.chromeStrong(context),
                ),
                Text(
                  [
                    stage,
                    if (podName != null && podName.isNotEmpty) podName,
                  ].join(' · '),
                  key: const Key('kubernetes-startup-stage'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppInlineText.chrome(
                    context,
                  ).copyWith(color: failed ? AppColors.error : null),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Text(
                  message,
                  key: const Key('kubernetes-startup-message'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppInlineText.chrome(
                    context,
                  ).copyWith(color: failed ? AppColors.error : null),
                ),
              ),
            Container(
              key: const Key('kubernetes-startup-logs'),
              constraints: const BoxConstraints(maxHeight: 180),
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: logs == null
                  ? Text(
                      l10n.sessionPodWaitingForContainer,
                      style: AppInlineText.chrome(context),
                    )
                  : SingleChildScrollView(
                      controller: _logScroll,
                      child: SelectableText(
                        logs,
                        style: AppText.mono(
                          theme,
                          cs.onSurfaceVariant,
                        ).copyWith(fontSize: AppFontSize.sm),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
