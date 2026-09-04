import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';
import 'known_tools.dart';
import 'tool_status_indicator.dart' show ToolState;

/// Parses a tool state string into [ToolState].
///
/// Null or unknown values map to [ToolState.pending]. `'canceled'` (stamped
/// by Sync when a turn ends leaving a running row without a result) lands
/// there deliberately: the row must render statically — no pulse, no elapsed
/// tick — because no process will ever finish it.
ToolState parseToolState(String? state) {
  switch (state) {
    case 'running':
      return ToolState.running;
    case 'completed':
      return ToolState.completed;
    case 'error':
      return ToolState.error;
    default:
      return ToolState.pending;
  }
}

/// Whether a permission map represents a pending (unresolved) request.
bool isPermissionPending(Map<String, dynamic>? permission) {
  if (permission == null) return false;
  final status = permission['status'];
  return status != 'approved' && status != 'denied' && status != 'canceled';
}

/// Whether a permission was not denied or canceled (still relevant to show).
bool isPermissionNotDeniedOrCanceled(Map<String, dynamic>? permission) {
  if (permission == null) return false;
  final status = permission['status'];
  return status != 'denied' && status != 'canceled';
}

/// Returns the accent/background color for a given tool state.
Color stateColor(ToolState state, ColorScheme cs) {
  switch (state) {
    case ToolState.running:
      return cs.primary;
    case ToolState.completed:
      return AppColors.success;
    case ToolState.error:
      return cs.error;
    case ToolState.pending:
      return cs.onSurfaceVariant;
  }
}

/// Returns the visual accent for a tool family.
///
/// Tool state is rendered separately by [stateColor]. Keeping the family
/// accent independent means a completed terminal call can still be told apart
/// from a completed file edit at a glance.
Color toolAccentColor(String toolName, ColorScheme cs) {
  final normalized = toolName.toLowerCase();
  final canonical = KnownTools.canonicalName(toolName).toLowerCase();

  if (normalized.startsWith('mcp__') ||
      normalized.startsWith('github.') ||
      normalized.startsWith('slack.') ||
      normalized.startsWith('linear.') ||
      normalized.startsWith('notion.') ||
      normalized.contains('__')) {
    return cs.tertiary;
  }

  if ({'bash', 'exec_command', 'functions.exec_command'}.contains(canonical)) {
    return cs.primary;
  }

  if ({
    'glob',
    'grep',
    'ls',
    'read',
    'toolsearch',
    'webfetch',
    'websearch',
    'web_search',
    'web_search_preview',
  }.contains(canonical)) {
    return cs.secondary;
  }

  if ({
    'edit',
    'file-edit',
    'multiedit',
    'write',
    'codexpatch',
    'codexdiff',
  }.contains(canonical)) {
    return cs.tertiary;
  }

  if ({'task', 'agent', 'workflow', 'todowrite'}.contains(canonical)) {
    return cs.primary;
  }

  // Unknown tools still get a deliberate accent instead of falling back to
  // the same muted icon treatment as every other tool.
  return cs.secondary;
}

/// Returns label text for the status badge.
String statusBadgeLabel(ToolState state) {
  switch (state) {
    case ToolState.running:
      return 'Running';
    case ToolState.completed:
      return 'Done';
    case ToolState.error:
      return 'Error';
    case ToolState.pending:
      return 'Pending';
  }
}

/// Accent color for permission-required state (orange).
const Color permissionColor = AppColors.warning;

/// Canonical casing for well-known tool namespaces and brands, so
/// `github.fetch_workflow_run_jobs` renders as `GitHub: …` not `Github: …`.
const Map<String, String> _brandCasings = {
  'github': 'GitHub',
  'gitlab': 'GitLab',
  'slack': 'Slack',
  'linear': 'Linear',
  'notion': 'Notion',
  'jira': 'Jira',
  'figma': 'Figma',
  'sentry': 'Sentry',
  'postgres': 'Postgres',
  'mysql': 'MySQL',
  'sqlite': 'SQLite',
  'filesystem': 'Filesystem',
  'playwright': 'Playwright',
  'chrome': 'Chrome',
  'happy': 'Happy',
  'codex': 'Codex',
  'agy': 'AGY',
  'gemini': 'AGY',
};

/// Humanizes an unknown tool name for display.
///
/// Agents and MCP-adjacent providers emit raw identifiers such as
/// `github.fetch_workflow_run_jobs` or `run_diagnostics`; showing the wire
/// name verbatim reads as noise. Dotted names are treated as
/// `namespace.tool_name` and rendered `Namespace: Tool Name`; plain
/// snake_case / kebab-case names are title-cased. Names without separators
/// (already display-ready, e.g. `Terminal`) pass through unchanged.
String humanizeToolName(String name) {
  final dot = name.indexOf('.');
  if (dot > 0 && dot < name.length - 1) {
    final namespace = name.substring(0, dot);
    final rest = name.substring(dot + 1);
    return '${_brandCasing(namespace)}: ${_titleCaseWords(rest)}';
  }
  if (name.contains('_') || name.contains('-')) {
    return _titleCaseWords(name);
  }
  return name;
}

String _brandCasing(String token) {
  return _brandCasings[token.toLowerCase()] ?? _titleCaseWords(token);
}

String _titleCaseWords(String input) {
  return input
      .split(RegExp(r'[_\-\s]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

/// Extracts plain text from an MCP tool result.
///
/// MCP results carry `content` blocks (`[{type: 'text', text: ...}]`), either
/// at the top level or nested under a `result` key; some servers answer with
/// a bare string instead. Returns the joined block texts when every block is
/// a text block (or the string itself), or null otherwise.
String? mcpToolTextResult(dynamic result) {
  if (result is String) return result.isEmpty ? null : result;

  final direct = _mcpTextFromContentBlocks(result);
  if (direct != null) return direct;

  final map = WireParsers.asMap(result);
  if (map == null) return null;

  final content = _mcpTextFromContentBlocks(map['content']);
  if (content != null) return content;

  final nestedResult = WireParsers.asMap(map['result']);
  return _mcpTextFromContentBlocks(nestedResult?['content']);
}

String? _mcpTextFromContentBlocks(dynamic value) {
  final blocks = WireParsers.asList(value);
  if (blocks == null || blocks.isEmpty) return null;

  final texts = <String>[];
  for (final block in blocks) {
    final map = WireParsers.asMap(block);
    if (map == null || map['type'] != 'text') return null;
    final text = map['text'];
    if (text is! String) return null;
    texts.add(text);
  }

  if (texts.isEmpty) return null;
  return texts.join('\n');
}

/// Decodes [raw] when it is a JSON object or array, otherwise returns null.
///
/// Scalars (`"42"`, `"true"`, a bare quoted string) decode successfully as
/// JSON but pretty-printing them changes nothing, so they are treated as plain
/// text. Bounded by a cheap first-character check so ordinary log output never
/// pays for a failed parse.
Object? tryDecodeJsonCollection(String raw) {
  final trimmed = raw.trim();
  if (trimmed.length < 2) return null;
  final first = trimmed[0];
  if (first != '{' && first != '[') return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map || decoded is List) return decoded;
  } on FormatException {
    return null;
  }
  return null;
}

/// One-glance summary of an MCP text result, for the collapsed tool header.
///
/// A collapsed MCP row otherwise says nothing about what came back. Prefers
/// the shape of the payload (`4 items`, `29 operations`, `3 fields`) and falls
/// back to a line count for non-JSON text. Returns null for empty results.
String? mcpResultSummary(String text) {
  final decoded = tryDecodeJsonCollection(text);
  if (decoded is List) return _pluralize(decoded.length, 'item');
  if (decoded is Map) {
    // Envelope shapes such as `{limit, offset, total, traces: [...]}` are far
    // better summarized by their payload list than by a field count.
    for (final entry in decoded.entries) {
      final value = entry.value;
      final key = entry.key.toString();
      if (value is List && key.endsWith('s')) return '${value.length} $key';
    }
    return _pluralize(decoded.length, 'field');
  }

  final trimmed = text.trimRight();
  if (trimmed.isEmpty) return null;
  final lines = trimmed.split('\n').length;
  if (lines == 1) return null;
  return _pluralize(lines, 'line');
}

String _pluralize(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';

/// Permission action kinds emitted from [ToolView].
enum PermissionActionKind {
  allow,
  deny,
  allowAllEdits,
  allowForSession,
  yolo,
  codexApprove,
  codexApproveForSession,
  codexAbort,
}

/// Structured permission action payload for tool permission interactions.
class PermissionAction {
  const PermissionAction({
    required this.kind,
    required this.sessionId,
    required this.permissionId,
    required this.toolName,
    this.toolInput,
  });

  final PermissionActionKind kind;
  final String sessionId;
  final String permissionId;
  final String toolName;
  final Map<String, dynamic>? toolInput;
}

/// Optional delegate for handling permission actions.
typedef PermissionActionDelegate =
    Future<void> Function(PermissionAction action);
