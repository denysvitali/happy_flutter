/// Centralized parsing of tool-result fields that vary across providers.
///
/// Different agents (Claude, Codex, Gemini, Pi, etc.) return tool results
/// with different field names for stdout, stderr, and exit code. This
/// utility provides canonical parsers so tool views do not duplicate the
/// same fallback chains.
///
/// All methods accept a `dynamic` result (the tool's `result` field) and
/// return `null` when the expected fields are absent or malformed.
library;

import 'wire_parsers.dart';

// ---------------------------------------------------------------------------
// Exit code
// ---------------------------------------------------------------------------

/// Parses an exit code from a tool result.
///
/// Tries `exitCode`, `exit_code`, and `exitCode` nested inside a map.
/// Handles both `int` and `String` values (parsing the latter with
/// [int.tryParse]).
int? parseExitCode(dynamic result) {
  if (result is Map<String, dynamic>) {
    final raw = result['exitCode'] ?? result['exit_code'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Stdout
// ---------------------------------------------------------------------------

/// Parses stdout text from a tool result.
///
/// Tries `stdout` and `output` in order. If the result is a plain string,
/// returns it directly (some tools return stdout as the entire result).
String? parseStdout(dynamic result) {
  if (result is String) return result;
  if (result is Map<String, dynamic>) {
    final direct = result['stdout'] as String? ??
        result['output'] as String? ??
        result['output_for_prompt'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;
    // Grok ListDir / nested Content maps occasionally land here before
    // normalizeGrokToolResult runs.
    final content = result['Content'] ?? result['content'];
    if (content is Map && content['content'] is String) {
      return content['content'] as String;
    }
    if (content is String && content.isNotEmpty) return content;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Stderr
// ---------------------------------------------------------------------------

/// Parses stderr text from a tool result.
///
/// Tries `stderr` inside a map. Returns `null` for plain strings since
/// stderr is only meaningful in structured results.
String? parseStderr(dynamic result) {
  if (result is Map<String, dynamic>) {
    return result['stderr'] as String?;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Error text (any error-ish field)
// ---------------------------------------------------------------------------

/// Parses an error text from a tool result, trying multiple fallback fields.
///
/// Tries `stderr`, `stdout`, `output`, `error`, and `summary` in order.
/// Falls back to `result.toString()` for non-map, non-string results.
String? parseErrorText(dynamic result) {
  if (result is String) return result;
  if (result is Map<String, dynamic>) {
    return (result['stderr'] ??
            result['stdout'] ??
            result['output'] ??
            result['error'] ??
            result['summary'])
        as String?;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Structured result check
// ---------------------------------------------------------------------------

/// Whether the result looks like a structured map with terminal fields.
///
/// Returns `true` if the result is a map containing at least one of the
/// known terminal keys: `stdout`, `stderr`, `exitCode`, `exit_code`,
/// `output`, `error`, or `summary`.
bool isStructuredResult(dynamic result) {
  if (result is! Map<String, dynamic>) return false;
  const keys = {
    'stdout',
    'stderr',
    'exitCode',
    'exit_code',
    'output',
    'error',
    'summary',
  };
  for (final key in keys) {
    if (result.containsKey(key)) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Batch / combined result helpers
// ---------------------------------------------------------------------------

/// Parses a list of file entries from a tool result.
///
/// Handles both list-shaped results and map-shaped results with an
/// `entries`, `files`, or `items` key.
List<Map<String, dynamic>> parseFileEntries(dynamic result) {
  if (result is List) {
    return result
        .map((e) => WireParsers.asMap(e))
        .whereType<Map<String, dynamic>>()
        .toList();
  }
  if (result is Map<String, dynamic>) {
    final source = WireParsers.asList(result['entries']) ??
        WireParsers.asList(result['files']) ??
        WireParsers.asList(result['items']);
    if (source != null) {
      return source
          .map((e) => WireParsers.asMap(e))
          .whereType<Map<String, dynamic>>()
          .toList();
    }
  }
  return const [];
}
