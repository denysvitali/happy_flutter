import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'markdown/markdown.dart';
import 'tools/tools.dart';

/// Message widget for displaying chat messages with full markdown support.
///
/// Supports rich text formatting including headers, lists, code blocks,
/// tables, mermaid diagrams, and text selection via long-press.
class MessageWidget extends StatelessWidget {
  final Map<String, dynamic> messageData;
  final bool isFromCurrentUser;
  final Map<String, dynamic>? metadata;
  final List<Map<String, dynamic>>? messages;
  final String? sessionId;
  final void Function(String)? onOptionPress;

  const MessageWidget({
    super.key,
    required this.messageData,
    this.isFromCurrentUser = false,
    this.metadata,
    this.messages,
    this.sessionId,
    this.onOptionPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = messageData['kind'] as String? ?? 'unknown';

    // Agent events render as a centered system-style message
    if (kind == 'agent-event') {
      return _AgentEventWidget(event: messageData['event']);
    }

    final content = messageData['content'] ?? messageData['text'] ?? '';
    final text = content is String ? content : content.toString();

    // Tool calls render without bubble styling
    if (kind == 'tool-call') {
      final messageId = messageData['id'] as String?;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ToolView(
          tool: messageData,
          metadata: metadata,
          messages: messages,
          sessionId: sessionId,
          onPress: (sessionId != null && messageId != null)
              ? () => context.push(
                    '/chat/$sessionId/message/$messageId',
                    extra: messageData,
                  )
              : null,
        ),
      );
    }

    // User messages: right-aligned with bubble
    if (isFromCurrentUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          decoration: BoxDecoration(
            color: theme.primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectionArea(
            child: MarkdownView(
              markdown: text,
              onOptionPress: onOptionPress,
            ),
          ),
        ),
      );
    }

    // Agent messages: left-aligned, no bubble
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SelectionArea(
        child: MarkdownView(
          markdown: text,
          onOptionPress: onOptionPress,
        ),
      ),
    );
  }
}

class _AgentEventWidget extends StatelessWidget {
  final dynamic event;

  const _AgentEventWidget({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _eventLabel(event);
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  String? _eventLabel(dynamic event) {
    if (event is! Map<String, dynamic>) return null;
    final type = event['type'] as String?;
    switch (type) {
      case 'switch':
        final mode = event['mode'] as String?;
        return mode != null ? 'Switched to $mode mode' : 'Mode switched';
      case 'message':
        return event['message'] as String?;
      case 'limit-reached':
        return 'Usage limit reached';
      default:
        return null;
    }
  }
}

/// Markdown rendered message widget.
///
/// A simpler widget for rendering just markdown content without
/// the chat message container styling.
class MarkdownMessage extends StatelessWidget {
  final String content;

  const MarkdownMessage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return SimpleMarkdownView(markdown: content);
  }
}
