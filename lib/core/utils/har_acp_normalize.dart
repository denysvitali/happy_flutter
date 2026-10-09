/// Pure-Dart normalizers for har ACP tool payloads.
///
/// happy-cli-go forwards har tool calls with har's own tool names and
/// arguments, and marks them with `_meta.har`. These helpers rewrite them
/// into the shapes Flutter tool views already understand (Bash/Read/Edit/
/// Write/LS/Grep) and turn har's canonical JSON observations into the text a
/// person expects: command output, file text, one path per line.
///
/// Must stay free of Flutter imports — [message_processor] runs in isolates.
library;

import 'dart:convert';

import '../wire/wire_parsers.dart';
import 'grok_acp_normalize.dart' show GrokToolDispatch;

/// har's own tool name for a tool-call or tool-result body, or null when the
/// body did not come from har.
///
/// Root calls carry `_meta.har.tool.name`; a delegated child's rows carry
/// `_meta.har.progress.tool`.
String? harToolName(Map<String, dynamic> data) {
  final har = WireParsers.asMap(WireParsers.asMap(data['_meta'])?['har']);
  if (har == null) return null;
  final name =
      WireParsers.asMap(har['tool'])?['name'] ??
      WireParsers.asMap(har['progress'])?['tool'];
  return name is String && name.isNotEmpty ? name : null;
}

/// har's built-in host tools, whose results are canonical observations.
///
/// Delegation and MCP tools are not listed: happy-cli-go already presents a
/// delegate as an Agent, and MCP results have their own shapes.
const Set<String> harHostTools = {
  'command',
  'diff',
  'read_file',
  'read_files',
  'edit_file',
  'list_files',
  'search_files',
  'rg',
  'artifact',
};

/// Maps a har tool call onto the display name and input keys of the matching
/// Happy tool view, or returns null for a tool without one.
GrokToolDispatch? normalizeHarToolCall(
  String harName,
  Map<String, dynamic>? rawInput,
) {
  final input = Map<String, dynamic>.from(rawInput ?? const {});
  switch (harName) {
    case 'command':
      return GrokToolDispatch(name: 'Bash', input: input);
    case 'read_file':
      _alias(input, 'path', 'file_path');
      return GrokToolDispatch(name: 'Read', input: input);
    case 'edit_file':
      _alias(input, 'path', 'file_path');
      // har creates a file with expected_version "absent" and no old text.
      if (input['expected_version'] == 'absent' &&
          (input['old_text'] ?? '') == '') {
        _alias(input, 'new_text', 'content');
        return GrokToolDispatch(name: 'Write', input: input);
      }
      _alias(input, 'old_text', 'old_string');
      _alias(input, 'new_text', 'new_string');
      return GrokToolDispatch(name: 'Edit', input: input);
    case 'list_files':
      input.putIfAbsent('path', () => '.');
      return GrokToolDispatch(name: 'LS', input: input);
    case 'search_files':
    case 'rg':
      // har always returns matching lines with their line numbers.
      input
        ..putIfAbsent('output_mode', () => 'content')
        ..putIfAbsent('-n', () => true);
      return GrokToolDispatch(name: 'Grep', input: input);
    default:
      return null;
  }
}

void _alias(Map<String, dynamic> input, String from, String to) {
  final value = input[from];
  if (value != null) input.putIfAbsent(to, () => value);
}

/// Normalizes a har tool result for display.
///
/// Current har sends plaintext. Older har, and results stored before it
/// changed, carry the canonical JSON observation as text; that is rendered to
/// the same plaintext here. `list_files` becomes a list of paths so the LS
/// view can show entries. Unrecognized content is returned unchanged; a tool
/// that is not one of [harHostTools] yields null.
dynamic normalizeHarToolResult(String harName, dynamic result) {
  if (!harHostTools.contains(harName)) return null;
  final text = _resultText(result);
  if (text == null) return result;
  final plain = _plainFromEnvelope(harName, text) ?? text;
  if (harName == 'list_files') {
    final paths = [
      for (final line in const LineSplitter().convert(plain))
        if (line.isNotEmpty && !_isNote(line) && line != '(empty)') line,
    ];
    if (paths.isNotEmpty) return paths;
  }
  return plain;
}

bool _isNote(String line) => line.startsWith('[') && line.endsWith(']');

String? _resultText(dynamic result) {
  if (result is String) return result;
  if (result is! List) return null;
  final parts = <String>[];
  for (final block in result) {
    final content = WireParsers.asMap(WireParsers.asMap(block)?['content']);
    final text = content?['text'];
    if (text is! String) return null;
    parts.add(text);
  }
  return parts.isEmpty ? null : parts.join('\n');
}

/// Renders a canonical har observation, or null when [text] is not one.
String? _plainFromEnvelope(String harName, String text) {
  if (!text.startsWith('{')) return null;
  final Map<String, dynamic>? data;
  try {
    data = WireParsers.asMap(jsonDecode(text));
  } catch (_) {
    return null;
  }
  // Every har host observation states its outcome with these two fields.
  if (data == null || data['failed'] is! bool || data['effect'] is! String) {
    return null;
  }
  return _plainError(data) ?? _plainTool(harName, data);
}

String? _plainTool(String harName, Map<String, dynamic> data) {
  switch (harName) {
    case 'command':
    case 'diff':
      return _plainCommand(data);
    case 'list_files':
      return _plainList(data);
    case 'search_files':
    case 'rg':
      return _plainSearch(data);
    case 'read_file':
      return _plainRead(data);
    case 'read_files':
      return _plainReadFiles(data);
    case 'edit_file':
      return _plainEdit(data);
    case 'artifact':
      return _plainArtifact(data);
    default:
      return null;
  }
}

String? _plainError(Map<String, dynamic> data) {
  final code = data['error'];
  if (code is! String || code.isEmpty) return null;
  final message = data['message'];
  return message is String && message.isNotEmpty
      ? 'error: $code\n$message'
      : 'error: $code';
}

String _trimEnd(Object? value) =>
    value is String ? value.replaceFirst(RegExp(r'\n+$'), '') : '';

String _withNotes(String body, List<String> notes) {
  final out = StringBuffer(body);
  for (final note in notes) {
    if (out.isNotEmpty) out.write('\n');
    out.write('[$note]');
  }
  return out.toString();
}

String? _plainCommand(Map<String, dynamic> data) {
  if (!data.containsKey('stdout')) return null;
  final out = StringBuffer(_trimEnd(data['stdout']));
  final stderr = _trimEnd(data['stderr']);
  if (stderr.trim().isNotEmpty) {
    if (out.isNotEmpty) out.write('\n');
    out.write('--- stderr ---\n$stderr');
  }
  final notes = <String>[];
  final exit = data['exit_code'];
  final termination = data['termination'];
  final interrupted =
      termination is String &&
      termination.isNotEmpty &&
      termination != 'exited';
  if ((exit is num && exit != 0) || interrupted) {
    notes.add(interrupted ? 'exit ${exit ?? 0} $termination' : 'exit $exit');
  }
  if (data['effect'] == 'unknown') notes.add('effect unknown');
  if (data['stdout_truncated'] == true || data['stderr_truncated'] == true) {
    final id = data['artifact_id'];
    notes.add(
      id is String && id.isNotEmpty
          ? 'output truncated; artifact $id'
          : 'output truncated',
    );
  }
  if (data['drain_incomplete'] == true) notes.add('output drain incomplete');
  final artifactError = data['artifact_error'];
  if (artifactError is String && artifactError.isNotEmpty) {
    notes.add(artifactError);
  }
  if (out.isEmpty && notes.isEmpty) return '(no output)';
  return _withNotes(out.toString(), notes);
}

String? _plainList(Map<String, dynamic> data) {
  final entries = WireParsers.asList(data['entries']);
  if (entries == null) return null;
  final lines = <String>[];
  for (final raw in entries) {
    final entry = WireParsers.asMap(raw);
    final path = entry?['path'];
    if (path is! String) return null;
    lines.add(
      entry?['directory'] == true
          ? '$path/'
          : entry?['symlink'] == true
          ? '$path@'
          : path,
    );
  }
  final notes = [if (data['truncated'] == true) 'list truncated'];
  if (lines.isEmpty && notes.isEmpty) return '(empty)';
  return _withNotes(lines.join('\n'), notes);
}

String? _plainSearch(Map<String, dynamic> data) {
  final matches = WireParsers.asList(data['matches']);
  if (matches == null) return null;
  final lines = <String>[];
  for (final raw in matches) {
    final match = WireParsers.asMap(raw);
    if (match == null) return null;
    lines.add('${match['path']}:${match['line']}:${match['content']}');
  }
  final notes = [if (data['truncated'] == true) 'results truncated'];
  if (lines.isEmpty && notes.isEmpty) return '(no matches)';
  return _withNotes(lines.join('\n'), notes);
}

String? _plainRead(Map<String, dynamic> data) {
  if (!data.containsKey('content')) return null;
  final notes = <String>[];
  if (data['truncated'] == true) {
    final line = data['next_start_line'];
    final column = data['next_start_column'];
    notes.add(
      'truncated; next line $line column $column of '
      "${data['total_lines']} lines",
    );
  }
  return _withNotes(_trimEnd(data['content']), notes);
}

String? _plainReadFiles(Map<String, dynamic> data) {
  final files = WireParsers.asList(data['files']);
  if (files == null) return null;
  final parts = <String>[];
  for (var i = 0; i < files.length; i++) {
    final page = WireParsers.asMap(files[i]);
    if (page == null) return null;
    final body = _plainError(page) ?? _plainRead(page);
    if (body == null) return null;
    final path = page['path'];
    final label = path is String && path.isNotEmpty ? path : 'file ${i + 1}';
    parts.add('==> $label <==\n$body');
  }
  return parts.join('\n\n');
}

String? _plainEdit(Map<String, dynamic> data) {
  if (!data.containsKey('new_version')) return null;
  final notes = [if (data['diff_truncated'] == true) 'diff truncated'];
  var diff = _trimEnd(data['diff']);
  if (diff.isEmpty) {
    diff = '${data['created'] == true ? 'created' : 'edited'} ${data['path']}';
  }
  return _withNotes(diff, notes);
}

String? _plainArtifact(Map<String, dynamic> data) {
  if (!data.containsKey('content')) return null;
  final notes = <String>[];
  if (data['truncated'] == true) {
    final next = data['next_offset'];
    notes.add('truncated; next offset $next of ${data['total_bytes']} bytes');
  }
  return _withNotes(_trimEnd(data['content']), notes);
}
