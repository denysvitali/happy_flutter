import 'package:flutter/material.dart';

import '../../../core/components/app_badge.dart';
import '../../../core/components/app_banner.dart';
import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/rpc/rpc_types.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import 'session_info_widgets.dart';

/// Kubernetes pod state and controls: a status header, then the pod
/// actions as rows — the same shape as Quick actions below.
class SessionPodSection extends StatelessWidget {
  const SessionPodSection({
    super.key,
    required this.session,
    required this.pod,
    required this.logs,
    required this.loading,
    required this.actionRunning,
    required this.error,
    required this.onRefresh,
    required this.onLoadLogs,
    required this.onHideLogs,
    required this.onPause,
    required this.onResume,
    required this.onKill,
  });

  final Session session;
  final SessionPod? pod;
  final SessionPodLogsResponse? logs;
  final bool loading;
  final bool actionRunning;
  final Object? error;
  final VoidCallback onRefresh;
  final VoidCallback onLoadLogs;
  final VoidCallback onHideLogs;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onKill;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentPod = pod;
    final state = currentPod == null
        ? session.podDisplayState
        : currentPod.archived
        ? SessionPodDisplayState.archived
        : currentPod.paused
        ? SessionPodDisplayState.paused
        : currentPod.ready
        ? SessionPodDisplayState.ready
        : currentPod.phase.toLowerCase() == 'failed'
        ? SessionPodDisplayState.failed
        : SessionPodDisplayState.scheduling;
    final stateLabel = switch (state) {
      SessionPodDisplayState.scheduling => l10n.sessionPodScheduling,
      SessionPodDisplayState.ready => l10n.sessionPodReady,
      SessionPodDisplayState.paused => l10n.sessionPodPaused,
      SessionPodDisplayState.archived => l10n.sessionPodArchived,
      SessionPodDisplayState.failed => l10n.sessionPodFailed,
    };
    final stateTone = switch (state) {
      SessionPodDisplayState.scheduling => AppBadgeTone.info,
      SessionPodDisplayState.ready => AppBadgeTone.success,
      SessionPodDisplayState.paused => AppBadgeTone.warning,
      SessionPodDisplayState.archived => AppBadgeTone.neutral,
      SessionPodDisplayState.failed => AppBadgeTone.danger,
    };
    final namespace = currentPod?.namespace ?? session.metadata?.namespace;
    final podName =
        currentPod?.podName ?? session.metadata?.podName ?? l10n.sessionPod;
    final detail = currentPod == null
        ? ''
        : [
            currentPod.reason,
            currentPod.message,
          ].where((value) => value.isNotEmpty).join(' · ');
    final logsResponse = logs;

    return SettingsSection(
      title: l10n.sessionPodSection,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              SettingsIconContainer(
                icon: Icons.cloud_outlined,
                color: AppToneColors.of(context, stateTone).iconColor,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppBadge(label: stateLabel, tone: stateTone),
                        if (namespace?.isNotEmpty ?? false)
                          Text(
                            namespace!,
                            style: AppText.secondary(
                              theme,
                              cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.commonRefresh,
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox.square(
                        dimension: AppIconSize.md,
                        child: AppCircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (detail.isNotEmpty || error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (detail.isNotEmpty)
                  AppBanner(
                    tone: state == SessionPodDisplayState.failed
                        ? AppBadgeTone.danger
                        : AppBadgeTone.info,
                    message: detail,
                  ),
                if (detail.isNotEmpty && error != null)
                  const SizedBox(height: AppSpacing.sm),
                if (error != null)
                  AppBanner(
                    tone: AppBadgeTone.danger,
                    message: l10n.sessionPodLoadFailed,
                  ),
              ],
            ),
          ),
        ActionRow(
          icon: logsResponse == null
              ? Icons.article_outlined
              : Icons.expand_less_rounded,
          label: logsResponse == null
              ? l10n.sessionPodLogs
              : l10n.sessionPodHideLogs,
          color: cs.primary,
          isLoading: loading && logsResponse == null,
          onTap: loading
              ? null
              : logsResponse == null
              ? onLoadLogs
              : onHideLogs,
        ),
        if (logsResponse != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 320),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: SelectableText(
                      logsResponse.content.isEmpty
                          ? l10n.sessionPodLogsEmpty
                          : logsResponse.content,
                      style: AppText.secondary(
                        theme,
                      ).copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ),
                if (logsResponse.truncated)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      l10n.sessionPodLogsTruncated,
                      style: AppText.secondary(theme, cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        if (state == SessionPodDisplayState.paused)
          ActionRow(
            icon: Icons.play_arrow_rounded,
            label: l10n.sessionPodResume,
            color: cs.primary,
            isLoading: actionRunning,
            onTap: actionRunning ? null : onResume,
          )
        else if (state == SessionPodDisplayState.ready)
          ActionRow(
            icon: Icons.pause_rounded,
            label: l10n.sessionPodPause,
            color: cs.primary,
            isLoading: actionRunning,
            onTap: actionRunning ? null : onPause,
          ),
        ActionRow(
          icon: Icons.stop_circle_outlined,
          label: l10n.sessionPodKill,
          color: cs.error,
          onTap: actionRunning ? null : onKill,
        ),
      ],
    );
  }
}
