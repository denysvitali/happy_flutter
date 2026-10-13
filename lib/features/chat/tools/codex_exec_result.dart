import 'dart:convert';

/// Exact Codex execution tool names; other MCP executors are unrelated.
const Set<String> codexExecToolNames = {'mcp__codex__codex_exec', 'codex_exec'};

bool isCodexExecTool(String name) => codexExecToolNames.contains(name);

/// Read-only display projection of a Codex execution result.
class CodexExecResult {
  const CodexExecResult({
    this.finalMessage,
    this.exitCode,
    this.elapsedMs,
    this.threadId,
    this.rawEventCount,
    this.inputTokens,
    this.cachedInputTokens,
    this.outputTokens,
  });

  final String? finalMessage;
  final int? exitCode;
  final int? elapsedMs;
  final String? threadId;
  final int? rawEventCount;
  final int? inputTokens;
  final int? cachedInputTokens;
  final int? outputTokens;

  bool get hasAnswer => finalMessage?.trim().isNotEmpty ?? false;

  /// Supports direct records, JSON, and common MCP result envelopes.
  /// Unknown/malformed payloads remain available through raw Tool Details.
  static CodexExecResult? tryParse(dynamic result) =>
      _CodexExecParser().find(result);
}

class _CodexExecParser {
  // Bound both nesting and breadth, including cyclic in-memory envelopes.
  static const _maxDepth = 8;
  static const _maxNodes = 128;
  int _remainingNodes = _maxNodes;

  CodexExecResult? find(dynamic value, [int depth = 0]) {
    if (depth > _maxDepth || _remainingNodes-- <= 0) return null;
    if (value is String) {
      final text = value.trim();
      if (!text.startsWith('{') && !text.startsWith('[')) return null;
      try {
        return find(jsonDecode(text), depth + 1);
      } on FormatException {
        return null;
      }
    }
    if (value is List) {
      for (final item in value) {
        if (_remainingNodes <= 0) break;
        final found = find(item, depth + 1);
        if (found != null) return found;
      }
      return null;
    }
    if (value is! Map) return null;
    final record = _parseRecord(value);
    if (record != null) return record;
    // Prefer structured data over its potentially abbreviated text copy.
    for (final key in const [
      'structuredContent',
      'result',
      'output',
      'content',
      'text',
    ]) {
      if (!value.containsKey(key)) continue;
      // Image/resource content cannot masquerade as a text block.
      if (key == 'text' &&
          value.containsKey('type') &&
          value['type'] != 'text') {
        continue;
      }
      final found = find(value[key], depth + 1);
      if (found != null) return found;
    }
    return null;
  }

  static CodexExecResult? _parseRecord(Map<dynamic, dynamic> map) {
    final answer = map['final_message'];
    final thread = map['thread_id'];
    final exitCode = _integer(map['exit_code']);
    final elapsedMs = _nonnegativeInteger(map['elapsed_ms']);
    final rawEventCount = _nonnegativeInteger(map['raw_event_count']);
    final usage = map['usage'];
    final tokens = usage is Map ? usage : const <String, dynamic>{};
    final inputTokens = _nonnegativeInteger(tokens['input_tokens']);
    final cachedInputTokens = _nonnegativeInteger(
      tokens['cached_input_tokens'],
    );
    final outputTokens = _nonnegativeInteger(tokens['output_tokens']);
    final hasExecutionMetadata =
        exitCode != null ||
        elapsedMs != null ||
        rawEventCount != null ||
        inputTokens != null ||
        cachedInputTokens != null ||
        outputTokens != null;
    if (answer is! String &&
        !(thread is String &&
            thread.trim().isNotEmpty &&
            hasExecutionMetadata)) {
      return null;
    }
    if (answer != null && answer is! String) {
      return null;
    }
    // Optional malformed metadata must never suppress a valid final answer.
    return CodexExecResult(
      finalMessage: answer is String ? answer : null,
      threadId: thread is String ? thread : null,
      exitCode: exitCode,
      elapsedMs: elapsedMs,
      rawEventCount: rawEventCount,
      inputTokens: inputTokens,
      cachedInputTokens: cachedInputTokens,
      outputTokens: outputTokens,
    );
  }

  static int? _integer(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    if (value is double && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return null;
  }

  static int? _nonnegativeInteger(dynamic value) {
    final number = _integer(value);
    return number != null && number >= 0 ? number : null;
  }
}
