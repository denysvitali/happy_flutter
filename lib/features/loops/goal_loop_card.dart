import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/loop.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Card for a single goal loop.
///
/// The two questions this has to answer at a glance are "what is it trying to
/// do" and "is it still going", so the goal is the headline and the status
/// chip sits next to it. Everything else — iteration count, the reason it
/// stopped, the directory — is secondary.
class GoalLoopCard extends StatelessWidget {
  const GoalLoopCard({
    required this.loop,
    required this.onPauseToggle,
    required this.onResume,
    required this.onDelete,
    this.onOpenSession,
    super.key,
  });

  final Loop loop;
  final Future<void> Function(bool paused) onPauseToggle;
  final Future<void> Function() onResume;
  final Future<void> Function() onDelete;

  /// Opens the session for the iteration currently running (or the last one).
  final void Function(String sessionId)? onOpenSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final status = loop.loopStatus;
    final maxIterations = loop.maxIterations > 0 ? loop.maxIterations : 25;
    final sessionId = loop.activeSessionId?.isNotEmpty ?? false
        ? loop.activeSessionId
        : loop.lastSessionId;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    loop.goal,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _GoalStatusChip(loop: loop),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 15,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    loop.directory,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Iteration progress. A determinate bar is honest here: the cap
            // is real, and hitting it is one of the ways the loop stops.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: (loop.completedIterations / maxIterations).clamp(
                  0.0,
                  1.0,
                ),
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                color: status == LoopStatus.complete
                    ? AppColors.success
                    : cs.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  l10n.goalLoopsIterationProgress(
                    loop.completedIterations,
                    maxIterations,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (loop.isIterating)
                  Text(
                    l10n.goalLoopsIterating,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),

            if (loop.statusDetail.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  loop.statusDetail,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              children: [
                if (sessionId != null && sessionId.isNotEmpty)
                  TextButton.icon(
                    onPressed: onOpenSession == null
                        ? null
                        : () => onOpenSession!(sessionId),
                    icon: const Icon(Icons.forum_outlined, size: 18),
                    label: Text(l10n.goalLoopsOpenSession),
                  ),
                if (loop.isTerminal)
                  TextButton.icon(
                    onPressed: () => onResume(),
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: Text(l10n.goalLoopsResumeButton),
                  )
                else
                  TextButton.icon(
                    onPressed: () => onPauseToggle(!loop.paused),
                    icon: Icon(
                      loop.paused ? Icons.play_arrow : Icons.pause,
                      size: 18,
                    ),
                    label: Text(
                      loop.paused
                          ? l10n.loopsResumeButton
                          : l10n.loopsPauseButton,
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.loopsDeleteButton),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.loopsDeleteConfirmTitle),
        content: Text(l10n.goalLoopsDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.loopsDeleteButton),
          ),
        ],
      ),
    );
    if (ok ?? false) await onDelete();
  }
}

class _GoalStatusChip extends StatelessWidget {
  const _GoalStatusChip({required this.loop});

  final Loop loop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    late final Color bg;
    late final Color fg;
    late final String label;
    late final IconData icon;

    switch (loop.loopStatus) {
      case LoopStatus.complete:
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        label = l10n.goalLoopsStatusComplete;
        icon = Icons.check_circle;
      case LoopStatus.blocked:
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        label = l10n.goalLoopsStatusBlocked;
        icon = Icons.pan_tool_outlined;
      case LoopStatus.stalled:
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        label = l10n.goalLoopsStatusStalled;
        icon = Icons.sync_problem;
      case LoopStatus.exhausted:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        label = l10n.goalLoopsStatusExhausted;
        icon = Icons.hourglass_disabled;
      case LoopStatus.running:
        if (loop.paused) {
          bg = cs.secondaryContainer;
          fg = cs.onSecondaryContainer;
          label = l10n.loopsStatusPaused;
          icon = Icons.pause;
        } else {
          bg = cs.primaryContainer;
          fg = cs.onPrimaryContainer;
          label = l10n.goalLoopsStatusRunning;
          icon = Icons.autorenew;
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
