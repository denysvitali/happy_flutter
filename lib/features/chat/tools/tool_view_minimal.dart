import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/grok_acp_normalize.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
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

  /// Format MCP tool name for display.
  ///
  /// Example: `mcp__linear__create_issue` -> `Linear: Create Issue`
  static String _formatMCPTitle(String toolName) {
    final withoutPrefix = toolName.replaceFirst('mcp__', '');
    final parts = withoutPrefix.split('__');
    if (parts.length >= 2) {
      final serverName = _snakeToPascal(parts[0]);
      final toolPart = _snakeToPascal(parts.skip(1).join('_'));
      return '$serverName: $toolPart';
    }
    return 'MCP: ${_snakeToPascal(withoutPrefix)}';
  }

  static String _snakeToPascal(String str) {
    return str
        .split('_')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = normalizeGrokToolCall(
      tool['name'] as String? ?? 'Unknown',
      WireParsers.asMap(tool['input']),
    );
    final toolName = display.name;
    final state = tool['state'] as String? ?? 'pending';
    final createdAt = tool['createdAt'] as int?;

    final icon = KnownTools.iconFor(
      toolName,
      18,
      theme.colorScheme.onSurfaceVariant,
    );
    final String title;
    if (toolName.startsWith('mcp__') || toolName.contains('__')) {
      title = _formatMCPTitle(toolName);
    } else {
      title = KnownTools.titleFor(toolName, tool, metadata);
    }

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
