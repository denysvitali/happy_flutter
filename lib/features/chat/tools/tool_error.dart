import 'package:flutter/material.dart';
import '../utils/tool_error_parser.dart';

/// Error display for tool use errors.
class ToolError extends StatelessWidget {
  /// The error message to display.
  final String message;

  const ToolError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = ToolErrorParser.parse(message);
    final displayMessage = result.displayMessage;
    final isToolUseError = result.isToolUseError;

    final backgroundColor = theme.colorScheme.errorContainer;
    final borderColor = theme.colorScheme.error;
    final textColor = theme.colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isToolUseError)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Icon(Icons.warning, size: 16, color: textColor),
            ),
          Expanded(
            child: Text(
              displayMessage.isNotEmpty ? displayMessage : message,
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact error display for tool results.
class ToolResultError extends StatelessWidget {
  /// The error message.
  final String message;

  const ToolResultError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = ToolErrorParser.parse(message);
    final isToolUseError = result.isToolUseError;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isToolUseError && result.errorMessage != null
                  ? result.errorMessage!
                  : message,
              style: TextStyle(fontSize: 13, color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
