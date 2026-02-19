import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tool_status_indicator.dart';
import '../known_tools.dart';
import '../../markdown/markdown.dart';

/// View for displaying Task tool (sub-agents) as a nested
/// sub-chat conversation.
///
/// Shows the agent description, a progress summary, and the
/// sub-agent's messages (text + tool calls) as a mini timeline.
class TaskView extends StatefulWidget {
  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  /// All session messages (legacy fallback).
  final List<Map<String, dynamic>>? messages;

  const TaskView({
    super.key,
    required this.tool,
    this.metadata,
    this.messages,
  });

  @override
  State<TaskView> createState() => _TaskViewState();
}

class _TaskViewState extends State<TaskView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final input =
        widget.tool['input'] as Map<String, dynamic>?;
    final description =
        input?['description'] as String? ??
        input?['prompt'] as String?;
    final toolState =
        widget.tool['state'] as String? ?? 'pending';

    final children = _getChildren();
    final toolCalls = children
        .where((m) => m['kind'] == 'tool-call')
        .toList();
    final completedCount = toolCalls
        .where((t) => t['state'] == 'completed')
        .length;
    final errorCount = toolCalls
        .where((t) => t['state'] == 'error')
        .length;
    final runningCount = toolCalls
        .where((t) => t['state'] == 'running')
        .length;
    final totalTools = toolCalls.length;

    final parsedState = _parseState(toolState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Task description card
        if (description != null && description.isNotEmpty)
          _TaskDescriptionCard(
            description: description,
            state: parsedState,
          ),

        // Progress section
        if (totalTools > 0)
          _ProgressSection(
            completedCount: completedCount,
            runningCount: runningCount,
            errorCount: errorCount,
            totalTools: totalTools,
            toolState: toolState,
          ),

        // Sub-chat timeline
        if (children.isNotEmpty)
          _buildSubChat(theme, children),
      ],
    );
  }

  /// Get child messages from sidechain grouping.
  List<Map<String, dynamic>> _getChildren() {
    final children =
        widget.tool['children'] as List<dynamic>?;
    if (children != null && children.isNotEmpty) {
      return children
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }

  Widget _buildSubChat(
    ThemeData theme,
    List<Map<String, dynamic>> children,
  ) {
    const collapsedCount = 8;
    final showAll =
        _expanded || children.length <= collapsedCount;
    final visible = showAll
        ? children
        : children.sublist(children.length - collapsedCount);
    final hiddenCount = children.length - visible.length;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 2,
            ),
          ),
        ),
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.only(left: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hiddenCount > 0)
              GestureDetector(
                onTap: () =>
                    setState(() => _expanded = true),
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: 6,
                    top: 2,
                  ),
                  child: Text(
                    '+ $hiddenCount more messages',
                    style:
                        theme.textTheme.labelSmall
                            ?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ...visible.map(
              (msg) => _buildChildMessage(theme, msg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildMessage(
    ThemeData theme,
    Map<String, dynamic> msg,
  ) {
    final kind = msg['kind'] as String?;

    if (kind == 'text') {
      final content = msg['content'] as String? ?? '';
      if (content.isEmpty) return const SizedBox.shrink();
      final isThinking = msg['isThinking'] == true;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: isThinking
            ? _ThinkingChip(theme: theme)
            : SimpleMarkdownView(markdown: content),
      );
    }

    if (kind == 'tool-call') {
      return _buildToolItem(theme, msg);
    }

    return const SizedBox.shrink();
  }

  Widget _buildToolItem(
    ThemeData theme,
    Map<String, dynamic> msg,
  ) {
    final toolName = msg['name'] as String? ?? 'Unknown';
    final state = msg['state'] as String? ?? 'pending';
    final knownTool = KnownTools.get(toolName);

    String title = toolName;
    if (knownTool?.extractDescription != null) {
      title =
          knownTool!.extractDescription!(
                msg,
                widget.metadata,
              ) ??
          toolName;
    } else if (knownTool?.title != null) {
      if (knownTool!.title is String) {
        title = knownTool.title as String;
      } else if (knownTool.title
          is String Function(
            Map<String, dynamic>,
            Map<String, dynamic>?,
          )) {
        title = (knownTool.title as String Function(
          Map<String, dynamic>,
          Map<String, dynamic>?,
        ))(msg, widget.metadata);
      }
    }

    final toolState = _parseState(state);
    final icon = KnownTools.iconFor(
      toolName,
      14,
      theme.colorScheme.onSurfaceVariant,
    );

    return GestureDetector(
      onTap: () => _showToolDetail(context, msg, toolName),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: icon,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusIcon(toolState, theme),
          ],
        ),
      ),
    );
  }

  void _showToolDetail(
    BuildContext context,
    Map<String, dynamic> tool,
    String toolName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) =>
            _ToolDetailSheet(
          tool: tool,
          toolName: toolName,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Widget _buildStatusIcon(
    ToolState state,
    ThemeData theme,
  ) {
    switch (state) {
      case ToolState.running:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: theme.colorScheme.primary,
          ),
        );
      case ToolState.completed:
        return const Icon(
          Icons.check_circle_rounded,
          size: 13,
          color: Color(0xFF34C759),
        );
      case ToolState.error:
        return Icon(
          Icons.error_rounded,
          size: 13,
          color: theme.colorScheme.error,
        );
      case ToolState.pending:
        return const SizedBox(width: 13, height: 13);
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

// ---------------------------------------------------------------------------
// Task description card
// ---------------------------------------------------------------------------

class _TaskDescriptionCard extends StatelessWidget {
  const _TaskDescriptionCard({
    required this.description,
    required this.state,
  });

  final String description;
  final ToolState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color borderColor;
    final Color iconColor;
    final IconData icon;
    switch (state) {
      case ToolState.running:
        borderColor = theme.colorScheme.primary.withAlpha(120);
        iconColor = theme.colorScheme.primary;
        icon = Icons.smart_toy_rounded;
      case ToolState.completed:
        borderColor =
            const Color(0xFF34C759).withAlpha(120);
        iconColor = const Color(0xFF34C759);
        icon = Icons.task_alt_rounded;
      case ToolState.error:
        borderColor =
            theme.colorScheme.error.withAlpha(120);
        iconColor = theme.colorScheme.error;
        icon = Icons.error_outline_rounded;
      case ToolState.pending:
        borderColor =
            theme.colorScheme.outlineVariant;
        iconColor = theme.colorScheme.onSurfaceVariant;
        icon = Icons.pending_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress section
// ---------------------------------------------------------------------------

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.completedCount,
    required this.runningCount,
    required this.errorCount,
    required this.totalTools,
    required this.toolState,
  });

  final int completedCount;
  final int runningCount;
  final int errorCount;
  final int totalTools;
  final String toolState;

  String _label() {
    final isDone =
        toolState == 'completed' || toolState == 'error';
    if (isDone) {
      if (errorCount > 0) {
        return '$completedCount/$totalTools'
            ' ($errorCount failed)';
      }
      return '$completedCount/$totalTools done';
    }
    return '$completedCount/$totalTools';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = totalTools > 0
        ? (completedCount + errorCount) / totalTools
        : 0.0;
    final barColor = errorCount > 0
        ? theme.colorScheme.error
        : const Color(0xFF34C759);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  barColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _label(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thinking chip
// ---------------------------------------------------------------------------

class _ThinkingChip extends StatelessWidget {
  const _ThinkingChip({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome_rounded,
          size: 12,
          color: theme.colorScheme.onSurfaceVariant
              .withAlpha(153),
        ),
        const SizedBox(width: 4),
        Text(
          'Thinking...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant
                .withAlpha(153),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tool detail bottom sheet
// ---------------------------------------------------------------------------

class _ToolDetailSheet extends StatelessWidget {
  const _ToolDetailSheet({
    required this.tool,
    required this.toolName,
    required this.scrollController,
  });
  final Map<String, dynamic> tool;
  final String toolName;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = tool['state'] as String? ?? 'pending';
    final input = tool['input'] as Map<String, dynamic>?;
    final result = tool['result'];
    final toolState = _parseState(state);

    return Column(
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant
                .withAlpha(77),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              KnownTools.iconFor(
                toolName,
                20,
                theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  toolName,
                  style:
                      theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ToolStatusIndicator(
                state: toolState,
                size: 18,
              ),
            ],
          ),
        ),

        Divider(
          height: 20,
          color: theme.colorScheme.outlineVariant,
        ),

        // Scrollable body
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              16, 0, 16, 24,
            ),
            children: [
              if (input != null)
                _JsonSection(
                  theme: theme,
                  title: 'Input',
                  icon: Icons.input_rounded,
                  content: const JsonEncoder.withIndent('  ')
                      .convert(input),
                ),
              if (input != null)
                const SizedBox(height: 12),
              if (result != null)
                _JsonSection(
                  theme: theme,
                  title:
                      state == 'error' ? 'Error' : 'Output',
                  icon: state == 'error'
                      ? Icons.error_outline_rounded
                      : Icons.output_rounded,
                  content: result is Map
                      ? const JsonEncoder.withIndent('  ')
                          .convert(result)
                      : result.toString(),
                  isError: state == 'error',
                ),
            ],
          ),
        ),
      ],
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

// ---------------------------------------------------------------------------
// JSON section widget
// ---------------------------------------------------------------------------

class _JsonSection extends StatelessWidget {
  const _JsonSection({
    required this.theme,
    required this.title,
    required this.icon,
    required this.content,
    this.isError = false,
  });

  final ThemeData theme;
  final String title;
  final IconData icon;
  final String content;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        isError ? theme.colorScheme.error : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: labelColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style:
                    theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            Builder(
              builder: (ctx) => GestureDetector(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(text: content),
                  );
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color:
                      theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isError
                  ? theme.colorScheme.error.withAlpha(80)
                  : const Color(0xFF2D2D2D),
              width: 1,
            ),
          ),
          child: SelectableText(
            content,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFFD4D4D4),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
