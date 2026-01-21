import 'package:flutter/material.dart';
import '../../core/models/message.dart';

/// Simple message widget for displaying chat messages
class MessageWidget extends StatelessWidget {
  final Map<String, dynamic> messageData;
  final bool isFromCurrentUser;

  const MessageWidget({
    super.key,
    required this.messageData,
    this.isFromCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = messageData['kind'] as String? ?? 'unknown';
    final content = messageData['content'] ?? messageData['text'] ?? '';
    final text = content is String ? content : content.toString();

    return Align(
      alignment: isFromCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
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
              _buildToolCallContent(context, messageData)
            else
              SelectableText(
                text,
                style: const TextStyle(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCallContent(BuildContext context, Map<String, dynamic> data) {
    final toolName = data['tool']?['name'] ?? 'Unknown';
    final toolState = data['tool']?['state'] ?? 'pending';
    final toolInput = data['tool']?['input'];

    return ExpansionTile(
      title: Text('$toolName ($toolState)'),
      children: [
        if (toolInput != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              toolInput is String ? toolInput : toolInput.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// Markdown rendered message
class MarkdownMessage extends StatelessWidget {
  final String content;

  const MarkdownMessage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      content,
      style: const TextStyle(height: 1.5),
    );
  }
}
