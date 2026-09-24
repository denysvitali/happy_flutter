/// Count lines and select the visible prefix without allocating a line list.
/// A trailing newline creates a final empty line, matching `split('\n')`.
({int totalLines, bool needsTruncation, String visibleText})
prepareTerminalOutputPreview(String text, int maxLines) {
  var totalLines = 1;
  var visibleEnd = maxLines <= 0 ? 0 : -1;
  var searchFrom = 0;
  while (true) {
    final newline = text.indexOf('\n', searchFrom);
    if (newline < 0) break;
    totalLines++;
    if (totalLines == maxLines + 1) visibleEnd = newline;
    searchFrom = newline + 1;
  }
  final needsTruncation = totalLines > maxLines;
  return (
    totalLines: totalLines,
    needsTruncation: needsTruncation,
    visibleText: needsTruncation
        ? text.substring(0, visibleEnd < 0 ? 0 : visibleEnd)
        : text,
  );
}
