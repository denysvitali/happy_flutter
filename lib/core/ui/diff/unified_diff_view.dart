import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../theme/diff_theme.dart';
import 'calculate_diff.dart';
import 'diff_types.dart';

/// Canonical unified-diff body used by every diff-rendering tool view.
///
/// This is the single implementation that turns [oldText] / [newText] into
/// hunk headers, line numbers, +/- symbols, and inline word-level change
/// highlights. It resolves its palette from the ambient [DiffTheme]
/// ThemeExtension (see [context.diffTheme]); there is no legacy color
/// translation layer.
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
    this.fontSize = AppFontSize.md,
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

  /// Font size for diff content.
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

class _DiffStatsRow extends StatelessWidget {
  const _DiffStatsRow({required this.stats});

  final DiffStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.diffTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+${stats.additions}',
            style: TextStyle(
              color: colors.addedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '-${stats.deletions}',
            style: TextStyle(
              color: colors.removedText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '(${stats.totalChanges} changes)',
            style: TextStyle(
              color: colors.hunkHeaderText,
              fontSize: AppFontSize.sm,
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
        padding: const EdgeInsets.all(AppSpacing.sm),
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
          _HunkHeader(hunk: hunk),
          ...hunk.lines.map(
            (line) => _DiffLineView(line: line, widget: widget),
          ),
        ],
      ),
    );
  }
}

class _HunkHeader extends StatelessWidget {
  const _HunkHeader({required this.hunk});

  final DiffHunk hunk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.diffTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: colors.hunkHeaderBg,
      child: Text(
        '@@ -${hunk.oldStart},${hunk.oldLines}'
        ' +${hunk.newStart},${hunk.newLines} @@',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.hunkHeaderText,
          fontFamily: 'monospace',
          fontSize: AppFontSize.sm,
        ),
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLineNumbers) _LineNumber(line: line),
        if (widget.showPlusMinusSymbols)
          _LineSymbol(line: line, color: textColor),
        _LineContent(line: line, fontSize: widget.fontSize),
      ],
    );
  }
}

class _LineNumber extends StatelessWidget {
  const _LineNumber({required this.line});

  final DiffLine line;

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
      constraints: const BoxConstraints(minWidth: 50),
      child: Text(
        (number ?? '').toString().padLeft(3, ' '),
        style: TextStyle(
          color: colors.lineNumberText,
          fontFamily: 'monospace',
          fontSize: AppFontSize.md,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }
}

class _LineSymbol extends StatelessWidget {
  const _LineSymbol({required this.line, required this.color});

  final DiffLine line;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final symbol = line.type == DiffLineType.add
        ? '+'
        : line.type == DiffLineType.remove
            ? '-'
            : ' ';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(
        symbol,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontSize: AppFontSize.md,
          fontWeight: FontWeight.bold,
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
    final lineBg = isAdded
        ? colors.addedBg
        : isRemoved
            ? colors.removedBg
            : null;

    if (line.tokens != null && line.tokens!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        color: lineBg,
        child: _TokenizedContent(tokens: line.tokens!),
      );
    }

    final content = line.content.trimRight();
    final leadingMatch = RegExp(r'^ +').matchAsPrefix(content);
    final leadingSpaces = leadingMatch?.group(0)?.length ?? 0;
    final leadingDots = '·' * leadingSpaces;
    final mainContent = leadingSpaces > 0
        ? content.substring(leadingSpaces)
        : content;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      color: lineBg,
      child: RichText(
        text: TextSpan(
          children: [
            if (leadingDots.isNotEmpty)
              TextSpan(
                text: leadingDots,
                style: TextStyle(color: colors.leadingSpaceDot),
              ),
            TextSpan(
              text: mainContent,
              style: TextStyle(
                color: isAdded
                    ? colors.addedText
                    : isRemoved
                        ? colors.removedText
                        : colors.contextText,
                fontFamily: 'monospace',
                fontSize: fontSize,
                height: AppLineHeight.relaxed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenizedContent extends StatelessWidget {
  const _TokenizedContent({required this.tokens});

  final List<DiffToken> tokens;

  @override
  Widget build(BuildContext context) {
    final colors = context.diffTheme;

    return RichText(
      text: TextSpan(
        children: tokens.map((token) {
          return TextSpan(
            text: token.value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: AppFontSize.md,
              height: AppLineHeight.relaxed,
              backgroundColor: token.added
                  ? colors.inlineAddedBg
                  : token.removed
                      ? colors.inlineRemovedBg
                      : null,
              color: token.added
                  ? colors.inlineAddedText
                  : token.removed
                      ? colors.inlineRemovedText
                      : colors.contextText,
            ),
          );
        }).toList(),
      ),
    );
  }
}
