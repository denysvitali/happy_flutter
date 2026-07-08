/// Pure-Dart normalizers for Grok Build ACP tool payloads.
///
/// happy-cli-go materialises Grok ACP sessionUpdates as `content.type=grok`
/// envelopes with DataType tool-call / tool-result bodies. Field names and
/// result shapes differ from Claude Code; these helpers rewrite them into
/// the shapes Flutter tool views already understand (Read/Bash/LS/Edit).
///
/// Must stay free of Flutter imports — [message_processor] runs in isolates.
library;

import 'wire_parsers.dart';

/// Maps Grok Build built-in tool names onto Happy/Claude display names.
///
/// Keep in sync with [KnownTools.aliases] for the UI layer.
const Map<String, String> grokToolNameAliases = {
  'list_dir': 'LS',
  'read_file': 'Read',
  'run_terminal_command': 'Bash',
  'run_terminal_cmd': 'Bash',
  'search_replace': 'Edit',
  'write': 'Write',
  'grep': 'Grep',
  'todo_write': 'TodoWrite',
  // Humanized titles from tool_call_update enrichment still map when they
  // match the raw tool name prefix; otherwise left as-is for default icon.
};

/// Grok/Cursor meta-tools that wrap a real MCP invocation.
///
/// Keep in sync with happy-cli-go `grokMCPDispatchers` in
/// `internal/remote/grok/acp.go`.
const Set<String> grokMcpDispatchers = {
  'use_tool',
  'CallMcpTool',
  'call_mcp_tool',
  'callMcpTool',
};

/// Result of unwrapping a Grok MCP meta-dispatch tool call.
class GrokToolDispatch {
  const GrokToolDispatch({required this.name, required this.input});

  final String name;
  final Map<String, dynamic> input;
}

/// Unwraps `use_tool` / `CallMcpTool` into the real MCP tool + args.
///
/// Grok does not expose every MCP tool as a first-class model tool. It routes
/// through a dispatcher whose input is:
/// `{tool_name: "server__tool", tool_input: {...}}`.
/// Happy should show the inner tool like Claude's `mcp__server__tool`.
GrokToolDispatch unwrapGrokMcpDispatch(
  Object? rawName,
  Map<String, dynamic>? input,
) {
  final name = rawName?.toString().trim() ?? '';
  final rawInput = input == null
      ? <String, dynamic>{}
      : Map<String, dynamic>.from(input);
  if (!grokMcpDispatchers.contains(name)) {
    return GrokToolDispatch(name: name.isEmpty ? 'tool' : name, input: rawInput);
  }
  final innerName = _firstNonEmptyString(rawInput, const [
    'tool_name',
    'toolName',
    'name',
    'serverTool',
    'qualified_name',
  ]);
  if (innerName == null || innerName.isEmpty) {
    return GrokToolDispatch(name: name, input: rawInput);
  }
  final innerInput =
      WireParsers.asMap(rawInput['tool_input']) ??
      WireParsers.asMap(rawInput['toolInput']) ??
      WireParsers.asMap(rawInput['arguments']) ??
      WireParsers.asMap(rawInput['input']) ??
      WireParsers.asMap(rawInput['args']) ??
      WireParsers.asMap(rawInput['parameters']) ??
      <String, dynamic>{};
  return GrokToolDispatch(
    name: formatGrokMcpToolName(innerName),
    input: Map<String, dynamic>.from(innerInput),
  );
}

/// Formats a Grok qualified MCP name as Claude-style `mcp__server__tool`.
String formatGrokMcpToolName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('mcp__')) return trimmed;
  if (trimmed.contains('__')) return 'mcp__$trimmed';
  return trimmed;
}

/// Canonical display/tool-view name for a Grok (or already-canonical) tool.
///
/// Also prefixes bare `server__tool` MCP names with `mcp__` so MCP title
/// formatting applies even when the CLI did not rewrite the name.
String canonicalizeGrokToolName(Object? raw) {
  final name = raw?.toString().trim() ?? '';
  if (name.isEmpty) return 'tool';
  final aliased = grokToolNameAliases[name] ?? name;
  return formatGrokMcpToolName(aliased);
}

/// Rewrites Grok `rawInput` field names to Claude-compatible keys used by
/// Read / LS / Edit / Write views and [extractFilePath].
Map<String, dynamic> normalizeGrokToolInput(Map<String, dynamic>? input) {
  if (input == null || input.isEmpty) return <String, dynamic>{};
  final out = Map<String, dynamic>.from(input);

  // File path variants (read_file / search_replace / write).
  final filePath = _firstNonEmptyString(out, const [
    'file_path',
    'filePath',
    'target_file',
    'path',
  ]);
  if (filePath != null) {
    out
      ..putIfAbsent('file_path', () => filePath)
      ..putIfAbsent('path', () => filePath);
  }

  // Directory variants (list_dir).
  final dir = _firstNonEmptyString(out, const [
    'path',
    'target_directory',
    'directory',
    'cwd',
  ]);
  if (dir != null) {
    out
      ..putIfAbsent('path', () => dir)
      ..putIfAbsent('target_directory', () => dir);
  }

  // Shell: Grok uses `command` + `description` (already Claude-compatible).
  // Strip internal variant discriminators from the display input copy only
  // when they would confuse subtitle extractors (keep if alone).
  return out;
}

/// Full normalize pipeline: unwrap MCP dispatch, alias name, rewrite input keys.
GrokToolDispatch normalizeGrokToolCall(
  Object? rawName,
  Map<String, dynamic>? rawInput,
) {
  final unwrapped = unwrapGrokMcpDispatch(rawName, rawInput);
  return GrokToolDispatch(
    name: canonicalizeGrokToolName(unwrapped.name),
    input: normalizeGrokToolInput(unwrapped.input),
  );
}

/// Normalizes a Grok tool-result payload into shapes tool views parse.
///
/// Handles:
/// - ACP content block lists `[{type:content, content:{type:text,text}}]`
/// - Shell rawOutput with `output` / `exit_code`
/// - ListDir `Content.content` tree strings
/// - FileContent / nested text maps
dynamic normalizeGrokToolResult(dynamic result) {
  if (result == null) return null;

  // Content block list from session/update tool_call_update.content
  if (result is List) {
    final text = _textFromContentBlocks(result);
    if (text != null) return text;
    return result;
  }

  if (result is! Map) return result;
  final map = WireParsers.asMap(result);
  if (map == null) return result;

  // Prefer nested ACP content array when present alongside rawOutput-like maps.
  final nestedContent = map['content'];
  if (nestedContent is List) {
    final text = _textFromContentBlocks(nestedContent);
    if (text != null && text.isNotEmpty) {
      // Shell may still need exit code from sibling fields.
      if (_looksLikeShellResult(map)) {
        return _normalizeShellResult(map, stdoutOverride: text);
      }
      return text;
    }
  }

  if (_looksLikeShellResult(map)) {
    return _normalizeShellResult(map);
  }

  // ListDir: {type: ListDir, Content: {content: "...", absolute_root_path}}
  final listDirBody = WireParsers.asMap(map['Content']) ??
      WireParsers.asMap(map['content']);
  final listType = map['type']?.toString();
  if (listType == 'ListDir' ||
      (listDirBody != null && listDirBody.containsKey('absolute_root_path'))) {
    final tree = listDirBody?['content']?.toString();
    if (tree != null && tree.isNotEmpty) {
      final entries = _parseListDirTree(tree);
      if (entries.isNotEmpty) {
        return {
          'entries': entries,
          'content': tree,
          'path': listDirBody?['absolute_root_path'],
        };
      }
      return tree;
    }
  }

  // FileContent or generic nested text.
  if (listType == 'FileContent' || map.containsKey('FileContent')) {
    final fileBody = WireParsers.asMap(map['FileContent']) ??
        WireParsers.asMap(map['Content']);
    final text = fileBody?['content']?.toString() ??
        fileBody?['text']?.toString() ??
        map['text']?.toString();
    if (text != null && text.isNotEmpty) return text;
  }

  final directText = map['text']?.toString() ?? map['body']?.toString();
  if (directText != null && directText.isNotEmpty && map.length <= 3) {
    return directText;
  }

  return map;
}

bool _looksLikeShellResult(Map<String, dynamic> map) {
  return map.containsKey('exit_code') ||
      map.containsKey('exitCode') ||
      map.containsKey('output') ||
      map.containsKey('output_for_prompt') ||
      map.containsKey('stdout') ||
      map.containsKey('stderr');
}

Map<String, dynamic> _normalizeShellResult(
  Map<String, dynamic> map, {
  String? stdoutOverride,
}) {
  final stdout = stdoutOverride ??
      map['stdout']?.toString() ??
      map['output']?.toString() ??
      map['output_for_prompt']?.toString();
  final exitRaw = map['exitCode'] ?? map['exit_code'];
  int? exitCode;
  if (exitRaw is int) {
    exitCode = exitRaw;
  } else if (exitRaw is String) {
    exitCode = int.tryParse(exitRaw);
  }
  return {
    ?'stdout': stdout,
    ?'stderr': map['stderr'],
    ?'exitCode': exitCode,
    ?'command': map['command'],
    ?'description': map['description'],
    ?'truncated': map['truncated'],
    if (map['timed_out'] != null) 'timedOut': map['timed_out'],
  };
}

String? _textFromContentBlocks(List<dynamic> blocks) {
  final parts = <String>[];
  for (final block in blocks) {
    final map = WireParsers.asMap(block);
    if (map == null) continue;
    // {type: content, content: {type: text, text: "..."}}
    final inner = WireParsers.asMap(map['content']);
    if (inner != null) {
      final text = inner['text']?.toString();
      if (text != null && text.isNotEmpty) parts.add(text);
      continue;
    }
    final text = map['text']?.toString();
    if (text != null && text.isNotEmpty) parts.add(text);
  }
  if (parts.isEmpty) return null;
  return parts.join();
}

/// Parses Grok ListDir tree text into LS entry maps.
///
/// Example:
/// ```
/// - /tmp/foo/
///   - probe.txt
///   - README.md
/// ```
List<Map<String, dynamic>> _parseListDirTree(String tree) {
  final entries = <Map<String, dynamic>>[];
  for (final rawLine in tree.split('\n')) {
    final line = rawLine.trimRight();
    if (line.isEmpty) continue;
    final match = RegExp(r'^[\s|\\-]*-?\s*(.+)$').firstMatch(line.trim());
    final name = (match?.group(1) ?? line).trim();
    if (name.isEmpty) continue;
    // Skip absolute root path lines that are only the listing root.
    if (name.startsWith('/') && !name.contains(' ') && entries.isEmpty) {
      // Still record as directory for path context if it ends with /
      if (name.endsWith('/')) {
        continue; // root path shown via input.path
      }
    }
    final isDir = name.endsWith('/');
    final clean = isDir ? name.substring(0, name.length - 1) : name;
    // Prefer basename for nested indentation entries.
    final base = clean.contains('/') ? clean.split('/').last : clean;
    if (base.isEmpty) continue;
    entries.add({
      'name': base,
      'isDirectory': isDir,
      'isFile': !isDir,
    });
  }
  return entries;
}

String? _firstNonEmptyString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final v = map[key];
    if (v is String && v.trim().isNotEmpty) return v;
  }
  return null;
}
