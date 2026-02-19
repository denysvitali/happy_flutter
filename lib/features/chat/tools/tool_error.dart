import 'package:flutter/material.dart';
import '../utils/tool_error_parser.dart';

/// Error display for tool use errors.
class ToolError extends StatelessWidget {

  const ToolError({required this.message, super.key});
  /// The error message to display.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = ToolErrorParser.parse(message);
    final displayMessage = result.displayMessage;

    final errorColor = theme.colorScheme.error;
    final surfaceColor = theme.colorScheme.errorContainer
        .withValues(alpha: 0.4);
    final textColor = theme.colorScheme.onErrorContainer;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          left: BorderSide(color: errorColor, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 15, color: errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayMessage.isNotEmpty ? displayMessage : message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontSize: 12.5,
                height: 1.5,
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Courier New', 'Courier'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact error display for tool results.
class ToolResultError extends StatelessWidget {

  const ToolResultError({required this.message, super.key});
  /// The error message.
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = ToolErrorParser.parse(message);
    final isToolUseError = result.isToolUseError;
    final errorColor = theme.colorScheme.error;

    final displayText =
        isToolUseError && result.errorMessage != null
            ? result.errorMessage!
            : message;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.06),
        border: Border(
          left: BorderSide(color: errorColor, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 12.5,
                color: errorColor,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
