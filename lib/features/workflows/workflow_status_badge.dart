import 'package:flutter/material.dart';

import '../../core/models/workflow_run.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Colored status chip for a [WorkflowRun].
class WorkflowStatusBadge extends StatelessWidget {
  /// Creates a [WorkflowStatusBadge].
  const WorkflowStatusBadge({required this.status, super.key});

  /// The workflow status string.
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = _resolve(status, cs);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppFontSize.xxs,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  (String, Color) _resolve(String status, ColorScheme cs) {
    switch (status) {
      case WorkflowStatus.running:
        return ('Running', cs.primary);
      case WorkflowStatus.paused:
        return ('Paused', cs.tertiary);
      case WorkflowStatus.completed:
        return ('Completed', AppColors.success);
      case WorkflowStatus.failed:
        return ('Failed', cs.error);
      case WorkflowStatus.killed:
        return ('Killed', cs.error);
      default:
        return (status, cs.onSurfaceVariant);
    }
  }
}
