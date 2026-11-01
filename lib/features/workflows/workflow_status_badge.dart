import 'package:flutter/material.dart';
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
    final (label, tone) = _resolve(status);
    return AppBadge(label: label, tone: tone, showToneIcon: false);
  }

  (String, AppBadgeTone) _resolve(String status) {
    switch (status) {
      case WorkflowStatus.running:
        return ('Running', AppBadgeTone.info);
      case WorkflowStatus.paused:
        return ('Paused', AppBadgeTone.warning);
      case WorkflowStatus.completed:
        return ('Completed', AppBadgeTone.success);
      case WorkflowStatus.failed:
        return ('Failed', AppBadgeTone.danger);
      case WorkflowStatus.killed:
        return ('Killed', AppBadgeTone.danger);
      case WorkflowStatus.cancelled:
        return ('Cancelled', AppBadgeTone.neutral);
      case WorkflowStatus.asyncLaunched:
        return ('Launching', AppBadgeTone.info);
      case WorkflowStatus.queued:
      case WorkflowStatus.pending:
        return ('Queued', AppBadgeTone.warning);
      default:
        return (status.isEmpty ? 'Unknown' : status, AppBadgeTone.neutral);
    }
  }
}
