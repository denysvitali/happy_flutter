/// Message utility functions for processing and formatting chat messages.
///
/// Provides functions for stripping markdown, generating message previews,
/// and detecting assistant messages.

import 'utils.dart';

/// Strip markdown formatting from text.
///
/// [text] - The text with markdown formatting
///
/// Returns plain text without markdown syntax
String stripMarkdown(String text) {
  return text
      // Remove headers
      .replaceAll(RegExp(r'^#{1,6}\s+'), '')
      // Remove bold and italic
      .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), '\$1')
      .replaceAll(RegExp(r'\*([^*]+)\*'), '\$1')
      .replaceAll(RegExp(r'__([^_]+)__'), '\$1')
      .replaceAll(RegExp(r'_([^_]+)_'), '\$1')
      // Remove inline code
      .replaceAll(RegExp(r'`([^`]+)`'), '\$1')
      // Remove code blocks
      .replaceAll(RegExp(r'```[\s\S]*?```'), '[code]')
      // Remove links
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), '\$1')
      // Remove horizontal rules
      .replaceAll(RegExp(r'^---+$'), '')
      // Remove list markers
      .replaceAll(RegExp(r'^\s*[-*+]\s+'), '')
      .replaceAll(RegExp(r'^\s*\d+\.\s+'), '')
      // Clean up multiple whitespace
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Get a human-readable summary of tool calls.
///
/// [toolNames] - List of tool names used
///
/// Returns a summary string describing the tools used
String getToolSummary(List<String> toolNames) {
  if (toolNames.isEmpty) return 'Used tools';

  if (toolNames.length == 1) {
    final toolName = toolNames.first;

    // Try to extract meaningful info from common tools
    switch (toolName) {
      case 'Edit':
      case 'Write':
        return 'Edited file';
      case 'Read':
        return 'Read file';
      case 'Bash':
      case 'RunCommand':
        return 'Ran command';
      default:
        return 'Used $toolName';
    }
  }

  // Multiple tools
  final names = toolNames.take(3).toList();
  if (toolNames.length <= 3) {
    return 'Used ${names.join(', ')}';
  } else {
    return 'Used ${names.join(', ')} and ${toolNames.length - 3} more';
  }
}

/// Content types for messages.
enum MessageContentType {
  text,
  tool,
  image,
  audio,
  other,
}

/// Simple message content structure.
class MessageContent {
  final String type;
  final String? text;
  final List<String>? tools;

  MessageContent({required this.type, this.text, this.tools});

  factory MessageContent.fromJson(Map<String, dynamic> json) {
    return MessageContent(
      type: json['type'] as String,
      text: json['text'] as String?,
      tools: (json['tools'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

/// Simple message structure for preview.
class Message {
  final String role; // 'user' or 'agent'
  final MessageContent? content;

  Message({required this.role, this.content});

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      role: json['role'] as String,
      content: json['content'] != null
          ? MessageContent.fromJson(json['content'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Get a readable preview of a message.
///
/// [message] - The message to preview
/// [maxLength] - Maximum length of the preview (default: 50)
///
/// Returns a short preview string
String getMessagePreview(Message? message, [int maxLength = 50]) {
  if (message?.content == null) {
    return 'No content';
  }

  final content = message!.content;

  // User messages
  if (message.role == 'user') {
    if (content!.text != null) {
      final plainText = stripMarkdown(content.text!);
      return truncate(plainText, maxLength);
    }
    return 'User message';
  }

  // Agent messages
  if (message.role == 'agent') {
    // Check for text content
    if (content!.type == 'text' && content.text != null) {
      final plainText = stripMarkdown(content.text!);
      return truncate(plainText, maxLength);
    }

    // Check for tool content
    if (content.type == 'tool' && content.tools != null) {
      return getToolSummary(content.tools!);
    }

    return 'Thinking...';
  }

  return 'Unknown message';
}

/// Determines if a message is from the assistant/agent.
///
/// [message] - The message to check
///
/// Returns true if the message is from the assistant
bool isMessageFromAssistant(Message? message) {
  if (message?.content == null) return false;
  return message!.role == 'agent';
}

/// Clean a message text for display.
String cleanForDisplay(String text) {
  return text
      .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '')
      .trim();
}

/// Format message timestamp for display.
String formatMessageTimestamp(int timestamp, {bool relative = false}) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final now = DateTime.now();

  if (relative) {
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
  }

  return '${date.month}/${date.day}/${date.year}';
}
