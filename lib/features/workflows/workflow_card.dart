import 'package:flutter/material.dart';

import '../../core/models/workflow_run.dart';
import '../../core/theme/app_tokens.dart';
import 'workflow_status_badge.dart';

/// Card displaying a single [WorkflowRun].
class WorkflowCard extends StatelessWidget {
  /// Creates a [WorkflowCard].
  const WorkflowCard({
    required this.run,
    required this.onTap,
    super.key,
  });

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
      parts.add('${run.totalTokens} tokens');
    }
    if (run.totalToolCalls != null && run.totalToolCalls! > 0) {
      parts.add('${run.totalToolCalls} tools');
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
                      run.workflowName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  WorkflowStatusBadge(status: run.status),
                ],
              ),
              if (run.summary != null && run.summary!.isNotEmpty) ...[
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
              if (_subtitle.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
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
