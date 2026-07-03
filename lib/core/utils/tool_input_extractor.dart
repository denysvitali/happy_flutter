/// Centralized extraction of tool input fields that vary across providers.
///
/// Different agents (Claude, Codex, Gemini, Pi, etc.) emit tool calls with
/// different input field names for the same semantic concept. This utility
/// provides canonical extractors so tool views and the [KnownTools] registry
/// do not duplicate the same fallback chains.
///
/// All methods accept a [Map<String, dynamic>] (the tool's `input` field)
/// and return `null` when no matching field is found.
library;

import 'wire_parsers.dart';

// ---------------------------------------------------------------------------
// Command / shell extraction
// ---------------------------------------------------------------------------

/// Extracts a shell command string from tool input.
///
/// Tries these field names in order:
/// 1. `command` (Claude Bash)
/// 2. `cmd` (Codex function tools)
/// 3. `parsed_cmd` list's first element's `cmd` field (CodexBash)
///
/// For the `parsed_cmd` path, the result is cleaned via [cleanShellCommand]
/// if [clean] is true.
String? extractCommand(Map<String, dynamic> input, {bool clean = true}) {
  final direct = input['command'] as String?;
  if (direct != null && direct.isNotEmpty) return direct;

  final cmd = input['cmd'] as String?;
  if (cmd != null && cmd.isNotEmpty) return cmd;

  final parsedCmd = WireParsers.asList(input['parsed_cmd']);
  if (parsedCmd != null && parsedCmd.isNotEmpty) {
    final first = WireParsers.asMap(parsedCmd[0]);
    if (first != null) {
      final raw = first['cmd'] as String?;
      if (raw != null && raw.isNotEmpty) {
        return clean ? _cleanShellCommand(raw) : raw;
      }
    }
  }

  return null;
}

/// Extracts a command list (e.g. `['ls', '-la']`) from tool input.
///
/// Tries `command` (list) and `parsed_cmd` (list) in order.
List<dynamic>? extractCommandList(Map<String, dynamic> input) {
  final command = input['command'];
  if (command is List && command.isNotEmpty) return command;

  final parsedCmd = WireParsers.asList(input['parsed_cmd']);
  if (parsedCmd != null && parsedCmd.isNotEmpty) return parsedCmd;

  return null;
}

// ---------------------------------------------------------------------------
// File path extraction
// ---------------------------------------------------------------------------

/// Extracts a file path from tool input.
///
/// Tries these field names in order:
/// 1. `file_path` (Claude Read/Write)
/// 2. `filePath` (Edit tool)
/// 3. `path` (LS, Gemini edit)
/// 4. `locations[0].path` (Gemini Read format)
///
/// Returns `null` if no path is found.
String? extractFilePath(Map<String, dynamic> input) {
  final direct = input['file_path'] as String?;
  if (direct != null && direct.isNotEmpty) return direct;

  final camel = input['filePath'] as String?;
  if (camel != null && camel.isNotEmpty) return camel;

  final path = input['path'] as String?;
  if (path != null && path.isNotEmpty) return path;

  final locations = WireParsers.asList(input['locations']);
  if (locations != null && locations.isNotEmpty) {
    final first = WireParsers.asMap(locations[0]);
    if (first != null) {
      final locPath = first['path'] as String?;
      if (locPath != null && locPath.isNotEmpty) return locPath;
    }
  }

  return null;
}

/// Extracts a file path from nested Gemini toolCall content.
///
/// Checks `input['toolCall']['content'][0]['path']` and falls back to
/// `input['toolCall']['title']` with "Writing to " prefix stripping.
String? extractGeminiToolCallPath(Map<String, dynamic> input) {
  final toolCall = WireParsers.asMap(input['toolCall']);
  if (toolCall != null) {
    final content = WireParsers.asList(toolCall['content']);
    if (content != null && content.isNotEmpty) {
      final first = WireParsers.asMap(content[0]);
      if (first != null) {
        final path = first['path'] as String?;
        if (path != null && path.isNotEmpty) return path;
      }
    }
    final title = toolCall['title'] as String?;
    if (title != null && title.startsWith('Writing to ')) {
      return title.replaceFirst('Writing to ', '');
    }
  }
  return null;
}

/// Extracts a file path from a list of path objects.
///
/// Checks `input['input'][0]['path']` (Gemini array format).
String? extractPathFromInputList(Map<String, dynamic> input) {
  final inputList = WireParsers.asList(input['input']);
  if (inputList != null && inputList.isNotEmpty) {
    final first = WireParsers.asMap(inputList[0]);
    if (first != null) {
      final path = first['path'] as String?;
      if (path != null && path.isNotEmpty) return path;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Content / text extraction
// ---------------------------------------------------------------------------

/// Extracts content text from tool input or result.
///
/// Tries `content`, `text`, `body`, and `output` in order.
String? extractContentText(dynamic source) {
  if (source is String) return source;
  final map = WireParsers.asMap(source);
  if (map == null) return null;
  for (final key in const ['content', 'text', 'body', 'output']) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

/// Extracts diff/old/new text from edit tool input.
///
/// Tries `old_string` / `oldContent` and `new_string` / `newContent`.
({String? oldText, String? newText}) extractEditTexts(
  Map<String, dynamic> input,
) {
  return (
    oldText: input['old_string'] as String? ??
        input['oldContent'] as String?,
    newText: input['new_string'] as String? ??
        input['newContent'] as String?,
  );
}

// ---------------------------------------------------------------------------
// Working directory / CWD extraction
// ---------------------------------------------------------------------------

/// Extracts the working directory from tool input.
///
/// Tries `cwd`, `workdir`, and `working_dir` in order.
String? extractCwd(Map<String, dynamic> input) {
  return input['cwd'] as String? ??
      input['workdir'] as String? ??
      input['working_dir'] as String?;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

String _cleanShellCommand(String? cmd) {
  if (cmd == null || cmd.isEmpty) return '';
  return cmd.trim();
}
