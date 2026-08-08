import '../../core/rpc/rpc_types.dart';

/// Bounded in-memory history for the one-off command runner.
///
/// The daemon already bounds each response stream, but repeated commands can
/// otherwise grow the screen's retained widget/data list for the app's entire
/// lifetime. This buffer keeps the newest lines across command invocations.
class TerminalOutputBuffer {
  TerminalOutputBuffer({this.maxRetainedLines = 2000})
    : assert(maxRetainedLines > 0);

  final int maxRetainedLines;
  final List<String> _lines = <String>[];

  List<String> get lines => _lines;

  void appendLine(String line) {
    _lines.add(line);
    _trim();
  }

  void appendResult(BashResponse result, {required String truncationNotice}) {
    final stdout = result.stdout.trim();
    final stderr = result.stderr.trim();
    if (stdout.isNotEmpty) _lines.addAll(stdout.split('\n'));
    if (stderr.isNotEmpty) _lines.addAll(stderr.split('\n'));
    if (stdout.isEmpty && stderr.isEmpty) _lines.add('');
    if (result.outputTruncated) _lines.add(truncationNotice);
    _trim();
  }

  void _trim() {
    final overflow = _lines.length - maxRetainedLines;
    if (overflow > 0) _lines.removeRange(0, overflow);
  }
}
