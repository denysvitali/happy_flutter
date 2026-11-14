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
import '../../../core/utils/ansi_parser.dart';
import '../../../core/widgets/ansi_log_text.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import '../session_failure_reason.dart';

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
  // A pod whose agent is visibly alive has started, whatever the lifecycle
  // says.
  if (session.isAliveDespiteLifecycleError) return false;
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

/// `45s`, `1m 29s`, `2h 3m`: how long a startup step has run.
String kubernetesStepDuration(Duration d) {
  final seconds = d.inSeconds;
  if (seconds < 60) return '${seconds}s';
  final minutes = d.inMinutes;
  if (minutes < 60) return '${minutes}m ${seconds % 60}s';
  return '${d.inHours}h ${minutes % 60}m';
}

/// One row per init/app container of [pod], in start order, with the state
/// the kubelet reports. Hidden when an older daemon reports no containers.
class KubernetesPodSteps extends StatelessWidget {
  const KubernetesPodSteps({required this.pod, super.key, this.nowMs});

  final SessionPod pod;

  /// Clock for running steps; defaults to now.
  final int? nowMs;

  @override
  Widget build(BuildContext context) {
    final containers = pod.containers;
    if (containers.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return Padding(
      key: const Key('kubernetes-startup-steps'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sessionPodStepsTitle,
            style: AppInlineText.chromeStrong(context),
          ),
          for (final c in containers)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _stepRow(context, l10n, cs, c, now),
            ),
        ],
      ),
    );
  }

  Widget _stepRow(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
    SessionPodContainer c,
    int now,
  ) {
    final Widget icon;
    final String state;
    if (c.failed) {
      icon = const Icon(
        Icons.error_outline_rounded,
        size: 16,
        color: AppColors.error,
      );
      state = l10n.sessionPodStepFailed;
    } else if (c.succeeded) {
      icon = Icon(
        Icons.check_circle_outline_rounded,
        size: 16,
        color: cs.primary,
      );
      state = l10n.sessionPodStepDone;
    } else if (c.state == 'running') {
      icon = SizedBox(
        width: 16,
        height: 16,
        child: AppCircularProgressIndicator(strokeWidth: 2, color: cs.primary),
      );
      state = l10n.sessionPodStepRunning;
    } else {
      icon = Icon(Icons.schedule_rounded, size: 16, color: cs.onSurfaceVariant);
      state = l10n.sessionPodStepWaiting;
    }
    final elapsed = c.elapsed(now);
    final detail = [
      state,
      if (c.reason.isNotEmpty && c.reason != 'Completed') c.reason,
      if (c.exitCode != null && c.exitCode != 0) 'exit ${c.exitCode}',
      if (elapsed != null && c.state != 'waiting')
        kubernetesStepDuration(elapsed),
      if (c.restartCount > 0) '↻ ${c.restartCount}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            icon,
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppInlineText.chrome(context),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppInlineText.chrome(context).copyWith(
                color: c.failed ? AppColors.error : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (c.failed && c.message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              c.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppInlineText.chrome(
                context,
              ).copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

/// The daemon's diagnostic facts (`phase …`, `node …`, `init: …`, events) as
/// a selectable list, so a start failure shows where the pod was stuck.
class KubernetesDiagnosticFacts extends StatelessWidget {
  const KubernetesDiagnosticFacts({
    required this.facts,
    super.key,
    this.warnings = const [],
  });

  final List<String> facts;

  /// Recent warning events from the live pod, shown when the failure
  /// sentence carries none.
  final List<SessionPodEvent> warnings;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty && warnings.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final style = AppInlineText.chrome(context);
    return Padding(
      key: const Key('kubernetes-startup-diagnostics'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (facts.isNotEmpty) ...[
            Text(
              l10n.sessionPodDiagnosticsTitle,
              style: AppInlineText.chromeStrong(context),
            ),
            for (final fact in facts)
              SelectableText('• $fact', maxLines: 4, style: style),
          ],
          if (warnings.isNotEmpty) ...[
            Text(
              l10n.sessionPodEventsTitle,
              style: AppInlineText.chromeStrong(context),
            ),
            for (final event in warnings)
              SelectableText(
                '• ${event.reason}: ${event.message}'
                '${event.count > 1 ? ' (×${event.count})' : ''}',
                maxLines: 3,
                style: style,
              ),
          ],
        ],
      ),
    );
  }
}

final _logSectionHeader = RegExp(r'^==> .+ <==$');

/// Drops `==> container <==` sections that hold no output. Daemons before
/// the silent-container fix listed every started init container, so a pod
/// whose steps printed nothing showed three bare headers as its "logs".
String kubernetesLogsWithoutEmptySections(String content) {
  final out = <String>[];
  String? pendingHeader;
  for (final line in content.split('\n')) {
    // Judge emptiness on visible text: a line of bare colour resets or
    // erase sequences prints nothing.
    final visible = AnsiParser.strip(line).trim();
    if (_logSectionHeader.hasMatch(visible)) {
      pendingHeader = line;
      continue;
    }
    if (visible.isEmpty) {
      if (pendingHeader == null && out.isNotEmpty) out.add(line);
      continue;
    }
    if (pendingHeader != null) {
      if (out.isNotEmpty && AnsiParser.strip(out.last).trim().isNotEmpty) {
        out.add('');
      }
      out.add(pendingHeader);
      pendingHeader = null;
    }
    out.add(line);
  }
  return out.join('\n').trimRight();
}

/// Keeps the last [maxLines] log lines of the sections that printed anything.
String kubernetesLogTail(String content, {int maxLines = 200}) {
  final lines = kubernetesLogsWithoutEmptySections(content).split('\n');
  final start = lines.length > maxLines ? lines.length - maxLines : 0;
  return lines.sublist(start).join('\n');
}

typedef KubernetesPodLoader = Future<SessionPod?> Function();
typedef KubernetesPodLogsLoader = Future<SessionPodLogsResponse> Function();

/// Live pod status and log tail shown while a Kubernetes session is spawning:
/// as the chat body before the first message, and above the composer after
/// it, so a send never waits behind an opaque "Sending".
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
    this.fillHeight = false,
  });

  /// Fills the available height with the log tail instead of a short strip.
  /// Used as the chat body while a conversation has no messages yet.
  final bool fillHeight;

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
      // Follow new output only while the reader is at the end; someone who
      // scrolled up to read an earlier line must not be yanked back down.
      final follow = !_logScroll.hasClients || _logsAtEnd(_logScroll.position);
      setState(() {
        if (pod != null) _pod = pod;
        if (logs != null && logs.isNotEmpty) _logs = logs;
      });
      if (_logs != hadLogs && follow) _scrollLogsToEnd();
    } finally {
      _polling = false;
      if (mounted && _active) {
        _timer = Timer(widget.pollInterval, () => unawaited(_poll()));
      }
    }
  }

  static bool _logsAtEnd(ScrollPosition position) =>
      position.pixels >= position.maxScrollExtent - 24;

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
    // The session's own failure sentence outranks the polled pod: after a
    // failed start the daemon deletes that pod, and the poll then describes
    // a different (or no) pod, e.g. "running, waiting for the agent".
    final lifecycleError = failed
        ? widget.session.metadata?.lifecycleStateError
        : null;
    final podFailed = kubernetesPodStartFailed(pod);
    final failureKind = !failed
        ? null
        : classifySessionFailure(lifecycleError) ??
              (podFailed
                  ? classifySessionFailure('${pod!.reason} ${pod.message}')
                  : null);
    final stage = failureKind != null
        ? sessionFailureReasonText(l10n, failureKind)
        : failed && !podFailed
        ? l10n.sessionPodStageStopped
        : _podFailures >= 3 && pod == null
        ? l10n.sessionPodLoadFailed
        : [
            kubernetesPodStageLabel(l10n, pod),
            if (pod?.deleting == true) l10n.sessionPodTerminating,
          ].join(' · ');
    final podName = pod?.podName.isNotEmpty == true
        ? pod!.podName
        : widget.session.metadata?.podName;
    final detailParts = splitSessionFailureDiagnosis(
      sessionFailureDetail(lifecycleError) ??
          (failed && !podFailed ? '' : pod?.message ?? ''),
    );
    final message = detailParts.summary;
    // Facts in the failure sentence describe the pod that died; the live
    // pod's recent warnings fill in only when the sentence has none.
    final liveWarnings = detailParts.facts.isEmpty && pod != null
        ? pod.events
              .where((e) => e.isWarning)
              .toList()
              .reversed
              .take(3)
              .toList()
        : const <SessionPodEvent>[];
    final logs = _logs;
    final fill = widget.fillHeight;
    final expanded = fill || _expanded;
    final logBox = Container(
      key: const Key('kubernetes-startup-logs'),
      constraints: fill ? null : const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: logs == null
          ? Text(
              failed
                  ? l10n.sessionPodNoOutput
                  : l10n.sessionPodWaitingForContainer,
              style: AppInlineText.chrome(context),
            )
          : SingleChildScrollView(
              controller: _logScroll,
              child: AnsiLogText(
                logs,
                style: AppText.mono(
                  theme,
                  cs.onSurfaceVariant,
                ).copyWith(fontSize: AppFontSize.sm),
              ),
            ),
    );

    return Padding(
      padding: fill
          ? const EdgeInsets.all(AppSpacing.md)
          : const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        key: fill ? const Key('kubernetes-startup-body') : null,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInlineRow(
            leading: failed
                ? const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                  )
                : Icon(Icons.cloud_sync_outlined, color: cs.primary),
            onTap: fill ? null : () => setState(() => _expanded = !_expanded),
            expanded: expanded,
            semanticLabel: '$title, $stage',
            dense: true,
            trailing: fill
                ? null
                : Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
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
                    // A reason is a sentence; the pod name would only
                    // truncate it, and the detail below names the pod.
                    if (failureKind == null &&
                        podName != null &&
                        podName.isNotEmpty)
                      podName,
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
          if (expanded) ...[
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: SelectableText(
                  message,
                  key: const Key('kubernetes-startup-message'),
                  minLines: 1,
                  maxLines: 6,
                  style: AppInlineText.chrome(
                    context,
                  ).copyWith(color: failed ? AppColors.error : null),
                ),
              ),
            if (pod != null && (!failed || podFailed))
              KubernetesPodSteps(pod: pod),
            KubernetesDiagnosticFacts(
              facts: detailParts.facts,
              warnings: liveWarnings,
            ),
            if (fill) Expanded(child: logBox) else logBox,
          ],
        ],
      ),
    );
  }
}
