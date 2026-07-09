import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/diff_theme.dart';
import 'calculate_diff.dart';
import 'diff_types.dart';

/// Default tab width used when expanding `\t` for monospace rendering.
const int kDiffTabSize = 4;

/// Canonical unified-diff body used by every diff-rendering tool view.
///
/// This is the single implementation that turns [oldText] / [newText] into
/// hunk headers, line numbers, +/- symbols, and inline word-level change
/// highlights. It resolves its palette from the ambient [DiffTheme]
/// ThemeExtension (see [context.diffTheme]); there is no legacy color
/// translation layer.
///
/// Rendering contract:
/// - All code text uses a monospace face at [fontSize]
/// - Tabs expand to spaces at [kDiffTabSize] stops so columns align
/// - Leading spaces render as mid-dots (·) so indentation is visible
class UnifiedDiffView extends StatefulWidget {
  /// Creates a [UnifiedDiffView].
  const UnifiedDiffView({
    required this.oldText,
    required this.newText,
    super.key,
    this.contextLines = 3,
    this.showLineNumbers = true,
    this.showPlusMinusSymbols = true,
    this.showDiffStats = false,
    this.fontSize = AppFontSize.sm,
  });

  /// Old/original text.
  final String oldText;

  /// New/modified text.
  final String newText;

  /// Number of context lines around each hunk.
  final int contextLines;

  /// Whether to render the old/new line number gutter.
  final bool showLineNumbers;

  /// Whether to render '+' / '-' / ' ' symbols before each line.
  final bool showPlusMinusSymbols;

  /// Whether to render the +additions / -deletions stats row at the top.
  final bool showDiffStats;

  /// Font size for diff content (line numbers, symbols, code).
  ///
  /// Defaults to [AppFontSize.sm] (12) for a dense tool-output look.
  final double fontSize;

  @override
  State<UnifiedDiffView> createState() => _UnifiedDiffViewState();
}

class _UnifiedDiffViewState extends State<UnifiedDiffView> {
  late DiffResult _result;

  @override
  void initState() {
    super.initState();
    _result = _computeDiff();
  }

  @override
  void didUpdateWidget(UnifiedDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldText != widget.oldText ||
        oldWidget.newText != widget.newText ||
        oldWidget.contextLines != widget.contextLines) {
      _result = _computeDiff();
    }
  }

  DiffResult _computeDiff() => calculateUnifiedDiff(
    widget.oldText,
    widget.newText,
    contextLines: widget.contextLines,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showDiffStats) _DiffStatsRow(stats: _result.stats),
          _DiffBody(result: _result, widget: widget),
        ],
      ),
    );
  }
}

/// Shared monospace style for every glyph in the diff body.
TextStyle _monoStyle({
  required double fontSize,
  Color? color,
  FontWeight? fontWeight,
  Color? backgroundColor,
  double height = AppLineHeight.normal,
}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontSize: fontSize,
    height: height,
    color: color,
    fontWeight: fontWeight,
    backgroundColor: backgroundColor,
    // Keep tabular figures so line-number gutters stay aligned.
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Expand `\t` to spaces using [tabSize]-column stops, tracking column.
///
/// Processes a single logical line (no embedded newlines expected).
String expandTabs(String input, {int tabSize = kDiffTabSize}) {
  if (!input.contains('\t')) return input;
  final sb = StringBuffer();
  var col = 0;
  for (var i = 0; i < input.length; i++) {
    final unit = input.codeUnitAt(i);
    if (unit == 0x09) {
      // TAB
      final spaces = tabSize - (col % tabSize);
      sb.write(' ' * spaces);
      col += spaces;
    } else {
      sb.writeCharCode(unit);
      // Treat other code units as width 1. Good enough for source code
      // (CJK wide glyphs are rare in diffs of typical codebases).
      col += 1;
    }
  }
  return sb.toString();
}

class _DiffStatsRow extends StatelessWidget {
  const _DiffStatsRow({required this.stats});

  final DiffStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.diffTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+${stats.additions}',
            style: _monoStyle(
              fontSize: AppFontSize.xs,
              color: colors.addedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '-${stats.deletions}',
            style: _monoStyle(
              fontSize: AppFontSize.xs,
              color: colors.removedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '(${stats.totalChanges} changes)',
            style: _monoStyle(
              fontSize: AppFontSize.xs,
              color: colors.hunkHeaderText,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffBody extends StatelessWidget {
  const _DiffBody({required this.result, required this.widget});

  final DiffResult result;
  final UnifiedDiffView widget;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: result.hunks
              .map((hunk) => _DiffHunkView(hunk: hunk, widget: widget))
              .toList(),
        ),
      ),
    );
  }
}

class _DiffHunkView extends StatelessWidget {
  const _DiffHunkView({required this.hunk, required this.widget});

  final DiffHunk hunk;
  final UnifiedDiffView widget;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HunkHeader(hunk: hunk, fontSize: widget.fontSize),
          ...hunk.lines.map(
            (line) => _DiffLineView(line: line, widget: widget),
          ),
        ],
      ),
    );
  }
}

class _HunkHeader extends StatelessWidget {
  const _HunkHeader({required this.hunk, required this.fontSize});

  final DiffHunk hunk;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.diffTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: colors.hunkHeaderBg,
      child: Text(
        '@@ -${hunk.oldStart},${hunk.oldLines}'
        ' +${hunk.newStart},${hunk.newLines} @@',
        style: _monoStyle(fontSize: fontSize, color: colors.hunkHeaderText),
      ),
    );
  }
}

class _DiffLineView extends StatelessWidget {
  const _DiffLineView({required this.line, required this.widget});

  final DiffLine line;
  final UnifiedDiffView widget;

  @override
  Widget build(BuildContext context) {
    final colors = context.diffTheme;
    final isAdded = line.type == DiffLineType.add;
    final isRemoved = line.type == DiffLineType.remove;
    final textColor = isAdded
        ? colors.addedText
        : isRemoved
        ? colors.removedText
        : colors.contextText;
    final lineBg = isAdded
        ? colors.addedBg
        : isRemoved
        ? colors.removedBg
        : null;

    return ColoredBox(
      color: lineBg ?? Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showLineNumbers)
            _LineNumber(line: line, fontSize: widget.fontSize),
          if (widget.showPlusMinusSymbols)
            _LineSymbol(
              line: line,
              color: textColor,
              fontSize: widget.fontSize,
            ),
          _LineContent(line: line, fontSize: widget.fontSize),
        ],
      ),
    );
  }
}

class _LineNumber extends StatelessWidget {
  const _LineNumber({required this.line, required this.fontSize});

  final DiffLine line;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.diffTheme;
    final isAdded = line.type == DiffLineType.add;
    final isRemoved = line.type == DiffLineType.remove;
    final number = isRemoved
        ? line.oldLineNumber
        : isAdded
        ? line.newLineNumber
        : line.oldLineNumber;
    final bgColor = isAdded
        ? colors.addedBg
        : isRemoved
        ? colors.removedBg
        : colors.lineNumberBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      color: bgColor,
      // Fixed-ish width so multi-digit line numbers don't jostle content.
      constraints: const BoxConstraints(minWidth: 40),
      child: Text(
        (number ?? '').toString().padLeft(3, ' '),
        style: _monoStyle(fontSize: fontSize, color: colors.lineNumberText),
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _LineSymbol extends StatelessWidget {
  const _LineSymbol({
    required this.line,
    required this.color,
    required this.fontSize,
  });

  final DiffLine line;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final symbol = line.type == DiffLineType.add
        ? '+'
        : line.type == DiffLineType.remove
        ? '-'
        : ' ';

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Text(
        symbol,
        style: _monoStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LineContent extends StatelessWidget {
  const _LineContent({required this.line, required this.fontSize});

  final DiffLine line;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.diffTheme;
    final isAdded = line.type == DiffLineType.add;
    final isRemoved = line.type == DiffLineType.remove;
    final textColor = isAdded
        ? colors.addedText
        : isRemoved
        ? colors.removedText
        : colors.contextText;

    if (line.tokens != null && line.tokens!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: _TokenizedContent(
          tokens: line.tokens!,
          fontSize: fontSize,
          baseColor: textColor,
        ),
      );
    }

    final expanded = expandTabs(line.content.trimRight());
    final spans = _leadingSpaceSpans(
      expanded,
      fontSize: fontSize,
      textColor: textColor,
      leadingDotColor: colors.leadingSpaceDot,
    );

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: RichText(text: TextSpan(children: spans)),
    );
  }
}

/// Build spans for a (tab-expanded) line, rendering leading spaces as mid-dots.
List<InlineSpan> _leadingSpaceSpans(
  String content, {
  required double fontSize,
  required Color textColor,
  required Color leadingDotColor,
}) {
  final leadingMatch = RegExp(r'^ +').matchAsPrefix(content);
  final leadingSpaces = leadingMatch?.group(0)?.length ?? 0;
  final leadingDots = '·' * leadingSpaces;
  final mainContent = leadingSpaces > 0
      ? content.substring(leadingSpaces)
      : content;

  return [
    if (leadingDots.isNotEmpty)
      TextSpan(
        text: leadingDots,
        // MUST share monospace + size with body so indentation columns
        // align with the rest of the line.
        style: _monoStyle(fontSize: fontSize, color: leadingDotColor),
      ),
    TextSpan(
      text: mainContent.isEmpty ? ' ' : mainContent,
      style: _monoStyle(fontSize: fontSize, color: textColor),
    ),
  ];
}

class _TokenizedContent extends StatelessWidget {
  const _TokenizedContent({
    required this.tokens,
    required this.fontSize,
    required this.baseColor,
  });

  final List<DiffToken> tokens;
  final double fontSize;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.diffTheme;

    // Expand tabs across tokens while tracking column so mid-line tabs
    // still land on the correct stop.
    final spans = <InlineSpan>[];
    var col = 0;
    var leadingDone = false;

    for (final token in tokens) {
      final expanded = _expandTabsFromColumn(token.value, col);
      col += expanded.length;

      // First token(s) may be pure leading whitespace — paint as mid-dots
      // until we hit non-space content so indentation stays visible.
      var paintText = expanded;
      var paintColor = baseColor;
      Color? bg;

      if (!leadingDone) {
        final lead = RegExp(r'^ +').matchAsPrefix(expanded);
        if (lead != null) {
          final n = lead.group(0)!.length;
          final dots = '·' * n;
          final rest = expanded.substring(n);
          if (rest.isEmpty) {
            paintText = dots;
            paintColor = colors.leadingSpaceDot;
          } else {
            // Split: dots + rest as two spans.
            spans.add(
              TextSpan(
                text: dots,
                style: _monoStyle(
                  fontSize: fontSize,
                  color: colors.leadingSpaceDot,
                ),
              ),
            );
            paintText = rest;
            leadingDone = true;
          }
        } else if (expanded.isNotEmpty) {
          leadingDone = true;
        }
      }

      if (token.added) {
        bg = colors.inlineAddedBg;
        paintColor = colors.inlineAddedText;
      } else if (token.removed) {
        bg = colors.inlineRemovedBg;
        paintColor = colors.inlineRemovedText;
      }

      if (paintText.isEmpty) continue;

      spans.add(
        TextSpan(
          text: paintText,
          style: _monoStyle(
            fontSize: fontSize,
            color: paintColor,
            backgroundColor: bg,
          ),
        ),
      );
    }

    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: ' ',
          style: _monoStyle(fontSize: fontSize, color: baseColor),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Expand tabs in [input] starting at column [startCol].
  static String _expandTabsFromColumn(String input, int startCol) {
    if (!input.contains('\t')) return input;
    final sb = StringBuffer();
    var col = startCol;
    for (var i = 0; i < input.length; i++) {
      final unit = input.codeUnitAt(i);
      if (unit == 0x09) {
        final spaces = kDiffTabSize - (col % kDiffTabSize);
        sb.write(' ' * spaces);
        col += spaces;
      } else {
        sb.writeCharCode(unit);
        col += 1;
      }
    }
    return sb.toString();
  }
}
