import 'package:flutter/material.dart';
import 'diff_view.dart';

/// Diff view colors for theming.
class DiffViewColors {
  /// Background colors
  final Color addedBg;
  final Color removedBg;
  final Color contextBg;
  final Color hunkHeaderBg;
  final Color lineNumberBg;

  /// Text colors
  final Color addedText;
  final Color removedText;
  final Color contextText;
  final Color hunkHeaderText;
  final Color lineNumberText;

  /// Inline highlight colors
  final Color inlineAddedBg;
  final Color inlineAddedText;
  final Color inlineRemovedBg;
  final Color inlineRemovedText;

  /// Other colors
  final Color leadingSpaceDot;

  DiffViewColors({
    required this.addedBg,
    required this.removedBg,
    required this.contextBg,
    required this.hunkHeaderBg,
    required this.lineNumberBg,
    required this.addedText,
    required this.removedText,
    required this.contextText,
    required this.hunkHeaderText,
    required this.lineNumberText,
    required this.inlineAddedBg,
    required this.inlineAddedText,
    required this.inlineRemovedBg,
    required this.inlineRemovedText,
    required this.leadingSpaceDot,
  });

  /// Light theme colors
  factory DiffViewColors.light() {
    return DiffViewColors(
      addedBg: const Color(0xFFE6FFEC),
      removedBg: const Color(0xFFFFEBE9),
      contextBg: Colors.transparent,
      hunkHeaderBg: const Color(0xFFF0F0F0),
      lineNumberBg: const Color(0xFFF5F5F5),
      addedText: const Color(0xFF1A7F37),
      removedText: const Color(0xFFCF222E),
      contextText: const Color(0xFF24292F),
      hunkHeaderText: const Color(0xFF656D76),
      lineNumberText: const Color(0xFF6E7781),
      inlineAddedBg: const Color(0xFF4AC26B4D),
      inlineAddedText: const Color(0xFF1A7F37),
      inlineRemovedBg: const Color(0xFFFFA39E4D),
      inlineRemovedText: const Color(0xFFCF222E),
      leadingSpaceDot: const Color(0xFFD4D4D4),
    );
  }

  /// Dark theme colors
  factory DiffViewColors.dark() {
    return DiffViewColors(
      addedBg: const Color(0xFF1A2D1A),
      removedBg: const Color(0xFF2D1A1A),
      contextBg: Colors.transparent,
      hunkHeaderBg: const Color(0xFF2D2D2D),
      lineNumberBg: const Color(0xFF252525),
      addedText: const Color(0xFF4AC26B),
      removedText: const Color(0xFFFF7B72),
      contextText: const Color(0xFFC9D1D9),
      hunkHeaderText: const Color(0xFF8B949E),
      lineNumberText: const Color(0xFF6E7681),
      inlineAddedBg: const Color(0xFF4AC26B33),
      inlineAddedText: const Color(0xFF4AC26B),
      inlineRemovedBg: const Color(0xFFFFA39E33),
      inlineRemovedText: const Color(0xFFFF7B72),
      leadingSpaceDot: const Color(0xFF4A4A4A),
    );
  }
}

/// Configuration for diff view styling.
class DiffViewConfig {
  /// Font size for diff content
  final double fontSize;

  /// Line height for diff lines
  final double lineHeight;

  /// Horizontal padding for lines
  final double linePaddingHorizontal;

  /// Padding for hunk headers
  final double hunkHeaderPadding;

  /// Width for line number column
  final double lineNumberWidth;

  /// Whether to use monospace font
  final bool useMonospaceFont;

  DiffViewConfig({
    this.fontSize = 13,
    this.lineHeight = 20,
    this.linePaddingHorizontal = 8,
    this.hunkHeaderPadding = 8,
    this.lineNumberWidth = 40,
    this.useMonospaceFont = true,
  });
}

/// A Flutter widget for displaying git diffs with syntax highlighting.
///
/// Matches the behavior of the React Native DiffView.tsx component.
class DiffView extends StatefulWidget {
  /// The old/original text
  final String oldText;

  /// The new/modified text
  final String newText;

  /// Number of context lines around changes (default: 3)
  final int contextLines;

  /// Whether to show line numbers (default: true)
  final bool showLineNumbers;

  /// Whether to show +/- symbols (default: true)
  final bool showPlusMinusSymbols;

  /// Whether to wrap long lines (default: false)
  final bool wrapLines;

  /// Custom colors for the diff view (null = use theme-based colors)
  final DiffViewColors? colors;

  /// Custom configuration for styling
  final DiffViewConfig? config;

  /// Title for the old file (optional)
  final String? oldTitle;

  /// Title for the new file (optional)
  final String? newTitle;

  /// Maximum height constraint
  final double? maxHeight;

  /// Background color override
  final Color? backgroundColor;

  const DiffView({
    super.key,
    required this.oldText,
    required this.newText,
    this.contextLines = 3,
    this.showLineNumbers = true,
    this.showPlusMinusSymbols = true,
    this.wrapLines = false,
    this.colors,
    this.config,
    this.oldTitle,
    this.newTitle,
    this.maxHeight,
    this.backgroundColor,
  });

  @override
  State<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> {
  late DiffResult _diffResult;
  late DiffViewColors _colors;
  late DiffViewConfig _config;

  @override
  void initState() {
    super.initState();
    _diffResult = DiffParser.compareStrings(
      widget.oldText,
      widget.newText,
      contextLines: widget.contextLines,
    );
  }

  @override
  void didUpdateWidget(DiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldText != widget.oldText ||
        oldWidget.newText != widget.newText ||
        oldWidget.contextLines != widget.contextLines) {
      _diffResult = DiffParser.compareStrings(
        widget.oldText,
        widget.newText,
        contextLines: widget.contextLines,
      );
    }
  }

  DiffViewColors _getColors(BuildContext context) {
    if (widget.colors != null) {
      return widget.colors!;
    }

    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? DiffViewColors.dark()
        : DiffViewColors.light();
  }

  DiffViewConfig _getConfig() {
    return widget.config ?? DiffViewConfig();
  }

  @override
  Widget build(BuildContext context) {
    _colors = _getColors(context);
    _config = _getConfig();

    final content = _buildDiffContent();

    return Container(
      constraints: widget.maxHeight != null
          ? BoxConstraints(maxHeight: widget.maxHeight!)
          : null,
      color: widget.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDiffContent() {
    final lines = <Widget>[];

    for (int hunkIndex = 0;
        hunkIndex < _diffResult.hunks.length;
        hunkIndex++) {
      final hunk = _diffResult.hunks[hunkIndex];

      // Add hunk header for non-first hunks
      if (hunkIndex > 0) {
        lines.add(_buildHunkHeader(hunk));
      }

      // Add lines in this hunk
      for (int lineIndex = 0; lineIndex < hunk.lines.length; lineIndex++) {
        lines.add(_buildDiffLine(hunk.lines[lineIndex]));
      }
    }

    return lines;
  }

  Widget _buildHunkHeader(DiffHunk hunk) {
    final headerText =
        '@@ -${hunk.oldStart},${hunk.oldLines} +${hunk.newStart},${hunk.newLines} @@';

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: _config.hunkHeaderPadding,
        horizontal: _config.linePaddingHorizontal,
      ),
      color: _colors.hunkHeaderBg,
      child: Text(
        headerText,
        style: TextStyle(
          fontSize: _config.fontSize - 1,
          color: _colors.hunkHeaderText,
          fontFamily: _config.useMonospaceFont ? 'monospace' : null,
        ),
      ),
    );
  }

  Widget _buildDiffLine(DiffLine line) {
    final isAdded = line.type == DiffLineType.add;
    final isRemoved = line.type == DiffLineType.remove;

    final textColor = isAdded
        ? _colors.addedText
        : isRemoved
            ? _colors.removedText
            : _colors.contextText;
    final bgColor = isAdded
        ? _colors.addedBg
        : isRemoved
            ? _colors.removedBg
            : _colors.contextBg;

    return Container(
      color: bgColor,
      padding: EdgeInsets.symmetric(
        horizontal: _config.linePaddingHorizontal,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line number column
          if (widget.showLineNumbers)
            SizedBox(
              width: _config.lineNumberWidth,
              child: Text(
                _getLineNumberText(line),
                style: TextStyle(
                  fontSize: _config.fontSize,
                  color: _colors.lineNumberText,
                  fontFamily: _config.useMonospaceFont ? 'monospace' : null,
                ),
                textAlign: TextAlign.end,
              ),
            ),

          // +/- symbol column
          if (widget.showPlusMinusSymbols)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                isAdded ? '+' : isRemoved ? '-' : ' ',
                style: TextStyle(
                  fontSize: _config.fontSize,
                  color: textColor,
                  fontFamily: _config.useMonospaceFont ? 'monospace' : null,
                ),
              ),
            ),

          // Line content
          Expanded(
            child: _buildLineContent(line, textColor),
          ),
        ],
      ),
    );
  }

  String _getLineNumberText(DiffLine line) {
    final number = line.type == DiffLineType.remove
        ? line.oldLineNumber
        : line.type == DiffLineType.add
            ? line.newLineNumber
            : line.oldLineNumber;

    if (number == null) return '';

    return number.toString().padLeft(3, ' ');
  }

  Widget _buildLineContent(DiffLine line, Color baseColor) {
    final formatted = _formatLineContent(line.content);

    if (line.tokens != null && line.tokens!.isNotEmpty) {
      return _buildWithInlineHighlighting(formatted, line.tokens!, baseColor);
    }

    return _buildPlainContent(formatted, baseColor);
  }

  String _formatLineContent(String content) {
    // Trim trailing spaces
    return content.trimRight();
  }

  Widget _buildWithInlineHighlighting(
    String content,
    List<DiffToken> tokens,
    Color baseColor,
  ) {
    final spans = <InlineSpan>[];
    bool processedLeadingSpaces = false;

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      // Process leading spaces in the first token only
      if (!processedLeadingSpaces && token.value.isNotEmpty) {
        final leadingMatch = RegExp(r'^( +)').firstMatch(token.value);
        if (leadingMatch != null) {
          processedLeadingSpaces = true;
          final leadingSpaces = leadingMatch[1]!;
          final leadingDots = '\u00B7' * leadingSpaces.length;
          final restOfToken = token.value.substring(leadingMatch[0]!.length);

          spans.add(TextSpan(
            text: leadingDots,
            style: TextStyle(color: _colors.leadingSpaceDot),
          ));

          if (restOfToken.isNotEmpty) {
            spans.add(_buildTokenSpan(restOfToken, token, baseColor));
          }
          continue;
        }
        processedLeadingSpaces = true;
      }

      spans.add(_buildTokenSpan(token.value, token, baseColor));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontSize: _config.fontSize,
        height: _config.lineHeight / _config.fontSize,
        fontFamily: _config.useMonospaceFont ? 'monospace' : null,
      ),
      softWrap: widget.wrapLines,
    );
  }

  InlineSpan _buildTokenSpan(
    String value,
    DiffToken token,
    Color baseColor,
  ) {
    if (token.added || token.removed) {
      return TextSpan(
        text: value,
        style: TextStyle(
          backgroundColor: token.added
              ? _colors.inlineAddedBg
              : _colors.inlineRemovedBg,
          color: token.added
              ? _colors.inlineAddedText
              : _colors.inlineRemovedText,
        ),
      );
    }

    return TextSpan(
      text: value,
      style: TextStyle(color: baseColor),
    );
  }

  Widget _buildPlainContent(String content, Color baseColor) {
    // Convert leading spaces to dots
    final leadingMatch = RegExp(r'^( +)').firstMatch(content);
    final widgets = <Widget>[];

    if (leadingMatch != null) {
      final leadingSpaces = leadingMatch[1]!;
      final leadingDots = '\u00B7' * leadingSpaces.length;
      final mainContent = content.substring(leadingMatch[0]!.length);

      widgets.add(Text(
        leadingDots,
        style: TextStyle(
          color: _colors.leadingSpaceDot,
          fontFamily: _config.useMonospaceFont ? 'monospace' : null,
        ),
      ));

      if (mainContent.isNotEmpty) {
        widgets.add(Text(
          mainContent,
          style: TextStyle(
            color: baseColor,
            fontFamily: _config.useMonospaceFont ? 'monospace' : null,
          ),
        ));
      }
    } else {
      widgets.add(Text(
        content,
        style: TextStyle(
          color: baseColor,
          fontFamily: _config.useMonospaceFont ? 'monospace' : null,
        ),
      ));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}

/// Extension on DiffResult for computing diff stats.
extension DiffResultExtension on DiffResult {
  /// Get the total number of changed lines
  int get totalChanges => stats.additions + stats.deletions;

  /// Get the list of added lines
  List<DiffLine> get addedLines =>
      hunks.expand((h) => h.lines).where((l) => l.type == DiffLineType.add).toList();

  /// Get the list of removed lines
  List<DiffLine> get removedLines =>
      hunks.expand((h) => h.lines).where((l) => l.type == DiffLineType.remove).toList();

  /// Get the list of context lines
  List<DiffLine> get contextLines =>
      hunks.expand((h) => h.lines).where((l) => l.type == DiffLineType.normal).toList();
}
