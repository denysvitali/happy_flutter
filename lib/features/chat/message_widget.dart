import 'package:flutter/material.dart';
import '../../core/models/message.dart';

/// Widget to render different message types
class MessageWidget extends StatelessWidget {
  final Message message;
  final bool isFromCurrentUser;

  const MessageWidget({
    super.key,
    required this.message,
    this.isFromCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        child: switch (message) {
          UserText(:final message) => _UserMessageContent(message: message),
          AgentText(:final message) => _AgentMessageContent(message: message),
          ToolCall(:final message) => _ToolCallContent(message: message),
          AgentEvent(:final message) => _AgentEventContent(event: message.event),
        },
      ),
    );
  }
}

class _UserMessageContent extends StatelessWidget {
  final UserTextMessage message;

  const _UserMessageContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message.text,
      style: const TextStyle(color: Colors.white),
    );
  }
}

class _AgentMessageContent extends StatelessWidget {
  final AgentTextMessage message;

  const _AgentMessageContent({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.isThinking == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Thinking...', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        SelectableText(message.text),
      ],
    );
  }
}

class _ToolCallContent extends StatelessWidget {
  final ToolCallMessage message;

  const _ToolCallContent({required this.message});

  @override
  Widget build(BuildContext context) {
    final tool = message.tool;

    return ExpansionTile(
      title: Text('${tool.name} (${tool.state})'),
      subtitle: tool.description != null ? Text(tool.description!) : null,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tool.input != null)
                _buildJsonView(tool.input),
            ],
          ),
        ),
        if (tool.result != null) ...[
          const SizedBox(height: 8),
          const Text('Result:', style: TextStyle(fontWeight: FontWeight.bold)),
          _buildJsonView(tool.result),
        ],
      ],
    );
  }

  Widget _buildJsonView(dynamic data) {
    final text = data is String ? data : data.toString();
    return SelectableText(
      text,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    );
  }
}

class _AgentEventContent extends StatelessWidget {
  final AgentEvent event;

  const _AgentEventContent({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = Colors.blue[100];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (event) {
              SwitchEvent() => Icons.swap_horiz,
              MessageEvent() => Icons.message,
              LimitReached() => Icons.warning,
              ReadyEvent() => Icons.check_circle,
            },
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(_eventDescription(event)),
        ],
      ),
    );
  }

  String _eventDescription(AgentEvent event) {
    return switch (event) {
      SwitchEvent(:final mode) => 'Switched to $mode',
      MessageEvent(:final message) => message,
      LimitReached(:final endsAt) =>
        'Limit reached. Resumes at ${DateTime.fromMillisecondsSinceEpoch(endsAt)}',
      ReadyEvent() => 'Ready',
    };
  }
}

/// Markdown rendered message
class MarkdownMessage extends StatelessWidget {
  final String content;

  const MarkdownMessage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      _parseMarkdown(content),
      style: const TextStyle(height: 1.5),
    );
  }

  TextSpan _parseMarkdown(String content) {
    // Simple markdown parsing - in production use flutter_markdown
    return TextSpan(text: content);
  }
}
