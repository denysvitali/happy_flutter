import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/sync_service.dart';
import 'markdown/markdown.dart';
import 'tools/known_tools.dart';
import 'tools/tool_status_indicator.dart';

/// Full-screen view for a Task (sub-agent) tool call's conversation.
///
/// Shows the sidechain messages (children) of the Task as a scrollable
/// chat-like feed. Updates live as new sidechain messages stream in from
/// the background agent output watcher.
class AgentConversationScreen extends StatefulWidget {
  /// Creates an [AgentConversationScreen].
  const AgentConversationScreen({
    required this.sessionId,
    required this.messageId,
    super.key,
    this.taskData,
  });

  /// The ID of the session this Task belongs to.
  final String sessionId;

  /// The ID of the Task tool-call message.
  final String messageId;

  /// Pre-loaded task message data passed via route extra.
  final Map<String, dynamic>? taskData;

  @override
  State<AgentConversationScreen> createState() =>
      _AgentConversationScreenState();
}

class _AgentConversationScreenState
    extends State<AgentConversationScreen> {
  final ScrollController _scroll = ScrollController();
  StreamSubscription<String>? _messageSubscription;
  Map<String, dynamic>? _taskMsg;
  int _prevChildCount = 0;

  @override
  void initState() {
    super.initState();
    _taskMsg = widget.taskData;
    _messageSubscription = sync.onSessionMessagesChanged
        .where((id) => id == widget.sessionId)
        .listen((_) => _refresh());
    _refresh(); // initial load
  }

  void _refresh() {
    if (!mounted) return;
    final messages =
        sync.sessionMessages[widget.sessionId] ?? [];
    for (final msg in messages) {
      if (msg['id'] == widget.messageId) {
        final children = msg['children'] as List<dynamic>?;
        final count = children?.length ?? 0;
        if (count != _prevChildCount) {
          setState(() {
            _taskMsg = Map<String, dynamic>.from(msg);
            _prevChildCount = count;
          });
          // Auto-scroll to bottom when new messages arrive.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              _scroll.animateTo(
                _scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
        return;
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final input =
        _taskMsg?['input'] as Map<String, dynamic>?;
    final description =
        input?['description'] as String? ??
        input?['prompt'] as String? ??
        'Agent';
    final state =
        _taskMsg?['state'] as String? ?? 'pending';
    final isRunning = state == 'running';
    final children =
        (_taskMsg?['children'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          description,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (isRunning)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: children.isEmpty
          ? Center(
              child: isRunning
                  ? const CircularProgressIndicator()
                  : Text(
                      'No messages yet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            )
          : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: children.length,
              itemBuilder: (context, i) =>
                  _buildChildMessage(theme, children[i]),
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
        padding: const EdgeInsets.only(bottom: 8),
        child: isThinking
            ? _ThinkingRow(theme: theme)
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SimpleMarkdownView(markdown: content),
              ),
      );
    }

    if (kind == 'tool-call') {
      return _ToolRow(
        theme: theme,
        msg: msg,
        metadata: _taskMsg?['metadata'] as Map<String, dynamic>?,
      );
    }

    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Thinking row
// ---------------------------------------------------------------------------

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            'Thinking...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tool call row
// ---------------------------------------------------------------------------

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.theme,
    required this.msg,
    required this.metadata,
  });
  final ThemeData theme;
  final Map<String, dynamic> msg;
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final toolName = msg['name'] as String? ?? 'Unknown';
    final state = msg['state'] as String? ?? 'pending';
    final toolState = _parseState(state);

    final knownTool = KnownTools.get(toolName);
    var title = toolName;
    if (knownTool?.extractDescription != null) {
      title =
          knownTool!.extractDescription!(msg, metadata) ?? toolName;
    } else if (knownTool?.title != null && knownTool!.title is String) {
      title = knownTool.title as String;
    }

    final icon =
        KnownTools.iconFor(toolName, 14, theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 14, height: 14, child: icon),
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
          SizedBox(
            width: 14,
            height: 14,
            child: ToolStatusIndicator(state: toolState, size: 14),
          ),
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
