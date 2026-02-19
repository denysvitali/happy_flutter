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
/// sub-agent's messages (text + tool calls) as a mini chat.
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
    final description = input?['description'] as String? ??
        input?['prompt'] as String?;
    final toolState =
        widget.tool['state'] as String? ?? 'pending';

    final children = _getChildren();
    final toolCalls = children
        .where((m) => m['kind'] == 'tool-call')
        .toList();
    final completedCount = toolCalls
        .where((t) =>
            t['state'] == 'completed')
        .length;
    final errorCount = toolCalls
        .where((t) => t['state'] == 'error')
        .length;
    final runningCount = toolCalls
        .where((t) => t['state'] == 'running')
        .length;
    final totalTools = toolCalls.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Agent description
        if (description != null && description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
              left: 4,
              right: 4,
            ),
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Progress bar
        if (totalTools > 0)
          Padding(
            padding: const EdgeInsets.only(
              bottom: 8,
              left: 4,
              right: 4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: totalTools > 0
                          ? (completedCount + errorCount) /
                              totalTools
                          : 0,
                      minHeight: 4,
                      backgroundColor: theme
                          .colorScheme.surfaceContainerHighest,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(
                        errorCount > 0
                            ? theme.colorScheme.error
                            : const Color(0xFF34C759),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _progressLabel(
                    completedCount,
                    runningCount,
                    errorCount,
                    totalTools,
                    toolState,
                  ),
                  style:
                      theme.textTheme.labelSmall?.copyWith(
                    color:
                        theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

        // Sub-chat messages
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

  String _progressLabel(
    int completed,
    int running,
    int errors,
    int total,
    String toolState,
  ) {
    if (toolState == 'completed' || toolState == 'error') {
      if (errors > 0) {
        return '$completed/$total ($errors failed)';
      }
      return '$completed/$total done';
    }
    return '$completed/$total';
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
        : children.sublist(
            children.length - collapsedCount);
    final hiddenCount = children.length - visible.length;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 2,
          ),
        ),
      ),
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hiddenCount > 0)
            GestureDetector(
              onTap: () => setState(() => _expanded = true),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '+ $hiddenCount more messages',
                  style:
                      theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ...visible
              .map((msg) => _buildChildMessage(theme, msg)),
        ],
      ),
    );
  }

  Widget _buildChildMessage(
    ThemeData theme,
    Map<String, dynamic> msg,
  ) {
    final kind = msg['kind'] as String?;

    // Text messages from sub-agent
    if (kind == 'text') {
      final content =
          msg['content'] as String? ?? '';
      if (content.isEmpty) {
        return const SizedBox.shrink();
      }
      final isThinking = msg['isThinking'] == true;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: isThinking
            ? Text(
                'Thinking...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              )
            : SimpleMarkdownView(markdown: content),
      );
    }

    // Tool calls from sub-agent
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
        title = knownTool.title;
      } else if (knownTool.title
          is String Function(
            Map<String, dynamic>,
            Map<String, dynamic>?,
          )) {
        title = knownTool.title(msg, widget.metadata);
      }
    }

    final icon = KnownTools.iconFor(
      toolName,
      16,
      theme.colorScheme.onSurfaceVariant,
    );

    return GestureDetector(
      onTap: () => _showToolDetail(context, msg, toolName),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: icon),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusIcon(
              _parseState(state),
              theme,
            ),
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
        return const SizedBox(
          width: 14,
          height: 14,
          child:
              CircularProgressIndicator(strokeWidth: 1.5),
        );
      case ToolState.completed:
        return const Icon(
          Icons.check_circle,
          size: 14,
          color: Color(0xFF34C759),
        );
      case ToolState.error:
        return Icon(
          Icons.error,
          size: 14,
          color: theme.colorScheme.error,
        );
      case ToolState.pending:
        return const SizedBox(width: 14, height: 14);
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
    final input =
        tool['input'] as Map<String, dynamic>?;
    final result = tool['result'];

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurfaceVariant
                .withAlpha(77),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
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
              const SizedBox(width: 8),
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
                state: _parseState(state),
                size: 18,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              if (input != null)
                _buildJsonSection(
                  theme,
                  'Input',
                  Icons.input,
                  const JsonEncoder.withIndent('  ')
                      .convert(input),
                ),
              if (input != null)
                const SizedBox(height: 12),
              if (result != null)
                _buildJsonSection(
                  theme,
                  state == 'error' ? 'Error' : 'Output',
                  state == 'error'
                      ? Icons.error_outline
                      : Icons.output,
                  result is Map
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

  Widget _buildJsonSection(
    ThemeData theme,
    String title,
    IconData icon,
    String content, {
    bool isError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isError
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style:
                    theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      isError ? theme.colorScheme.error : null,
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
                  Icons.copy,
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            content,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFFD4D4D4),
            ),
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
