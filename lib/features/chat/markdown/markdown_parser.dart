/// Markdown parser that converts raw markdown text into structured blocks.
///
/// Supports headers (H1-H6), lists, code blocks, tables, mermaid diagrams,
/// horizontal rules, and options blocks.
library;

import 'markdown_models.dart';

/// Parses markdown text into a list of structured blocks.
List<MarkdownBlock> parseMarkdown(String markdown) {
  return _MarkdownParser(markdown).parse();
}

class _MarkdownParser {
  final String markdown;
  final List<String> lines;
  int index = 0;

  _MarkdownParser(this.markdown) : lines = markdown.split('\n');

  List<MarkdownBlock> parse() {
    final blocks = <MarkdownBlock>[];

    while (index < lines.length) {
      final block = _parseBlock();
      if (block != null) {
        blocks.add(block);
      } else {
        index++;
      }
    }

    return blocks;
  }

  MarkdownBlock? _parseBlock() {
    final line = lines[index];
    final trimmed = line.trim();

    // Headers H1-H6
    for (int i = 1; i <= 6; i++) {
      if (trimmed.startsWith('${'#' * i} ')) {
        index++;
        return HeaderBlock(
          level: i,
          content: _parseSpans(trimmed.substring(i + 1), isHeader: true),
        );
      }
    }

    // Code block
    if (trimmed.startsWith('```')) {
      return _parseCodeBlock(trimmed);
    }

    // Horizontal rule
    if (trimmed == '---') {
      index++;
      return const HorizontalRuleBlock();
    }

    // Options block
    if (trimmed.startsWith('<options>')) {
      return _parseOptionsBlock();
    }

    // Numbered list
    final numberedMatch = _numberedListRegex.firstMatch(trimmed);
    if (numberedMatch != null) {
      return _parseNumberedList(numberedMatch);
    }

    // Unordered list
    if (trimmed.startsWith('- ')) {
      return _parseListBlock();
    }

    // Table detection
    if (trimmed.contains('|') && !trimmed.startsWith('```')) {
      final tableResult = _parseTable(lines, index);
      if (tableResult != null) {
        return tableResult;
      }
    }

    // Text block (fallback)
    if (trimmed.isNotEmpty) {
      index++;
      return TextBlock(content: _parseSpans(trimmed, isHeader: false));
    }

    return null;
  }

  static final _numberedListRegex = RegExp(r'^(\d+)\.\s');

  MarkdownBlock _parseCodeBlock(String firstLine) {
    final language = firstLine.length > 3 ? firstLine.substring(3).trim() : null;
    index++;

    final content = <String>[];
    while (index < lines.length) {
      final nextLine = lines[index];
      if (nextLine.trim() == '```') {
        index++;
        break;
      }
      content.add(nextLine);
      index++;
    }

    final contentString = content.join('\n');

    // Mermaid diagrams are code blocks with mermaid language
    if (language == 'mermaid') {
      return MermaidBlock(content: contentString);
    }

    return CodeBlock(language: language, content: contentString);
  }

  MarkdownBlock _parseOptionsBlock() {
    index++; // Skip opening tag
    final items = <String>[];

    while (index < lines.length) {
      final nextLine = lines[index].trim();
      if (nextLine == '</options>') {
        index++;
        break;
      }

      // Extract content from <option> tags
      final optionMatch = _optionTagRegex.firstMatch(nextLine);
      if (optionMatch != null) {
        items.add(optionMatch.group(1)!);
      }
      index++;
    }

    return OptionsBlock(items: items);
  }

  static final _optionTagRegex = RegExp(r'<option>(.*?)</option>');

  MarkdownBlock _parseNumberedList(RegExpMatch firstMatch) {
    final allItems = <NumberedItem>[];

    final firstNumber = int.parse(firstMatch.group(1)!);
    final currentLine = lines[index].trim();
    final firstContent = currentLine.substring(firstMatch.group(0)!.length);
    allItems.add(NumberedItem(
      number: firstNumber,
      spans: _parseSpans(firstContent, isHeader: false),
    ));
    index++;

    // Continue collecting numbered list items
    while (index < lines.length) {
      final nextLine = lines[index].trim();
      final nextMatch = _numberedListRegex.firstMatch(nextLine);
      if (nextMatch == null) break;

      final number = int.parse(nextMatch.group(1)!);
      final content = nextLine.substring(nextMatch.group(0)!.length);
      allItems.add(NumberedItem(
        number: number,
        spans: _parseSpans(content, isHeader: false),
      ));
      index++;
    }

    return NumberedListBlock(items: allItems);
  }

  MarkdownBlock _parseListBlock() {
    final allItems = <List<MarkdownSpan>>[];
    final firstLine = lines[index].trim();
    allItems.add(_parseSpans(firstLine.substring(2), isHeader: false));
    index++;

    while (index < lines.length) {
      final nextLine = lines[index].trim();
      if (!nextLine.startsWith('- ')) break;
      allItems.add(_parseSpans(nextLine.substring(2), isHeader: false));
      index++;
    }

    return ListBlock(items: allItems);
  }

  TableBlock? _parseTable(List<String> allLines, int startIndex) {
    final tableLines = <String>[];

    // Collect consecutive lines with pipe characters
    while (startIndex < allLines.length && allLines[startIndex].contains('|')) {
      tableLines.add(allLines[startIndex]);
      startIndex++;
    }

    if (tableLines.length < 2) return null;

    // Validate separator line
    final separatorLine = tableLines[1].trim();
    final isSeparator =
        RegExp(r'^[|\s\-:=]*$').hasMatch(separatorLine) && separatorLine.contains('-');

    if (!isSeparator) return null;

    // Parse headers
    final headerLine = tableLines[0].trim();
    final headers = headerLine
        .split('|')
        .map((cell) => cell.trim())
        .where((cell) => cell.isNotEmpty)
        .toList();

    if (headers.isEmpty) return null;

    // Parse rows
    final rows = <List<String>>[];
    for (int i = 2; i < tableLines.length; i++) {
      final rowLine = tableLines[i].trim();
      if (rowLine.startsWith('|')) {
        final rowCells = rowLine
            .split('|')
            .map((cell) => cell.trim())
            .where((cell) => cell.isNotEmpty)
            .toList();

        if (rowCells.isNotEmpty) {
          rows.add(rowCells);
        }
      }
    }

    // Update index to end of table
    index = startIndex;

    return TableBlock(headers: headers, rows: rows);
  }

  List<MarkdownSpan> _parseSpans(String text, {required bool isHeader}) {
    final spans = <MarkdownSpan>[];
    final pattern = _spanPattern;
    final matches = pattern.allMatches(text);
    int lastIndex = 0;

    for (final match in matches) {
      // Plain text before the match
      final beforeText = text.substring(lastIndex, match.start);
      if (beforeText.isNotEmpty) {
        spans.add(const MarkdownSpan(styles: [], text: '', url: null));
        spans[spans.length - 1] = MarkdownSpan(
          styles: const [],
          text: beforeText,
          url: null,
        );
      }

      // Bold: **text**
      if (match.group(1) != null) {
        final boldText = match.group(2)!;
        spans.add(MarkdownSpan(
          styles: isHeader ? [] : [MarkdownTextStyle.bold],
          text: boldText,
          url: null,
        ));
      }
      // Italic: *text*
      else if (match.group(3) != null) {
        final italicText = match.group(4)!;
        spans.add(MarkdownSpan(
          styles: isHeader ? [] : [MarkdownTextStyle.italic],
          text: italicText,
          url: null,
        ));
      }
      // Link: [text](url) or incomplete link [text]
      else if (match.group(5) != null) {
        final linkText = match.group(5)!;
        final url = match.group(7);
        spans.add(MarkdownSpan(
          styles: const [],
          text: url != null ? linkText : '[$linkText]',
          url: url,
        ));
      }
      // Inline code: `text`
      else if (match.group(8) != null) {
        final codeText = match.group(9)!;
        spans.add(MarkdownSpan(
          styles: [MarkdownTextStyle.code],
          text: codeText,
          url: null,
        ));
      }

      lastIndex = match.end;
    }

    // Remaining text after last match
    if (lastIndex < text.length) {
      spans.add(MarkdownSpan(
        styles: const [],
        text: text.substring(lastIndex),
        url: null,
      ));
    }

    return spans;
  }

  static final _spanPattern = RegExp(
    r'(\*\*(.*?)(?:\*\*|$))|(\*(.*?)(?:\*|$))|(\[([^\]]+)\](?:\(([^)]+)\))?)|(`(.*?)(?:`|$))',
  );

  String get trimmed => lines[index].trim();
}
