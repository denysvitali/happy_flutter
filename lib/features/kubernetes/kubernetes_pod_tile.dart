import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/components/app_badge.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/pod_operations_notifier.dart';
import '../../core/rpc/rpc_types.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/session_utils.dart' show formatRelativeTime;
import '../../core/utils/snack.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import 'kubernetes_pod_format.dart';
import 'kubernetes_pod_operation_view.dart';
import 'kubernetes_pod_state.dart';
import 'kubernetes_pods_model.dart';

/// One compact pod row: a state dot (or a checkbox while selecting), the
/// session title with the pod's uptime, one line with state, repository
/// and restarts, CPU/memory against limits when the cluster reports them,
/// and any failure. The menu opens the chat or Session info, copies the
/// pod name, pauses or resumes the pod, archives the session, or kills the
/// pod.
class KubernetesPodTile extends StatelessWidget {
  const KubernetesPodTile({
    required this.entry,
    super.key,
    this.now,
    this.lastUpdatedMs,
    this.onTap,
    this.onLongPress,
    this.onInfo,
    this.onAction,
    this.onArchive,
    this.onRetry,
    this.onDismiss,
    this.selected,
  });

  final KubernetesPodEntry entry;

  /// Reference time for uptime; defaults to the build time.
  final DateTime? now;

  /// When this machine's pod state was last successfully refreshed.
  final int? lastUpdatedMs;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onInfo;

  /// Pod lifecycle actions; null when the pod cannot be controlled.
  final ValueChanged<KubernetesPodAction>? onAction;

  /// Archives the owning session; null when it cannot be archived.
  final VoidCallback? onArchive;

  /// Retry / dismiss a failed operation shown on the row.
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  /// Null outside selection mode; otherwise whether this row is selected.
  /// A selecting row with a null [onTap] cannot be selected.
  final bool? selected;

  bool get _selecting => selected != null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = entry.state;
    final tone = kubernetesPodStateTone(state);
    final toneColors = AppToneColors.of(context, tone);
    final title = entry.sessionTitle;
    final running = entry.runningPod;
    final repo = formatPodRepo(entry.repoUrl, entry.repoRef);
    final detail = entry.detail;
    final startedAt = running == null || running.startedAtMs <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(running.startedAtMs);
    final uptime = startedAt == null
        ? null
        : formatPodUptime((now ?? DateTime.now()).difference(startedAt));
    final restarts = running?.restartCount ?? 0;
    final operation = entry.operation;
    final pendingKill =
        operation != null &&
        operation.isPending &&
        operation.action == KubernetesPodAction.kill;
    final isSelected = selected ?? false;
    final lastUpdated = lastUpdatedMs;

    final separator = TextSpan(text: ' · ', style: AppText.secondary(theme));
    final meta = <InlineSpan>[
      TextSpan(
        text: kubernetesPodStateLabel(l10n, state),
        style: AppText.label(theme, toneColors.iconColor),
      ),
      if (title == null) ...[
        separator,
        TextSpan(text: l10n.kubernetesUntrackedPod),
      ],
      if (repo.isNotEmpty) ...[separator, TextSpan(text: repo)],
      if (restarts > 0) ...[
        separator,
        TextSpan(
          text: l10n.kubernetesRestarts(restarts),
          style: AppText.secondary(
            theme,
            AppToneColors.of(context, AppBadgeTone.warning).iconColor,
          ),
        ),
      ],
      if (!entry.live) ...[
        separator,
        TextSpan(
          text: lastUpdated != null
              ? '${l10n.kubernetesLastKnown} · '
                    '${l10n.kubernetesLastUpdated(formatRelativeTime(lastUpdated))}'
              : l10n.kubernetesLastKnown,
        ),
      ],
    ];

    final Widget leading = _selecting
        ? Checkbox(
            value: isSelected,
            onChanged: onTap == null ? null : (_) => onTap!(),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xsm),
            child: AppStatusDot(
              color: toneColors.iconColor,
              size: AppSpacing.sm,
              pulse: state == SessionPodDisplayState.scheduling,
            ),
          );

    final row = Material(
      color: isSelected
          ? cs.secondaryContainer.withValues(alpha: 0.6)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _selecting ? AppSpacing.xs : AppSpacing.lg,
            AppSpacing.smd,
            _selecting ? AppSpacing.lg : AppSpacing.xxs,
            AppSpacing.smd,
          ),
          child: Row(
            crossAxisAlignment: _selecting
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              leading,
              SizedBox(width: _selecting ? AppSpacing.xs : AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title ?? entry.podName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title(theme).copyWith(
                              fontFamily: title == null ? 'monospace' : null,
                            ),
                          ),
                        ),
                        if (uptime != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Tooltip(
                            message: l10n.kubernetesUptime(uptime),
                            child: Text(
                              uptime,
                              key: const Key('kubernetes-pod-uptime'),
                              semanticsLabel: l10n.kubernetesUptime(uptime),
                              style: AppText.badge(theme),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text.rich(
                      TextSpan(children: meta),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.secondary(theme),
                    ),
                    if (running != null && running.metricsAvailable) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      _UsageLine(pod: running),
                    ],
                    if (operation != null && operation.isPending) ...[
                      const SizedBox(height: AppSpacing.xs),
                      AppBadge(
                        key: const Key('kubernetes-pod-operation-pending'),
                        leading: const Icon(Icons.sync_rounded),
                        label: kubernetesPodPendingLabel(
                          l10n,
                          operation.action,
                        ),
                        tone: operation.action == KubernetesPodAction.kill
                            ? AppBadgeTone.danger
                            : AppBadgeTone.info,
                      ),
                    ],
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.secondary(
                          theme,
                          state == SessionPodDisplayState.failed
                              ? cs.error
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (operation != null && operation.isFailed) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        child: PodOperationFailureBanner(
                          operation: operation,
                          onRetry: onRetry ?? () {},
                          onDismiss: onDismiss ?? () {},
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!_selecting) _menu(context),
            ],
          ),
        ),
      ),
    );
    // A pod being deleted fades while the daemon confirms.
    return pendingKill ? Opacity(opacity: 0.6, child: row) : row;
  }

  Widget _menu(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (entry.busy) {
      return const SizedBox(
        width: AppControlSize.lg,
        height: AppControlSize.md,
        child: Center(
          child: SizedBox.square(
            dimension: AppIconSize.md,
            child: AppCircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final action = onAction;
    final archive = onArchive;
    final paused = entry.state == SessionPodDisplayState.paused;
    final podName = entry.podName;
    final items = <PopupMenuEntry<VoidCallback>>[
      if (onTap != null)
        PopupMenuItem(
          value: onTap,
          child: _MenuRow(
            icon: Icons.chat_bubble_outline_rounded,
            label: l10n.kubernetesOpenChat,
          ),
        ),
      if (onInfo != null)
        PopupMenuItem(
          value: onInfo,
          child: _MenuRow(
            icon: Icons.info_outline_rounded,
            label: l10n.kubernetesInfoAndLogs,
          ),
        ),
      if (podName.isNotEmpty && entry.sessionTitle != null)
        PopupMenuItem(
          key: const Key('kubernetes-pod-copy-name'),
          value: () {
            Clipboard.setData(ClipboardData(text: podName));
            context.showSnack(l10n.commonCopied);
          },
          child: _MenuRow(
            icon: Icons.copy_rounded,
            label: l10n.kubernetesCopyPodName,
          ),
        ),
      if (action != null || archive != null) const PopupMenuDivider(),
      if (action != null)
        if (paused)
          PopupMenuItem(
            value: () => action(KubernetesPodAction.resume),
            child: _MenuRow(
              icon: Icons.play_arrow_rounded,
              label: l10n.sessionPodResume,
            ),
          )
        else
          PopupMenuItem(
            value: () => action(KubernetesPodAction.pause),
            child: _MenuRow(
              icon: Icons.pause_rounded,
              label: l10n.sessionPodPause,
            ),
          ),
      if (archive != null)
        PopupMenuItem(
          key: const Key('kubernetes-pod-archive'),
          value: archive,
          child: _MenuRow(
            icon: Icons.archive_outlined,
            label: l10n.sessionsArchiveSession,
          ),
        ),
      if (action != null)
        PopupMenuItem(
          key: const Key('kubernetes-pod-kill'),
          value: () => action(KubernetesPodAction.kill),
          child: _MenuRow(
            icon: Icons.delete_forever_outlined,
            label: l10n.sessionPodKill,
            color: cs.error,
          ),
        ),
    ];
    if (items.isEmpty) return const SizedBox(width: AppSpacing.md);
    return PopupMenuButton<VoidCallback>(
      key: Key('kubernetes-pod-menu-${entry.key}'),
      tooltip: l10n.kubernetesPodActions,
      // Compact button: the default 48dp square, not the two text lines,
      // would set the row height and leave a blank band under each row.
      style: IconButton.styleFrom(
        minimumSize: const Size(AppControlSize.lg, AppControlSize.md),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        Icons.more_vert_rounded,
        size: AppIconSize.xl,
        color: cs.onSurfaceVariant,
      ),
      onSelected: (callback) => callback(),
      itemBuilder: (_) => items,
    );
  }
}

/// `CPU 0.25 / 2 · Memory 512 MiB / 4 GiB`, each value tinted when it
/// nears its limit (or request).
class _UsageLine extends StatelessWidget {
  const _UsageLine({required this.pod});

  final SessionPod pod;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cpu = _usage(
      context,
      usage: pod.cpuUsageMillicores,
      limit: pod.cpuLimitMillicores,
      request: pod.cpuRequestMillicores,
      format: formatCpuCores,
    );
    final memory = _usage(
      context,
      usage: pod.memoryUsageBytes,
      limit: pod.memoryLimitBytes,
      request: pod.memoryRequestBytes,
      format: formatBinaryBytes,
    );
    return Text.rich(
      key: const Key('kubernetes-pod-usage'),
      TextSpan(
        children: [
          TextSpan(text: '${l10n.kubernetesCpu} '),
          cpu,
          const TextSpan(text: ' · '),
          TextSpan(text: '${l10n.kubernetesMemory} '),
          memory,
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.secondary(theme),
    );
  }

  static TextSpan _usage(
    BuildContext context, {
    required int usage,
    required int limit,
    required int request,
    required String Function(int) format,
  }) {
    final theme = Theme.of(context);
    final share = podUsageFraction(
      usage: usage,
      limit: limit,
      request: request,
    );
    final capacity = limit > 0
        ? format(limit)
        : request > 0
        ? format(request)
        : null;
    final color = share == null || share < 0.75
        ? theme.colorScheme.onSurface
        : share >= 0.9
        ? AppToneColors.of(context, AppBadgeTone.danger).iconColor
        : AppToneColors.of(context, AppBadgeTone.warning).iconColor;
    return TextSpan(
      text: capacity == null ? format(usage) : '${format(usage)} / $capacity',
      style: AppText.badge(theme, color).copyWith(fontWeight: FontWeight.w500),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.lg, color: color),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(label, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
