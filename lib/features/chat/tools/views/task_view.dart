import 'package:flutter/material.dart';

import '../tool_status_indicator.dart';

/// Compact view for a Task (sub-agent) tool call.
///
/// Renders as a small tappable block that navigates to the full
/// agent conversation screen when tapped. The inline sub-chat
/// timeline has been replaced with navigation to keep the chat
/// feed clean.
class TaskView extends StatelessWidget {

  /// Creates a [TaskView].
  const TaskView({
    required this.tool,
    required this.onNavigate,
    super.key,
    this.metadata,
    this.messages,
  });

  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Called when the user taps the block to open the agent conversation.
  final VoidCallback onNavigate;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  /// All session messages (legacy fallback, unused in this widget).
  final List<Map<String, dynamic>>? messages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final input = tool['input'] as Map<String, dynamic>?;
    final description =
        input?['description'] as String? ??
        input?['prompt'] as String? ??
        'Task';
    final toolState = tool['state'] as String? ?? 'pending';
    final parsedState = _parseState(toolState);

    final children = tool['children'] as List<dynamic>?;
    final childCount = children?.length ?? 0;

    final Color borderColor;
    switch (parsedState) {
      case ToolState.running:
        borderColor = theme.colorScheme.primary.withAlpha(100);
      case ToolState.completed:
        borderColor = const Color(0xFF34C759).withAlpha(100);
      case ToolState.error:
        borderColor = theme.colorScheme.error.withAlpha(100);
      case ToolState.pending:
        borderColor = theme.colorScheme.outlineVariant;
    }

    return GestureDetector(
      onTap: onNavigate,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            // State indicator
            SizedBox(
              width: 16,
              height: 16,
              child: ToolStatusIndicator(state: parsedState, size: 16),
            ),
            const SizedBox(width: 8),

            // Description
            Expanded(
              child: Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),

            // Child count badge (if any)
            if (childCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '$childCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  ToolState _parseState(String state) {
    switch (state) {
      case 'running':
        return ToolState.running;
      case 'completed':
        return ToolState.completed;
      case 'error':
        return ToolState.error;
      default:
        return ToolState.pending;
    }
  }
}
