import 'package:flutter/material.dart';

import '../../core/models/message.dart';
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
    final content = messageData['content'] ?? messageData['text'] ?? '';
    final text = content is String ? content : content.toString();

    return Align(
      alignment: isFromCurrentUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFromCurrentUser
              ? theme.primaryColor
              : theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind == 'tool-call')
              ToolView(
                tool: messageData,
                metadata: metadata,
                messages: messages,
                sessionId: sessionId,
              )
            else
              SelectionArea(
                child: MarkdownView(
                  markdown: text,
                  onOptionPress: onOptionPress,
                ),
              ),
          ],
        ),
      ),
    );
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
