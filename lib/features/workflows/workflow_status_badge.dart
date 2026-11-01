import 'package:flutter/material.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/components/app_badge.dart';

import '../../core/models/workflow_run.dart';

/// Colored status chip for a [WorkflowRun].
class WorkflowStatusBadge extends StatelessWidget {
  /// Creates a [WorkflowStatusBadge].
  const WorkflowStatusBadge({required this.status, super.key});

  /// The workflow status string.
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = _resolve(status, context.l10n);
    return AppBadge(label: label, tone: tone, showToneIcon: false);
  }

  (String, AppBadgeTone) _resolve(String status, AppLocalizations l10n) {
    switch (status) {
      case WorkflowStatus.running:
        return (l10n.workflowStatusRunning, AppBadgeTone.info);
      case WorkflowStatus.paused:
        return (l10n.workflowStatusPaused, AppBadgeTone.warning);
      case WorkflowStatus.completed:
        return (l10n.workflowStatusCompleted, AppBadgeTone.success);
      case WorkflowStatus.failed:
        return (l10n.workflowStatusFailed, AppBadgeTone.danger);
      case WorkflowStatus.killed:
        return (l10n.workflowStatusKilled, AppBadgeTone.danger);
      case WorkflowStatus.cancelled:
        return (l10n.workflowStatusCancelled, AppBadgeTone.neutral);
      case WorkflowStatus.asyncLaunched:
        return (l10n.workflowStatusLaunching, AppBadgeTone.info);
      case WorkflowStatus.queued:
      case WorkflowStatus.pending:
        return (l10n.workflowStatusQueued, AppBadgeTone.warning);
      default:
        return (
          status.isEmpty ? l10n.workflowStatusUnknown : status,
          AppBadgeTone.neutral,
        );
    }
  }
}
