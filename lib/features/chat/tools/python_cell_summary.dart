import '../../../core/utils/ansi_parser.dart';
import '../../../core/utils/grok_acp_normalize.dart';
import '../../../core/utils/text_truncate.dart';
import '../../../core/utils/tool_result_parser.dart';
import '../../../core/utils/utf16_sanitizer.dart';
import '../../../core/wire/wire_parsers.dart';

/// Small, plain-text summaries; the original call stays in the detail view.
String? pythonCellDescription(Map<String, dynamic> tool) {
  final input = WireParsers.toolInput(tool);
  for (final value in [
    input['description'],
    tool['description'],
    input['code'],
  ]) {
    if (value is! String || value.trim().isEmpty) continue;
    final line = _summaryLine(value);
    return line?.replaceFirst(RegExp(r'^#\s*'), '');
  }
  return null;
}

String? pythonCellOutputPreview(Map<String, dynamic> tool) {
  final result = normalizeGrokToolResult(tool['result']);
  final isError = tool['state'] == 'error';
  final stderr = parseStderr(result);
  if (stderr != null && stderr.trim().isNotEmpty) {
    return _summaryLine(stderr, last: true);
  }
  return _summaryLine(
    parseStdout(result) ?? (isError ? parseErrorText(result) : null),
    last: isError,
  );
}

String? _summaryLine(String? value, {bool last = false}) {
  if (value == null) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  final newline = last ? text.lastIndexOf('\n') : text.indexOf('\n');
  final line = newline < 0
      ? text
      : last
      ? text.substring(newline + 1)
      : text.substring(0, newline);
  final plain = sanitizeUtf16(AnsiParser.strip(line)).trim();
  return plain.isEmpty ? null : truncateGraphemes(plain, 120);
}
