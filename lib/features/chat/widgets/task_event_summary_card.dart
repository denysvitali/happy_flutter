import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';

/// Compact summary card for a sub-agent task completion event.
///
/// Emitted by the CLI when a `Task` / `Agent` / `Workflow` (or local
/// async task like `local_workflow` / `local_bash`) finishes.  The wire
/// stream never carries the individual tool_use blocks from inside the
/// sub-agent, so when the CLI also stamps the on-disk transcript path on
/// the event, we surface it here as a tappable "Copy path" affordance —
/// the user can paste it into their editor to audit the sub-agent's
/// actual tool calls.
class TaskEventSummaryCard extends StatelessWidget {
  const TaskEventSummaryCard({
    required this.data,
    this.sessionId,
    super.key,
  });

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

  String? get _taskType {
    final raw = data['taskType'];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  /// Shell-backed tasks put a command in their summary; render it mono.
  bool get _isShellTask => _taskType == 'local_bash';

  String _statusGlyph() {
    if (_isFailed) return '⚠️';
    if (_isCompleted) return '✅';
    return '⏳';
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
    final summary = data['content'] as String? ??
        data['text'] as String? ??
        _statusLabel();
    final transcriptDir = _transcriptDir;
    final taskType = _taskType;
    final runId = _workflowRunId;

    final accentColor = _isFailed
        ? cs.error
        : _isCompleted
            ? cs.primary.withValues(alpha: 0.85)
            : cs.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: AppBorder.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_statusGlyph(), style: const TextStyle(fontSize: 14)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _statusLabel(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (taskType != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    taskType,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          if (summary.isNotEmpty &&
              summary != _statusLabel() &&
              data['redundantSummary'] != true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              summary,
              // `local_bash` notifications repeat the entire shell command
              // as their summary; clamp so one task can't own the screen.
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.85),
                fontFamily: _isShellTask ? 'monospace' : null,
                height: 1.35,
              ),
            ),
          ],
          if (transcriptDir != null) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () => _copyPath(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
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
          ],
          if (runId != null && transcriptDir == null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'run: $runId',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
