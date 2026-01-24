/// Parses error messages that contain `<tool_use_error>` tags.
///
/// Example:
/// Input: "<tool_use_error>File has not been read yet. Read it first before writing to it.</tool_use_error>"
/// Output: { isToolUseError: true, errorMessage: "File has not been read yet. Read it first before writing to it." }
class ToolErrorParser {
  /// Parses a tool use error from a message string.
  ///
  /// Returns a [ToolErrorParseResult] containing:
  /// - [isToolUseError]: Whether the message contains a `<tool_use_error>` tag
  /// - [errorMessage]: The extracted error message (without tags), or null if not found
  static ToolErrorParseResult parse(String? message) {
    if (message == null) {
      return const ToolErrorParseResult(
        isToolUseError: false,
        errorMessage: null,
      );
    }

    // Match <tool_use_error> tags with content inside
    // The 's' flag allows . to match newlines
    final regex = RegExp(
      r'<tool_use_error>(.*?)<\/tool_use_error>',
      dotAll: true,
    );
    final match = regex.firstMatch(message);

    if (match != null) {
      return ToolErrorParseResult(
        isToolUseError: true,
        errorMessage: match.group(1)?.trim() ?? '',
      );
    }

    return const ToolErrorParseResult(
      isToolUseError: false,
      errorMessage: null,
    );
  }

  /// Checks if the message is a cancellation error.
  ///
  /// Handles various cancellation error formats:
  /// - <tool_use_error>...</tool_use_error>
  /// - Error: [Request interrupted by user for tool use]
  /// - Request interrupted
  /// - User cancelled
  /// - Operation cancelled
  static bool isCancelError(String message) {
    // Check for tool_use_error tags
    if (RegExp(
      r'<tool_use_error>.*<\/tool_use_error>',
      dotAll: true,
    ).hasMatch(message)) {
      return true;
    }

    // Check for common cancellation patterns
    return [
      RegExp(
        r'\[Request interrupted by user for tool use\]',
        caseSensitive: false,
      ),
      RegExp(r'Request interrupted', caseSensitive: false),
      RegExp(r'User cancelled', caseSensitive: false),
      RegExp(r'Operation cancelled', caseSensitive: false),
      RegExp(r'Cancelled by user', caseSensitive: false),
      RegExp(r'User aborted', caseSensitive: false),
      RegExp(r'Operation aborted', caseSensitive: false),
      RegExp(r'Interrupted by user', caseSensitive: false),
      RegExp(
        r"The user doesn't want to proceed with this tool use\. The tool use was rejected",
        caseSensitive: false,
      ),
    ].any((pattern) => pattern.hasMatch(message));
  }

  /// Extracts all tool use errors from a message that might contain multiple.
  static List<String> parseAll(String message) {
    final regex = RegExp(
      r'<tool_use_error>(.*?)<\/tool_use_error>',
      dotAll: true,
    );
    final matches = regex.allMatches(message);

    return matches.map((match) => match.group(1)?.trim() ?? '').toList();
  }

  /// Checks if a message contains any tool use error.
  static bool hasToolUseError(String message) {
    return parse(message).isToolUseError;
  }
}

/// Result of parsing a tool use error.
class ToolErrorParseResult {
  /// Whether the message contains a `<tool_use_error>` tag.
  final bool isToolUseError;

  /// The extracted error message (without tags), or null if not found.
  final String? errorMessage;

  const ToolErrorParseResult({
    required this.isToolUseError,
    required this.errorMessage,
  });

  /// Returns the display message - either the extracted error or the original.
  String get displayMessage {
    if (isToolUseError && errorMessage != null) {
      return errorMessage!;
    }
    return '';
  }
}
