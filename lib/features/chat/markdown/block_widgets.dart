/// Block widgets for rendering markdown content.
///
/// Provides individual widget components for each markdown block type
/// with support for text selection and proper styling.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../syntax_highlighter.dart';
import 'markdown_models.dart';

/// A widget that displays text with inline formatting.
///
/// Supports bold, italic, semibold, and inline code styles.
/// Text is selectable for copying on long-press.
class TextBlockWidget extends StatefulWidget {
  const TextBlockWidget({
    required this.content,
    super.key,
    this.isFirst = false,
    this.isLast = false,
  });
  final List<MarkdownSpan> content;
  final bool isFirst;
  final bool isLast;

  @override
  State<TextBlockWidget> createState() => _TextBlockWidgetState();
}

class _TextBlockWidgetState extends State<TextBlockWidget> {
  final List<TapGestureRecognizer> _recognizers = [];
  Color _inlineCodeBg = const Color(0x1F000000);
  List<InlineSpan>? _cachedSpans;
  Object? _lastContent;

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void didUpdateWidget(TextBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _disposeRecognizers();
      _cachedSpans = null;
      _lastContent = null;
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    _inlineCodeBg = cs.primary.withValues(alpha: 0.1);
    final inheritedColor = DefaultTextStyle.of(context).style.color;
    final baseStyle = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        fontSize: 14,
        height: 1.45,
        color: inheritedColor ?? cs.onSurface,
      ),
    );

    if (_lastContent != widget.content) {
      _lastContent = widget.content;
      _cachedSpans = widget.content
          .map(_buildSpan)
          .toList(growable: false);
    }

    return RepaintBoundary(
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: _cachedSpans ?? [],
        ),
      ),
    );
  }

  InlineSpan _buildSpan(MarkdownSpan span) {
    final textStyle = TextStyle(
      decoration: span.url != null ? TextDecoration.underline : null,
      fontStyle: span.styles.contains(MarkdownTextStyle.italic)
          ? FontStyle.italic
          : null,
      fontWeight: span.styles.contains(MarkdownTextStyle.bold)
          ? FontWeight.bold
          : span.styles.contains(MarkdownTextStyle.semibold)
          ? FontWeight.w600
          : null,
      fontFamily: span.styles.contains(MarkdownTextStyle.code)
          ? 'monospace'
          : null,
      backgroundColor: span.styles.contains(MarkdownTextStyle.code)
          ? _inlineCodeBg
          : null,
      color: span.styles.contains(MarkdownTextStyle.code)
          ? Colors.pink.shade300
          : (span.url != null ? Colors.blue : null),
    );

    if (span.url != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: InlineLinkWidget(
          text: span.text,
          url: span.url!,
          baseStyle: textStyle,
        ),
      );
    }

    return TextSpan(text: span.text, style: textStyle);
  }
}

/// A widget that displays a header with the appropriate styling.
///
/// Headers are rendered with decreasing font sizes from H1 to H6.
class HeaderBlockWidget extends StatefulWidget {
  const HeaderBlockWidget({
    required this.level,
    required this.content,
    super.key,
    this.isFirst = false,
    this.isLast = false,
  });
  final int level;
  final List<MarkdownSpan> content;
  final bool isFirst;
  final bool isLast;

  @override
  State<HeaderBlockWidget> createState() => _HeaderBlockWidgetState();
}

class _HeaderBlockWidgetState extends State<HeaderBlockWidget> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<InlineSpan>? _cachedSpans;
  Object? _lastContent;

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void didUpdateWidget(HeaderBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _disposeRecognizers();
      _cachedSpans = null;
      _lastContent = null;
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = DefaultTextStyle.of(context).style;

    final fontSize = switch (widget.level) {
      1 => 20,
      2 => 18,
      3 => 16,
      4 => 15,
      _ => 15,
    };

    final fontWeight = switch (widget.level) {
      1 => FontWeight.w700,
      2 || 3 => FontWeight.w600,
      _ => FontWeight.w600,
    };

    final inheritedColor = DefaultTextStyle.of(context).style.color;

    if (_lastContent != widget.content) {
      _lastContent = widget.content;
      _cachedSpans = widget.content
          .map(_buildSpan)
          .toList(growable: false);
    }

    return Text.rich(
      TextSpan(
        style: baseStyle.copyWith(
          fontSize: fontSize.toDouble(),
          fontWeight: fontWeight,
          height: 1.3,
          color: inheritedColor ?? theme.colorScheme.onSurface,
        ),
        children: _cachedSpans ?? [],
      ),
    );
  }

  InlineSpan _buildSpan(MarkdownSpan span) {
    final textStyle = TextStyle(
      color: span.url != null ? Colors.blue : null,
      decoration: span.url != null ? TextDecoration.underline : null,
    );

    if (span.url != null) {
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: InlineLinkWidget(
          text: span.text,
          url: span.url!,
          baseStyle: textStyle,
        ),
      );
    }

    return TextSpan(text: span.text, style: textStyle);
  }
}

/// A widget that displays an unordered (bulleted) list.
class ListBlockWidget extends StatefulWidget {
  const ListBlockWidget({
    required this.items,
    super.key,
    this.isFirst = false,
    this.isLast = false,
  });
  final List<List<MarkdownSpan>> items;
  final bool isFirst;
  final bool isLast;

  @override
  State<ListBlockWidget> createState() => _ListBlockWidgetState();
}

class _ListBlockWidgetState extends State<ListBlockWidget> {
  Color _inlineCodeBg = const Color(0x1F000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    _inlineCodeBg = cs.primary.withValues(alpha: 0.1);
    final inheritedColor = DefaultTextStyle.of(context).style.color;
    final textColor = inheritedColor ?? cs.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.items.map((item) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                '•',
                style: TextStyle(fontSize: 14, height: 1.45, color: textColor),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: DefaultTextStyle.of(context).style.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    color: textColor,
                  ),
                  children: item.map(_buildSpan).toList(),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  InlineSpan _buildSpan(MarkdownSpan span) {
    return TextSpan(
      text: span.text,
      style: TextStyle(
        fontStyle: span.styles.contains(MarkdownTextStyle.italic)
            ? FontStyle.italic
            : null,
        fontWeight: span.styles.contains(MarkdownTextStyle.bold)
            ? FontWeight.bold
            : null,
        fontFamily: span.styles.contains(MarkdownTextStyle.code)
            ? 'monospace'
            : null,
        backgroundColor: span.styles.contains(MarkdownTextStyle.code)
            ? _inlineCodeBg
            : null,
        color: span.styles.contains(MarkdownTextStyle.code)
            ? Colors.pink.shade300
            : null,
      ),
    );
  }
}

/// A widget that displays a numbered list.
class NumberedListBlockWidget extends StatefulWidget {
  const NumberedListBlockWidget({
    required this.items,
    super.key,
    this.isFirst = false,
    this.isLast = false,
  });
  final List<NumberedItem> items;
  final bool isFirst;
  final bool isLast;

  @override
  State<NumberedListBlockWidget> createState() =>
      _NumberedListBlockWidgetState();
}

class _NumberedListBlockWidgetState extends State<NumberedListBlockWidget> {
  Color _inlineCodeBg = const Color(0x1F000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    _inlineCodeBg = cs.primary.withValues(alpha: 0.1);
    final inheritedColor = DefaultTextStyle.of(context).style.color;
    final textColor = inheritedColor ?? cs.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.items.map((item) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                '${item.number}.',
                style: TextStyle(fontSize: 15, height: 1.45, color: textColor),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: DefaultTextStyle.of(context).style.copyWith(
                    fontSize: 15,
                    height: 1.45,
                    color: textColor,
                  ),
                  children: item.spans.map(_buildSpan).toList(),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  InlineSpan _buildSpan(MarkdownSpan span) {
    return TextSpan(
      text: span.text,
      style: TextStyle(
        fontStyle: span.styles.contains(MarkdownTextStyle.italic)
            ? FontStyle.italic
            : null,
        fontWeight: span.styles.contains(MarkdownTextStyle.bold)
            ? FontWeight.bold
            : null,
        fontFamily: span.styles.contains(MarkdownTextStyle.code)
            ? 'monospace'
            : null,
        backgroundColor: span.styles.contains(MarkdownTextStyle.code)
            ? _inlineCodeBg
            : null,
        color: span.styles.contains(MarkdownTextStyle.code)
            ? Colors.pink.shade300
            : null,
      ),
    );
  }
}

/// A widget that displays a code block with optional syntax highlighting.
///
/// Features:
/// - Syntax highlighting with language detection
/// - 5-color bracket nesting for depth visualization
/// - Hover-to-reveal copy button
/// - Language badge display
/// - Text selection support
class CodeBlockWidget extends StatefulWidget {
  const CodeBlockWidget({
    required this.content,
    super.key,
    this.language,
    this.isFirst = false,
    this.isLast = false,
  });
  final String content;
  final String? language;
  final bool isFirst;
  final bool isLast;

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  bool _showCopyButton = false;
  bool _copied = false;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = _isDarkMode
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF8F8F8);
    final borderColor = _isDarkMode
        ? const Color(0xFF303030)
        : const Color(0xFFE0E0E0);
    final headerBackground = _isDarkMode
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFF0F0F0);

    final detectedLanguage = detectLanguage(widget.language);

    return MouseRegion(
      onEnter: (_) => setState(() => _showCopyButton = true),
      onExit: (_) => setState(() => _showCopyButton = false),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with language badge and copy button
            if (widget.language != null || _showCopyButton)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: headerBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Language badge
                    if (widget.language != null)
                      _buildLanguageBadge(theme, detectedLanguage),
                    const Spacer(),
                    // Copy button (hover-to-reveal)
                    AnimatedOpacity(
                      opacity: _showCopyButton ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: _buildCopyButton(theme),
                    ),
                  ],
                ),
              ),
            // Code content with syntax highlighting
            Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SyntaxHighlighter(
                  code: widget.content,
                  language: detectedLanguage,
                  isDarkMode: _isDarkMode,
                  fontSize: 14,
                  lineHeight: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageBadge(ThemeData theme, String? detectedLanguage) {
    final badgeColor = _isDarkMode
        ? const Color(0xFF38383A)
        : const Color(0xFFE5E5EA);
    final textColor = _isDarkMode
        ? const Color(0xFF8E8E93)
        : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        (detectedLanguage ?? widget.language!).toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCopyButton(ThemeData theme) {
    final iconColor = _isDarkMode
        ? const Color(0xFFCAC4D0)
        : const Color(0xFF49454F);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _copyToClipboard,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check : Icons.content_copy,
                size: 14,
                color: iconColor,
              ),
              if (_copied)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Copied',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: iconColor,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }
}

/// A widget that displays a horizontal rule separator.
class HorizontalRuleBlockWidget extends StatelessWidget {
  const HorizontalRuleBlockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 1,
      color: theme.colorScheme.outlineVariant,
    );
  }
}

/// A widget that displays an options block for interactive choices.
class OptionsBlockWidget extends StatelessWidget {
  const OptionsBlockWidget({
    required this.items,
    super.key,
    this.isFirst = false,
    this.isLast = false,
    this.onOptionPress,
  });
  final List<String> items;
  final bool isFirst;
  final bool isLast;
  final void Function(String option)? onOptionPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final child = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            item,
            style: TextStyle(
              fontSize: 14,
              color: onOptionPress != null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        );

        if (onOptionPress != null) {
          return Material(
            color: Colors.transparent,
            elevation: 1,
            shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(100),
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: () => onOptionPress!(item),
              child: child,
            ),
          );
        }

        return child;
      }).toList(),
    );
  }
}

/// A widget that displays a table with headers and data rows.
class TableBlockWidget extends StatelessWidget {
  const TableBlockWidget({
    required this.headers,
    required this.rows,
    super.key,
    this.isFirst = false,
    this.isLast = false,
  });
  final List<String> headers;
  final List<List<String>> rows;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inheritedColor = DefaultTextStyle.of(context).style.color;
    final columnCount = headers.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Distribute columns evenly across available width; min 72px each.
        final available = constraints.maxWidth;
        final colWidth = columnCount > 0
            ? (available / columnCount).clamp(72.0, double.infinity)
            : available;
        final tableWidth = colWidth * columnCount;

        final tableContent = Container(
          width: tableWidth,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(7),
                    topRight: Radius.circular(7),
                  ),
                ),
                child: Row(
                  children: headers.map((header) {
                    return SizedBox(
                      width: colWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          header,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Data rows
              ...rows.asMap().entries.map((entry) {
                final rowIndex = entry.key;
                final row = entry.value;
                final isLastRow = rowIndex == rows.length - 1;

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: isLastRow
                          ? BorderSide.none
                          : BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: headers.asMap().entries.map((cellEntry) {
                      final cellIndex = cellEntry.key;
                      final cellText = row.length > cellIndex
                          ? row[cellIndex]
                          : '';

                      return SizedBox(
                        width: colWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Text(
                            cellText,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color:
                                  inheritedColor ?? theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          ),
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: tableContent,
        );
      },
    );
  }
}

/// An inline link rendered as a [WidgetSpan] to avoid gesture conflicts.
///
/// Using [WidgetSpan] instead of [TextSpan.recognizer] prevents the link's
/// [TapGestureRecognizer] from competing with [SelectionArea]'s long-press
/// recognizer in the gesture arena. This ensures text selection works
/// correctly and link taps are not suppressed.
class InlineLinkWidget extends StatelessWidget {
  const InlineLinkWidget({
    required this.text,
    required this.url,
    required this.baseStyle,
    super.key,
  });

  final String text;
  final String url;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _launchUrl(url),
      child: Text(
        text,
        style: baseStyle.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
          decorationColor: Colors.blue,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
