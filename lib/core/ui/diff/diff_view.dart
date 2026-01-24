import 'package:flutter/material.dart';
import 'diff_types.dart';
import 'calculate_diff.dart';

/// Diff view widget for displaying code differences
class DiffView extends StatefulWidget {
  final String oldText;
  final String newText;
  final DiffViewConfig config;
  final String? oldTitle;
  final String? newTitle;

  const DiffView({
    required this.oldText,
    required this.newText,
    this.config = const DiffViewConfig(),
    this.oldTitle,
    this.newTitle,
    super.key,
  });

  @override
  State<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> {
  late final DiffResult _diffResult;

  @override
  void initState() {
    super.initState();
    _diffResult = calculateUnifiedDiff(
      widget.oldText,
      widget.newText,
      contextLines: widget.config.contextLines,
    );
  }

  @override
  void didUpdateWidget(DiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oldText != widget.oldText ||
        oldWidget.newText != widget.newText) {
      _diffResult = calculateUnifiedDiff(
        widget.oldText,
        widget.newText,
        contextLines: widget.config.contextLines,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = widget.config.theme;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.config.showDiffStats) _buildStatsHeader(theme),
          Expanded(child: _buildDiffContent(theme)),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(ThemeData theme) {
    final colors = widget.config.theme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (widget.oldTitle != null || widget.newTitle != null) ...[
            Text(
              '${widget.oldTitle ?? 'Old'} -> ${widget.newTitle ?? 'New'}',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
          ],
          if (_diffResult.stats.additions > 0)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                '+${_diffResult.stats.additions}',
                style: TextStyle(
                  color: colors.addedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (_diffResult.stats.deletions > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '-${_diffResult.stats.deletions}',
                style: TextStyle(
                  color: colors.removedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiffContent(ThemeData theme) {
    final colors = widget.config.theme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _diffResult.hunks.map((hunk) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHunkHeader(hunk, theme, colors),
                ...hunk.lines.map((line) => _buildLine(line, theme, colors)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHunkHeader(DiffHunk hunk, ThemeData theme, DiffTheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.hunkHeaderBg,
      child: Text(
        '@@ -${hunk.oldStart},${hunk.oldLines} +${hunk.newStart},${hunk.newLines} @@',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.hunkHeaderText,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLine(DiffLine line, ThemeData theme, DiffTheme colors) {
    final isAdded = line.type == DiffLineType.add;
    final isRemoved = line.type == DiffLineType.remove;
    final textColor = isAdded
        ? colors.addedText
        : isRemoved
            ? colors.removedText
            : colors.contextText;
    final bgColor = isAdded
        ? colors.addedBg
        : isRemoved
            ? colors.removedBg
            : colors.contextBg;

    return IntrinsicWidth(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.config.showLineNumbers)
            _buildLineNumber(line, theme, colors),
          if (widget.config.showPlusMinusSymbols)
            _buildSymbol(line, textColor),
          Expanded(child: _buildContent(line, theme, colors)),
        ],
      ),
    );
  }

  Widget _buildLineNumber(DiffLine line, ThemeData theme, DiffTheme colors) {
    final number = line.type == DiffLineType.remove
        ? line.oldLineNumber
        : line.type == DiffLineType.add
            ? line.newLineNumber
            : line.oldLineNumber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: colors.lineNumberBg,
      constraints: const BoxConstraints(minWidth: 50),
      child: Text(
        (number ?? '').toString().padStart(3),
        style: TextStyle(
          color: colors.lineNumberText,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildSymbol(DiffLine line, Color color) {
    final symbol = line.type == DiffLineType.add
        ? '+'
        : line.type == DiffLineType.remove
            ? '-'
            : ' ';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        symbol,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildContent(DiffLine line, ThemeData theme, DiffTheme colors) {
    final formatted = _formatLineContent(line.content);

    if (line.tokens != null && line.tokens!.isNotEmpty) {
      return _buildTokenizedContent(line.tokens!, colors);
    }

    // Regular rendering
    final leadingSpaces = formatted.matchAsPrefix(' ');
    final leadingDots = leadingSpaces != null
        ? '\u00b7' * leadingSpaces.group(0)!.length
        : '';
    final mainContent =
        leadingSpaces != null ? formatted.substring(leadingSpaces.group(0)!.length) : formatted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: line.type == DiffLineType.normal ? null : null,
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
                color: line.type == DiffLineType.add
                    ? colors.addedText
                    : line.type == DiffLineType.remove
                        ? colors.removedText
                        : colors.contextText,
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenizedContent(List<DiffToken> tokens, DiffTheme colors) {
    final spans = <InlineSpan>[];

    for (final token in tokens) {
      final style = TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.5,
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
      );

      spans.add(TextSpan(text: token.value, style: style));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: RichText(
        text: TextSpan(children: spans),
      ),
    );
  }

  String _formatLineContent(String content) {
    return content.trimEnd();
  }
}

/// Simplified inline diff viewer
class InlineDiffView extends StatelessWidget {
  final String oldText;
  final String newText;
  final DiffTheme theme;
  final TextStyle? textStyle;

  const InlineDiffView({
    required this.oldText,
    required this.newText,
    this.theme = const DiffTheme(),
    this.textStyle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final result = calculateUnifiedDiff(oldText, newText);
    final tokens = _getAllTokens(result);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: RichText(
        text: TextSpan(
          children: tokens.map((token) {
            return TextSpan(
              text: token.value,
              style: (textStyle ?? const TextStyle()).copyWith(
                backgroundColor: token.added
                    ? theme.inlineAddedBg
                    : token.removed
                        ? theme.inlineRemovedBg
                        : null,
                color: token.added
                    ? theme.inlineAddedText
                    : token.removed
                        ? theme.inlineRemovedText
                        : null,
                fontFamily: 'monospace',
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<DiffToken> _getAllTokens(DiffResult result) {
    final tokens = <DiffToken>[];

    for (final hunk in result.hunks) {
      for (final line in hunk.lines) {
        if (line.tokens != null) {
          tokens.addAll(line.tokens!);
        } else {
          tokens.add(DiffToken(value: line.content));
        }
      }
    }

    return tokens;
  }
}

/// Diff stats widget
class DiffStatsView extends StatelessWidget {
  final DiffStats stats;
  final DiffTheme theme;
  final bool showTotal;

  const DiffStatsView({
    required this.stats,
    this.theme = const DiffTheme(),
    this.showTotal = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '+${stats.additions}',
          style: TextStyle(
            color: theme.addedText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '-${stats.deletions}',
          style: TextStyle(
            color: theme.removedText,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (showTotal) ...[
          const SizedBox(width: 8),
          Text(
            '(${stats.totalChanges} changes)',
            style: TextStyle(
              color: theme.hunkHeaderText,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
