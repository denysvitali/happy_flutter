/// Utility for parsing and handling tool error formats
///
/// Parses error messages containing `<tool_use_error>` tags and extracts
/// structured error information for better error display and debugging.
class ToolErrorParser {
  /// Parse a raw error string and extract structured information
  ///
  /// Returns a [ParsedToolError] if the error contains tool error tags,
  /// or null if no parsing is needed.
  static ParsedToolError? parse(String errorMessage) {
    // Check if this is a tool use error
    final toolErrorMatch = _toolUseErrorRegex.firstMatch(errorMessage);
    if (toolErrorMatch == null) {
      return null;
    }

    final errorType = toolErrorMatch.group(1)?.trim() ?? 'Unknown';
    final errorContent = toolErrorMatch.group(2)?.trim() ?? '';

    // Extract error name and message
    final nameMatch = _errorNameRegex.firstMatch(errorContent);
    final name = nameMatch?.group(1)?.trim() ?? errorType;
    final message =
        nameMatch?.group(2)?.trim() ?? errorContent.split('\n').first;

    // Extract suggestion if present
    String? suggestion;
    final suggestionMatch = _suggestionRegex.firstMatch(errorContent);
    if (suggestionMatch != null) {
      suggestion = suggestionMatch.group(1)?.trim();
    }

    // Extract context if present
    String? context;
    final contextMatch = _contextRegex.firstMatch(errorContent);
    if (contextMatch != null) {
      context = contextMatch.group(1)?.trim();
    }

    return ParsedToolError(
      rawMessage: errorMessage,
      errorType: errorType,
      errorName: name,
      message: message,
      suggestion: suggestion,
      context: context,
    );
  }

  /// Check if an error message contains tool error tags
  static bool isToolError(String errorMessage) {
    return _toolUseErrorRegex.hasMatch(errorMessage);
  }

  /// Format a parsed error for display
  static String formatForDisplay(ParsedToolError error) {
    final buffer = StringBuffer();
    buffer.writeln('Error: ${error.errorName}');
    buffer.writeln(error.message);
    if (error.context != null) {
      buffer.writeln('\nContext: ${error.context}');
    }
    if (error.suggestion != null) {
      buffer.writeln('\nSuggestion: ${error.suggestion}');
    }
    return buffer.toString();
  }

  /// Extract all error messages from a string (handles multiple errors)
  static List<ParsedToolError> extractAll(String errorMessage) {
    final errors = <ParsedToolError>[];
    final matches = _toolUseErrorRegex.allMatches(errorMessage);
    for (final match in matches) {
      final parsed = parse(errorMessage);
      if (parsed != null) {
        errors.add(parsed);
      }
    }
    return errors;
  }

  // Regex patterns for parsing
  static final _toolUseErrorRegExp = '''<tool_use_error>
(?:<error_type>(.*?)</error_type>)?
(?:<body>(.*?)</body>)?
</tool_use_error>''';
  static final _toolUseErrorRegex = RegExp(_toolUseErrorRegExp, dotAll: true);

  static final _errorNameRegExp = r'^(?:<error_name>(.*?)</error_name>\s*)?(.*)';
  static final _errorNameRegex = RegExp(_errorNameRegExp, dotAll: true);

  static final _suggestionRegExp =
      r'<suggestion>(.*?)</suggestion>';
  static final _suggestionRegex = RegExp(_suggestionRegExp, dotAll: true);

  static final _contextRegExp = r'<context>(.*?)</context>';
  static final _contextRegex = RegExp(_contextRegExp, dotAll: true);
}

/// Parsed tool error information
class ParsedToolError {
  /// The original raw error message
  final String rawMessage;

  /// The type of tool error (from error_type tag)
  final String errorType;

  /// The error name (from error_name tag)
  final String errorName;

  /// The human-readable error message
  final String message;

  /// Optional suggestion for fixing the error
  final String? suggestion;

  /// Optional context information
  final String? context;

  ParsedToolError({
    required this.rawMessage,
    required this.errorType,
    required this.errorName,
    required this.message,
    this.suggestion,
    this.context,
  });

  @override
  String toString() {
    return 'ParsedToolError(errorType: $errorType, errorName: $errorName, '
        'message: $message, suggestion: $suggestion, context: $context)';
  }

  /// Convert to a user-friendly display string
  String toDisplayString() {
    return ToolErrorParser.formatForDisplay(this);
  }

  /// Create a copy with optional field updates
  ParsedToolError copyWith({
    String? rawMessage,
    String? errorType,
    String? errorName,
    String? message,
    String? suggestion,
    String? context,
  }) {
    return ParsedToolError(
      rawMessage: rawMessage ?? this.rawMessage,
      errorType: errorType ?? this.errorType,
      errorName: errorName ?? this.errorName,
      message: message ?? this.message,
      suggestion: suggestion ?? this.suggestion,
      context: context ?? this.context,
    );
  }
}

/// Common tool error types for categorization
class ToolErrorTypes {
  static const String invalidInput = 'invalid_input';
  static const String fileNotFound = 'file_not_found';
  static const String permissionDenied = 'permission_denied';
  static const String timeout = 'timeout';
  static const String rateLimit = 'rate_limit';
  static const String validation = 'validation';
  static const String parsing = 'parsing';
  static const String execution = 'execution';
  static const String network = 'network';
  static const String unknown = 'unknown';
}

/// Extension on String to easily parse tool errors
extension ToolErrorStringExtension on String {
  /// Parse this string as a tool error if applicable
  ParsedToolError? get asToolError => ToolErrorParser.parse(this);

  /// Check if this string is a tool error
  bool get isToolError => ToolErrorParser.isToolError(this);
}
