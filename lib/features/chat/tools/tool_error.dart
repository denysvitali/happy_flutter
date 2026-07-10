import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import '../../../core/utils/tool_error_parser.dart';
import 'json_viewer.dart';

/// Error display for tool use errors.
class ToolError extends StatelessWidget {
  const ToolError({required this.message, super.key});

  /// The error message to display.
  final String message;

  /// Extracts the useful message from structured tool results.
  ///
  /// Codex returns some errors as `{ "message": "..." }`; displaying the
  /// map's Dart `toString()` makes that otherwise clear message harder to read.
  static String messageFromResult(dynamic result) {
    if (result is String) {
      final decoded = _decodeJsonObject(result);
      return decoded == null ? result : messageFromResult(decoded);
    }

    if (result is Map) {
      for (final key in const ['message', 'error', 'output']) {
        final value = result[key];
        if (value is String && value.trim().isNotEmpty) return value;
      }

      for (final key in const ['result', 'error']) {
        final value = result[key];
        if (value is Map) return messageFromResult(value);
      }
    }

    return result?.toString() ?? '';
  }

  static Map<Object?, Object?>? _decodeJsonObject(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = ToolErrorParser.parse(message);

    final errorColor = theme.colorScheme.error;
    final surfaceColor = theme.colorScheme.errorContainer.withValues(
      alpha: 0.4,
    );
    final textColor = theme.colorScheme.onErrorContainer;
    final displayText = parsed != null && parsed.displayMessage.isNotEmpty
        ? parsed.displayMessage
        : message;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(left: BorderSide(color: errorColor, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppRadius.xsm),
          bottomRight: Radius.circular(AppRadius.xsm),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 15, color: errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: ToolOutputScrollFrame(
              maxHeight: 260,
              child: SelectableText(
                displayText,
                scrollPhysics: const NeverScrollableScrollPhysics(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontSize: AppFontSize.sm,
                  height: 1.5,
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Courier New', 'Courier'],
                ),
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
    final parsed = ToolErrorParser.parse(message);
    final errorColor = theme.colorScheme.error;

    final displayText = parsed != null ? parsed.message : message;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.06),
        border: Border(left: BorderSide(color: errorColor, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppRadius.xs),
          bottomRight: Radius.circular(AppRadius.xs),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: ToolOutputScrollFrame(
              maxHeight: 220,
              child: SelectableText(
                displayText,
                scrollPhysics: const NeverScrollableScrollPhysics(),
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: errorColor,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
