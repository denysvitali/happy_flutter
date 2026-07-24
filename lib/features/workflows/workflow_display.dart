import 'package:flutter/material.dart';

import '../../core/models/workflow_run.dart';
import '../../core/theme/app_colors.dart';

/// Display helpers shared by the workflows list and run detail screens.

/// Icon + colour for a workflow agent/phase wire state.
///
/// The wire sends `running` / `progress` for live work, so those cases must
/// be handled explicitly or every in-flight item falls into the pending
/// bucket. [pendingIcon] distinguishes the two call sites that existed
/// before this was shared: agent rows show an hourglass while waiting,
/// phase rows show an empty circle.
(IconData, Color) workflowStateStyle(
  String state,
  ColorScheme cs, {
  IconData pendingIcon = Icons.circle_outlined,
}) {
  switch (state) {
    case 'done':
    case 'completed':
      return (Icons.check_circle_outline_rounded, AppColors.success);
    case 'error':
    case 'failed':
      return (Icons.error_outline_rounded, cs.error);
    case 'start':
    case 'running':
    case 'progress':
      return (Icons.play_circle_outline_rounded, cs.primary);
    default:
      return (pendingIcon, cs.onSurfaceVariant);
  }
}

/// Matches auto-generated run names (`wf_a6c2cfba-460`) that carry no
/// information beyond the run id itself.
final RegExp _opaqueName = RegExp(r'^wf_[a-z0-9-]+$');

/// Whether the run's wire name is just an auto-generated id.
bool workflowNameIsOpaque(WorkflowRun run) {
  final name = run.workflowName;
  return name.isEmpty || name == run.runId || _opaqueName.hasMatch(name);
}

/// Friendly title: hides auto-generated `wf_*` names that just repeat
/// the run id.
String workflowDisplayName(WorkflowRun run) {
  return workflowNameIsOpaque(run) ? 'Workflow run' : run.workflowName;
}

/// Formats large counts compactly: 999 → "999", 19698 → "19.7k",
/// 1200000 → "1.2M".
String formatWorkflowCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final k = value / 1000;
    if (k >= 100) {
      final rounded = k.round();
      return rounded >= 1000 ? '1M' : '${rounded}k';
    }
    return '${_trimDecimal(k)}k';
  }
  return '${_trimDecimal(value / 1000000)}M';
}

String _trimDecimal(double value) {
  final s = value.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}
