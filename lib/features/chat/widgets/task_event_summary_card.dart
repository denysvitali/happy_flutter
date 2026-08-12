import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/task_label.dart';

/// Slim system-style row for a sub-agent task completion event, matching
/// the agent-event start/progress markers so a task's lifecycle reads as
/// one visual family in the timeline.
///
/// Emitted by the CLI when a `Task` / `Agent` / `Workflow` (or local
/// async task like `local_workflow` / `local_bash`) finishes.  The wire
/// stream never carries the individual tool_use blocks from inside the
/// sub-agent, so when the CLI also stamps the on-disk transcript path on
/// the event, we surface it here as a tappable "Copy path" affordance —
/// the user can paste it into their editor to audit the sub-agent's
/// actual tool calls.
class TaskEventSummaryCard extends StatelessWidget {
  const TaskEventSummaryCard({required this.data, this.sessionId, super.key});

  final Map<String, dynamic> data;
  final String? sessionId;

  bool get _isCompleted => data['taskStatus'] == 'completed';
  bool get _isFailed => data['taskStatus'] == 'failed';

  String? get _transcriptDir {
    final raw = data['transcriptDir'];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  String? get _workflowRunId {
    final raw = data['workflowRunId'];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  IconData _statusIcon() {
    if (_isFailed) return Icons.error_rounded;
    if (_isCompleted) return Icons.check_circle_rounded;
    return Icons.autorenew_rounded;
  }

  String _statusLabel() {
    if (_isFailed) return 'Task failed';
    if (_isCompleted) return 'Task completed';
    return 'Task updated';
  }

  Future<void> _copyPath(BuildContext context) async {
    final path = _transcriptDir;
    if (path == null) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied transcript path: $path'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final summary =
        data['content'] as String? ?? data['text'] as String? ?? _statusLabel();
    final transcriptDir = _transcriptDir;
    final runId = _workflowRunId;

    final muted = cs.onSurfaceVariant.withValues(alpha: 0.85);
    // The icon alone carries the status color — a column of finished
    // tasks reads as a wall of green when the label is tinted too.
    final iconColor = _isFailed
        ? cs.error
        : _isCompleted
        ? AppColors.success
        : muted;
    final labelColor = _isFailed ? cs.error : muted;
    final showSummary =
        summary.isNotEmpty &&
        summary != _statusLabel() &&
        data['redundantSummary'] != true;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.xs,
          ),
          // Left-aligned sibling of the task_started marker (icon ·
          // label · title), in the same column as the tool rows so the
          // transcript keeps one left edge.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_statusIcon(), size: 13, color: iconColor),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _statusLabel(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (showSummary)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 13 + AppSpacing.xs,
                    top: 1,
                  ),
                  child: Text(
                    // `local_bash` notifications repeat the entire shell
                    // command as their summary; clamp so one task can't
                    // own the screen. Title sits on its own line so a
                    // long path cannot wrap mid-word after the prefix.
                    compactTaskLabel(summary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                    textAlign: TextAlign.start,
                  ),
                ),
            ],
          ),
        ),
        if (transcriptDir != null)
          InkWell(
            onTap: () => _copyPath(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        transcriptDir,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.copy_rounded,
                      size: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (runId != null && transcriptDir == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Center(
              child: Text(
                'run: $runId',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
