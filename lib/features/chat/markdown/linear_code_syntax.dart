import 'package:markdown/markdown.dart' as md;

/// Inline code without the backtracking regexp used by markdown's CodeSyntax.
/// Index delimiter runs once per parser, so unfinished streaming input and
/// runs of different widths have bounded work as well as bounded stack usage.
class LinearCodeSyntax extends md.InlineSyntax {
  LinearCodeSyntax() : super('`');

  final _ends = Expando<Map<int, int>>();

  @override
  bool tryMatch(md.InlineParser parser, [int? startMatchPos]) {
    final source = parser.source;
    final start = parser.pos;
    if (source.codeUnitAt(start) != 96) return false;
    final ends = _ends[parser] ??= _indexRuns(source);
    var contentStart = start;
    while (contentStart < source.length &&
        source.codeUnitAt(contentStart) == 96) {
      contentStart++;
    }
    final end = ends[start];
    parser.writeText();
    if (end == null || (start > 0 && source.codeUnitAt(start - 1) == 96)) {
      // Consume unmatched markers ourselves: returning false would run the
      // default CodeSyntax regexp on the same input again.
      parser.addNode(md.Text(source.substring(start, contentStart)));
      parser.consume(contentStart - start);
      return true;
    }
    var code = source.substring(contentStart, end).replaceAll('\n', ' ');
    if (code.startsWith(' ') && code.endsWith(' ') && code.trim().isNotEmpty) {
      code = code.substring(1, code.length - 1);
    }
    if (parser.encodeHtml) {
      code = code
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('"', '&quot;');
    }
    parser.addNode(md.Element.text('code', code));
    final markerWidth = contentStart - start;
    parser.consume(end + markerWidth - start);
    return true;
  }

  Map<int, int> _indexRuns(String source) {
    final previous = <int, int>{};
    final ends = <int, int>{};
    var index = 0;
    while (index < source.length) {
      if (source.codeUnitAt(index) != 96) {
        index++;
        continue;
      }
      final start = index;
      while (index < source.length && source.codeUnitAt(index) == 96) {
        index++;
      }
      final width = index - start;
      final prior = previous[width];
      if (prior != null) ends[prior] = start;
      previous[width] = start;
    }
    return ends;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) => false;
}
