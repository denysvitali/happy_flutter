import 'package:flutter/material.dart';
import 'tool_section_view.dart';
import 'tool_status_indicator.dart';
import 'elapsed_time.dart';
import 'tool_error.dart';
import 'known_tools.dart';
import 'permission_footer.dart';
import '../utils/tool_error_parser.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

/// Main ToolView component with header, status, and elapsed time.
///
/// Displays tool call information with:
/// - Tool icon and title
/// - Optional subtitle/description
/// - Status indicator (running spinner, completed check, error)
/// - Elapsed time for running tools
/// - Tool-specific content view
/// - Permission footer (if applicable)
class ToolView extends StatelessWidget {
  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata (e.g., working directory).
  final Map<String, dynamic>? metadata;

  /// Optional list of messages (for Task tool).
  final List<Map<String, dynamic>>? messages;

  /// Session ID for permission actions.
  final String? sessionId;

  /// Callback when the tool header is pressed.
  final VoidCallback? onPress;

  const ToolView({
    super.key,
    required this.tool,
    this.metadata,
    this.messages,
    this.sessionId,
    this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = tool['name'] as String? ?? 'Unknown';
    final toolState = tool['state'] as String? ?? 'pending';
    final toolInput = tool['input'] as Map<String, dynamic>?;
    final toolResult = tool['result'];
    final permission = tool['permission'] as Map<String, dynamic>?;
    final createdAt = tool['createdAt'] as int?;

    final knownTool = KnownTools.get(toolName);
    final isMCP = toolName.startsWith('mcp__');

    // Determine tool title
    String toolTitle = toolName;
    if (isMCP) {
      toolTitle = _formatMCPTitle(toolName);
    } else if (knownTool != null) {
      if (knownTool.title is String) {
        toolTitle = knownTool.title;
      } else if (knownTool.title
          is String Function(Map<String, dynamic>, Map<String, dynamic>?)) {
        toolTitle = knownTool.title(tool, metadata);
      }
    }

    // Extract status if available
    String? status;
    if (knownTool?.extractStatus != null) {
      status = knownTool!.extractStatus!(tool, metadata);
    }

    // Extract subtitle
    String? subtitle;
    if (knownTool?.extractSubtitle != null) {
      subtitle = knownTool!.extractSubtitle!(tool, metadata);
    } else if (isMCP) {
      subtitle = null;
    }

    // Determine minimal mode
    bool minimal = knownTool?.minimal ?? true;
    if (isMCP) minimal = true;

    // Get icon
    final icon = KnownTools.iconFor(
      toolName,
      24,
      theme.colorScheme.onSurfaceVariant,
    );

    // Determine state enum
    final state = _parseToolState(toolState);

    // Check for tool use error
    final resultStr = toolResult?.toString() ?? '';
    final errorResult = ToolErrorParser.parse(resultStr);
    final isToolUseError = errorResult.isToolUseError;

    // Determine status indicator
    Widget? statusIcon;
    if (permission != null) {
      final permStatus = permission['status'] as String?;
      if (permStatus == 'denied' || permStatus == 'canceled') {
        statusIcon = Icon(
          Icons.remove_circle_outline,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        );
      }
    } else if (isToolUseError) {
      statusIcon = Icon(
        Icons.remove_circle_outline,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      );
    } else {
      switch (state) {
        case ToolState.running:
          statusIcon = const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
          break;
        case ToolState.completed:
          // No status icon for completed
          break;
        case ToolState.error:
          statusIcon = Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.error,
          );
          break;
        case ToolState.pending:
          break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          GestureDetector(
            onTap: onPress,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Icon container
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Align(alignment: Alignment.centerLeft, child: icon),
                  ),
                  const SizedBox(width: 8),
                  // Title and subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                toolTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (status != null)
                              Text(
                                ' $status',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Elapsed time for running tools
                  if (state == ToolState.running && createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ElapsedTimeWidget(startTime: createdAt),
                    ),
                  // Status icon
                  if (statusIcon != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: statusIcon,
                    ),
                ],
              ),
            ),
          ),

          // Content area
          if (!minimal)
            _buildContent(
              context,
              knownTool,
              toolInput,
              toolResult,
              state,
              errorResult,
              permission,
            ),

          // Permission footer
          if (permission != null &&
              sessionId != null &&
              toolName != 'AskUserQuestion')
            PermissionFooter(
              permission: permission,
              sessionId: sessionId!,
              toolName: toolName,
              toolInput: toolInput,
            ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ToolDefinition? knownTool,
    Map<String, dynamic>? toolInput,
    dynamic toolResult,
    ToolState state,
    ToolErrorParseResult errorResult,
    Map<String, dynamic>? permission,
  ) {
    final theme = Theme.of(context);
    final toolName = tool['name'] as String? ?? '';

    // Get the specific view component for this tool
    final specificView = _getToolViewComponent(toolName);
    if (specificView != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            specificView(this, tool, metadata, messages),
            // Show error if present
            if (state == ToolState.error &&
                toolResult != null &&
                permission != null &&
                (permission['status'] != 'denied' &&
                    permission['status'] != 'canceled') &&
                !(knownTool?.hideDefaultError ?? false) &&
                !errorResult.isToolUseError)
              ToolError(message: toolResult.toString()),
          ],
        ),
      );
    }

    // Fallback to default content
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Input section
          if (toolInput != null)
            ToolSectionView(
              title: 'INPUT',
              child: _buildCodeBlock(toolInput.toString()),
            ),
          // Output section
          if (state == ToolState.completed && toolResult != null)
            ToolSectionView(
              title: 'OUTPUT',
              child: _buildCodeBlock(
                toolResult is String ? toolResult : toolResult.toString(),
              ),
            ),
          // Error section
          if (state == ToolState.error &&
              toolResult != null &&
              permission != null &&
              (permission['status'] != 'denied' &&
                  permission['status'] != 'canceled') &&
              !errorResult.isToolUseError)
            ToolError(message: toolResult.toString()),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFFD4D4D4),
        ),
      ),
    );
  }

  ToolState _parseToolState(String state) {
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

  /// Format MCP tool name for display.
  /// Example: "mcp__linear__create_issue" -> "MCP: Linear Create Issue"
  String _formatMCPTitle(String toolName) {
    final withoutPrefix = toolName.replaceFirst('mcp__', '');
    final parts = withoutPrefix.split('__');

    if (parts.length >= 2) {
      final serverName = _snakeToPascal(parts[0]);
      final toolNamePart = _snakeToPascal(parts.skip(1).join('_'));
      return 'MCP: $serverName $toolNamePart';
    }

    return 'MCP: ${_snakeToPascal(withoutPrefix)}';
  }

  String _snakeToPascal(String str) {
    return str
        .split('_')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  /// Get the tool-specific view component for a tool name.
  /// Returns a function that builds the view widget.
  Widget Function(
    ToolView parent,
    Map<String, dynamic> tool,
    Map<String, dynamic>? metadata,
    List<Map<String, dynamic>>? messages,
  )?
  _getToolViewComponent(String toolName) {
    // Map of tool names to their view builder functions
    final views =
        <
          String,
          Widget Function(
            ToolView parent,
            Map<String, dynamic> tool,
            Map<String, dynamic>? metadata,
            List<Map<String, dynamic>>? messages,
          )
        >{};

    return views[toolName];
  }
}

/// Compact tool view for minimal mode (just header, no content).
class ToolViewMinimal extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const ToolViewMinimal({super.key, required this.tool, this.metadata});

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (state == 'running' && createdAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ElapsedTimeWidget(startTime: createdAt),
            ),
          const SizedBox(width: 4),
          ToolStatusIndicator(state: _parseState(state), size: 16),
        ],
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
