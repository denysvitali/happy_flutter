import '../models/message.dart';
import '../wire/wire_parsers.dart';

/// Extracts plain text from markdown by removing formatting
String stripMarkdown(String text) {
  return text
      // Remove headers
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      // Remove bold and italic
      .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
      .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')
      .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
      .replaceAll(RegExp(r'_([^_]+)_'), r'$1')
      // Remove inline code
      .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
      // Remove code blocks
      .replaceAll(RegExp(r'```[\s\S]*?```'), '[code]')
      // Remove links
      .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
      // Remove horizontal rules
      .replaceAll(RegExp(r'^---+$', multiLine: true), '')
      // Remove list markers
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
      // Clean up multiple whitespace
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Gets a readable summary of tool calls
String getToolSummary(List<ToolCall> tools) {
  if (tools.isEmpty) return 'Used tools';

  if (tools.length == 1) {
    final tool = tools.first;
    final toolName = tool.name;

    // Try to extract meaningful info from common tools
    switch (toolName) {
      case 'Edit':
      case 'Write':
        final filePath = tool.input?['target_file'] ?? tool.input?['file_path'];
        return filePath != null ? 'Edited $filePath' : 'Used $toolName';

      case 'Read':
        final readPath = tool.input?['target_file'] ?? tool.input?['file_path'];
        return readPath != null ? 'Read $readPath' : 'Read file';

      case 'Bash':
      case 'RunCommand':
        final command = tool.input?['command'];
        if (command != null && command is String) {
          final displayCmd = command.length > 20
              ? '${command.substring(0, 20)}...'
              : command;
          return 'Ran: $displayCmd';
        }
        return 'Ran command';

      default:
        return 'Used $toolName';
    }
  }

  // Multiple tools
  final toolNames = tools.map((t) => t.name).take(3).toList();
  if (tools.length <= 3) {
    return 'Used ${toolNames.join(', ')}';
  } else {
    return 'Used ${toolNames.join(', ')} and ${tools.length - 3} more';
  }
}

/// Extracts text from Claude's complex message structure
String? extractClaudeTextContent(dynamic content) {
  // Handle the complex nested structure of agent messages
  if (content != null && content is Map<String, dynamic>) {
    // Format 1: Direct text content structure
    if (content['type'] == 'text' && content['data'] is String) {
      return content['data'] as String;
    }

    // Format 2: Simple text structure (alternative direct format)
    if (content['type'] == 'text' && content['text'] is String) {
      return content['text'] as String;
    }

    // Format 3: String content directly
    if (content is String) {
      return content as String;
    }

    // Format 4: Complex nested structure (output type)
    if (content['type'] == 'output' &&
        content['data'] is Map<String, dynamic>) {
      final data = content['data'] as Map<String, dynamic>;

      // Handle summary messages - should not reach here anymore
      // due to SessionsList filtering
      if (data['type'] == 'summary' && data['summary'] != null) {
        return 'Summary message (should be filtered)';
      }

      // Check if it's an assistant message
      if (data['type'] == 'assistant' &&
          data['message'] != null &&
          data['message']['content'] != null) {
        final messageContent = data['message']['content'];
        // Look for text content in the content array
        if (messageContent is List) {
          for (final item in messageContent) {
            if (item is Map<String, dynamic> &&
                item['type'] == 'text' &&
                item['text'] != null) {
              return item['text'] as String;
            }
          }
        }
      }

      // Handle other data types that might contain text
      if (data['type'] == 'user' &&
          data['message'] != null &&
          data['message']['content'] != null) {
        final messageContent = data['message']['content'];
        // User messages might also have text
        if (messageContent is String) {
          return messageContent;
        }
        if (messageContent is List) {
          for (final item in messageContent) {
            if (item is String) {
              return item;
            }
            if (item is Map<String, dynamic> &&
                item['type'] == 'text' &&
                item['text'] != null) {
              return item['text'] as String;
            }
          }
        }
      }
    }

    // Format 5: Alternative structure patterns - try common text fields
    const possibleTextFields = ['text', 'content', 'message', 'body'];
    for (final field in possibleTextFields) {
      if (content[field] != null && content[field] is String) {
        return content[field] as String;
      }
    }

    // Format 6: Nested content field
    if (content['content'] != null && content['content'] is String) {
      return content['content'] as String;
    }

    // Format 7: Check if data field contains string directly
    if (content['data'] != null && content['data'] is String) {
      return content['data'] as String;
    }
  }

  return null;
}

/// Extracts tool calls from Claude's message structure
List<Map<String, dynamic>> extractClaudeToolCalls(dynamic content) {
  if (content != null && content is Map<String, dynamic>) {
    // Check if it's the outer agent content structure
    if (content['type'] == 'output' &&
        content['data'] is Map<String, dynamic>) {
      final data = content['data'] as Map<String, dynamic>;

      // Check if it's an assistant message with tool use
      if (data['type'] == 'assistant' &&
          data['message'] != null &&
          data['message']['content'] != null) {
        final tools = <Map<String, dynamic>>[];
        final messageContent = data['message']['content'];
        if (messageContent is List) {
          for (final item in messageContent) {
            if (item is Map<String, dynamic> && item['type'] == 'tool_use') {
              tools.add({
                'name': item['name'],
                'arguments': item['input'] ?? <String, dynamic>{},
                'state': 'completed', // Assume completed for preview
              });
            }
          }
        }
        return tools;
      }
    }
  }

  return [];
}

/// Message content wrapper for different message formats
class MessageContentWrapper {
  MessageContentWrapper({required this.role, required this.content});

  final String role;
  final dynamic content;

  static MessageContentWrapper fromMessage(ApiMessage message) {
    return MessageContentWrapper(
      role: message.content.t,
      content: message.content.c,
    );
  }
}

/// Extracts a readable preview from message content
String getMessagePreview(ApiMessage? message, {int maxLength = 50}) {
  if (message == null || message.content.c.isEmpty) {
    return 'No content';
  }

  final contentWrapper = MessageContentWrapper.fromMessage(message);
  final content = contentWrapper.content;

  // User messages
  if (contentWrapper.role == 'user') {
    final isTextContent =
        content != null &&
        content is Map<String, dynamic> &&
        content['type'] == 'text';
    if (isTextContent) {
      final text = content['text'] as String?;
      if (text != null) {
        final plainText = stripMarkdown(text);
        return plainText.length > maxLength
            ? '${plainText.substring(0, maxLength)}...'
            : plainText;
      }
    }
    return 'User message';
  }

  // Agent messages - handle BOTH raw and processed formats
  if (contentWrapper.role == 'agent') {
    // FIRST: Check if this is the processed Message format (simple structure)
    // This handles: {role: 'agent', content: {type: 'text', text: '...'}}
    if (content != null && content is Map<String, dynamic>) {
      if (content['type'] == 'text' && content['text'] != null) {
        final text = content['text'] as String;
        final plainText = stripMarkdown(text);
        return plainText.length > maxLength
            ? '${plainText.substring(0, maxLength)}...'
            : plainText;
      }

      if (content['type'] == 'tool' && content['tools'] != null) {
        final toolsData = content['tools'];
        if (toolsData is List) {
          final tools = toolsData
              .whereType<Map<String, dynamic>>()
              .map((t) => ToolCall.fromJson(t))
              .toList();
          return getToolSummary(tools);
        }
      }

      // SECOND: Try the complex format (nested structure)
      final textContent = extractClaudeTextContent(content);
      if (textContent != null) {
        final plainText = stripMarkdown(textContent);
        return plainText.length > maxLength
            ? '${plainText.substring(0, maxLength)}...'
            : plainText;
      }

      // THIRD: Check for tool calls in complex format
      final toolCalls = extractClaudeToolCalls(content);
      if (toolCalls.isNotEmpty) {
        final tools = toolCalls
            .map(
              (t) => ToolCall(
                name: t['name'] as String,
                state: t['state'] as String? ?? 'completed',
                createdAt: 0,
                input: WireParsers.asMap(t['arguments']),
              ),
            )
            .toList();
        return getToolSummary(tools);
      }
    }

    // Fallback for agent messages
    return 'Thinking...';
  }

  return 'Unknown message';
}

/// Determines if a message is from the assistant/agent
bool isMessageFromAssistant(ApiMessage? message) {
  if (message == null || message.content.c.isEmpty) return false;
  final contentWrapper = MessageContentWrapper.fromMessage(message);
  return contentWrapper.role == 'agent';
}
