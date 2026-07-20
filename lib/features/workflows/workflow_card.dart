import 'package:flutter/material.dart';

import '../../core/models/workflow_run.dart';
import '../../core/theme/app_tokens.dart';
import 'workflow_display.dart';
import 'workflow_status_badge.dart';

/// Static wait copy for a live run that is not actively starting yet, so
/// the body never contradicts the status badge (queued/paused ≠ starting)
/// and nothing animates indefinitely while the run waits.
String _liveWaitLabel(String status) {
  switch (status) {
    case WorkflowStatus.paused:
      return 'Paused';
    case WorkflowStatus.queued:
    case WorkflowStatus.pending:
      return 'Queued';
    default:
      return 'In progress';
  }
}

/// Card displaying a single [WorkflowRun].
class WorkflowCard extends StatelessWidget {
  /// Creates a [WorkflowCard].
  const WorkflowCard({required this.run, required this.onTap, super.key});

  /// The workflow run to display.
  final WorkflowRun run;

  /// Called when the user taps the card.
  final VoidCallback onTap;

  String get _subtitle {
    final parts = <String>[];
    if (run.agentCount != null && run.agentCount! > 0) {
      parts.add('${run.agentCount} agents');
    }
    if (run.totalTokens != null && run.totalTokens! > 0) {
      parts.add('${formatWorkflowCount(run.totalTokens!)} tokens');
    }
    if (run.totalToolCalls != null && run.totalToolCalls! > 0) {
      parts.add('${formatWorkflowCount(run.totalToolCalls!)} tools');
    }
    return parts.join(' · ');
  }

  double get _phaseProgress {
    final phases = run.phases;
    if (phases.isEmpty) return 0;
    final completed = run.workflowProgress
        .whereType<WorkflowPhaseEvent>()
        .map((e) => e.index)
        .fold(0, (max, idx) => idx > max ? idx : max);
    return (completed / phases.length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtitle = _subtitle;
    final hasSummary = run.summary != null && run.summary!.isNotEmpty;
    final hasDetails =
        hasSummary || run.phases.isNotEmpty || subtitle.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 18,
                    color: cs.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      workflowDisplayName(run),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  WorkflowStatusBadge(status: run.status),
                ],
              ),
              if (workflowNameIsOpaque(run)) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  run.runId,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (hasSummary) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  run.summary!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (run.phases.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: _phaseProgress,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${run.phases.length} phases',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (!hasDetails) ...[
                const SizedBox(height: AppSpacing.xs),
                if (WorkflowStatus.isStarting(run.status))
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Starting…',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                else if (WorkflowStatus.isLive(run.status))
                  Text(
                    _liveWaitLabel(run.status),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    'No progress details',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
