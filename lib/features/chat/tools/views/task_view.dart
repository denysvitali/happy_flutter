import 'package:flutter/material.dart';
import '../tool_section_view.dart';
import '../tool_status_indicator.dart';
import '../known_tools.dart';

/// View for displaying Task tool with nested tool calls.
class TaskView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;
  final List<Map<String, dynamic>>? messages;

  const TaskView({super.key, required this.tool, this.metadata, this.messages});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (messages == null || messages!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter for completed, running, or error tool calls
    final filteredTools = <_FilteredTool>[];

    for (final message in messages!) {
      final kind = message['kind'] as String?;
      if (kind != 'tool-call') continue;

      final toolData = message['tool'] as Map<String, dynamic>?;
      if (toolData == null) continue;

      final state = toolData['state'] as String?;
      if (state != 'running' && state != 'completed' && state != 'error') {
        continue;
      }

      final toolName = toolData['name'] as String? ?? 'Unknown';
      final knownTool = KnownTools.get(toolName);

      // Extract title
      String title = toolName;
      if (knownTool?.extractDescription != null) {
        title = knownTool!.extractDescription!(toolData, metadata) ?? toolName;
      } else if (knownTool?.title != null) {
        if (knownTool!.title is String) {
          title = knownTool.title;
        } else if (knownTool.title
            is String Function(Map<String, dynamic>, Map<String, dynamic>?)) {
          title = knownTool.title(toolData, metadata);
        }
      }

      filteredTools.add(
        _FilteredTool(tool: toolData, title: title, state: _parseState(state!)),
      );
    }

    if (filteredTools.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show last 3 tools, with count of remaining
    final visibleTools = filteredTools.length <= 3
        ? filteredTools
        : filteredTools.skip(filteredTools.length - 3).toList();
    final remainingCount = filteredTools.length - 3;

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...visibleTools.map((item) => _buildToolItem(context, item)),
          if (remainingCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ $remainingCount more tools',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolItem(BuildContext context, _FilteredTool item) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              item.title,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            height: 20,
            child: _buildStatusIcon(item.state, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ToolState state, ThemeData theme) {
    switch (state) {
      case ToolState.running:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case ToolState.completed:
        return Icon(
          Icons.check_circle,
          size: 16,
          color: const Color(0xFF34C759),
        );
      case ToolState.error:
        return Icon(Icons.error, size: 16, color: theme.colorScheme.error);
      case ToolState.pending:
        return const SizedBox.shrink();
    }
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

class _FilteredTool {
  final Map<String, dynamic> tool;
  final String title;
  final ToolState state;

  _FilteredTool({required this.tool, required this.title, required this.state});
}
