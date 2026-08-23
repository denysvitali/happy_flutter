import 'package:flutter/material.dart';

import '../../../../core/components/tool_view_buttons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/ansi_parser.dart';
import '../../../../core/utils/ansi_span_cache.dart';

/// Boxed `stdout` / `stderr` / `error` section used by every shell-style tool
/// view (Claude `Bash`, Codex `bash`, Gemini `execute`, MCP exec).
///
/// Extracted so all agents render command output identically; the views used
/// to carry near-identical private copies that drifted apart.
class TerminalOutputSection extends StatefulWidget {
  /// Creates a [TerminalOutputSection].
  const TerminalOutputSection({
    required this.label,
    required this.output,
    required this.isError,
    super.key,
    this.maxLines = 20,
  });

  /// Section label — `stdout`, `stderr` or `error`.
  final String label;

  /// Raw output text, may contain ANSI escapes.
  final String output;

  /// Whether to render with error colors and an error icon.
  final bool isError;

  /// Lines shown before the "show more" toggle kicks in.
  final int maxLines;

  @override
  State<TerminalOutputSection> createState() => _TerminalOutputSectionState();
}

class _TerminalOutputSectionState extends State<TerminalOutputSection> {
  bool _expanded = false;
  late int _totalLines;
  late bool _needsTruncation;
  late String _visibleText;
  List<TextSpan> _parsedSpans = const [];
  // Track the style used to build _parsedSpans so we can avoid re-parsing
  // when only unrelated parts of the tree rebuild.
  TextStyle? _lastDefaultStyle;
  // Full output with ANSI escapes stripped, for the copy button. Stripping
  // is a regex sweep over the whole output; recompute only when the output
  // actually changes, not on every build while the tool view streams.
  late String _strippedOutput;

  void _recomputeVisibleText() {
    final lines = widget.output.split('\n');
    _totalLines = lines.length;
    _needsTruncation = _totalLines > widget.maxLines;
    final visibleLines = _expanded || !_needsTruncation
        ? lines
        : lines.take(widget.maxLines).toList();
    _visibleText = visibleLines.join('\n');
    _lastDefaultStyle = null;
    _strippedOutput = AnsiParser.strip(widget.output);
  }

  @override
  void initState() {
    super.initState();
    _recomputeVisibleText();
  }

  @override
  void didUpdateWidget(TerminalOutputSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.output != widget.output ||
        oldWidget.maxLines != widget.maxLines) {
      _recomputeVisibleText();
    } else if (oldWidget.isError != widget.isError) {
      // visibleText is unchanged but the default text color differs.
      _lastDefaultStyle = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isError = widget.isError;

    final defaultStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier New', 'Courier'],
      fontSize: AppFontSize.sm,
      color: isError ? AppColors.error : cs.onSurface,
      height: AppLineHeight.relaxed,
    );
    if (_lastDefaultStyle != defaultStyle) {
      // Memoized: while a session streams, every output tick invalidates
      // the local guard and re-parses the whole visible window; identical
      // (visible text, style) pairs now reuse cached spans instead.
      _parsedSpans = AnsiSpanCache.instance.parse(
        _visibleText,
        defaultStyle: defaultStyle,
      );
      _lastDefaultStyle = defaultStyle;
    }

    final labelColor = isError ? AppColors.error : cs.onSurfaceVariant;
    final borderColor = isError ? AppColors.error : cs.outlineVariant;
    final bgColor = isError ? cs.errorContainer : cs.surface;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xsm),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smd,
              vertical: AppSpacing.xxs2,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.sm),
                topRight: Radius.circular(AppRadius.sm),
              ),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                if (isError)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xxs2),
                    child: Icon(
                      Icons.error_outline,
                      size: AppIconSize.xs,
                      color: AppColors.error,
                    ),
                  ),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.xs,
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_totalLines line${_totalLines == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: AppFontSize.xxs,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ToolViewCopyButton(text: _strippedOutput, iconSize: 13),
              ],
            ),
          ),
          // Output text
          Padding(
            padding: const EdgeInsets.all(AppSpacing.smd),
            child: SelectableText.rich(
              TextSpan(children: _parsedSpans),
              style: defaultStyle,
            ),
          ),
          // Show more / show less button
          if (_needsTruncation)
            ToolViewShowMoreButton(
              expanded: _expanded,
              hiddenCount: _totalLines - widget.maxLines,
              onToggle: () => setState(() {
                _expanded = !_expanded;
                _recomputeVisibleText();
              }),
            ),
        ],
      ),
    );
  }
}
