import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'elapsed_time.dart';
import 'known_tools.dart';
import 'tool_status_indicator.dart';
import 'tool_view_helpers.dart';

/// Compact tool view for minimal mode (header only, no expandable content).
class ToolViewMinimal extends StatelessWidget {
  /// Creates a [ToolViewMinimal].
  const ToolViewMinimal({
    required this.tool,
    super.key,
    this.metadata,
  });

  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata (e.g., working directory).
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = tool['name'] as String? ?? 'Unknown';
    final state = tool['state'] as String? ?? 'pending';
    final createdAt = tool['createdAt'] as int?;

    final icon = KnownTools.iconFor(
      toolName,
      18,
      theme.colorScheme.onSurfaceVariant,
    );
    final title = KnownTools.titleFor(toolName, tool, metadata);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state == 'running' && createdAt != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: ElapsedTimeWidget(startTime: createdAt),
            ),
          const SizedBox(width: AppSpacing.xs),
          ToolStatusIndicator(
            state: parseToolState(state),
            size: 16,
          ),
        ],
      ),
    );
  }
}
