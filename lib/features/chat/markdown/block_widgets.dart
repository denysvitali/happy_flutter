/// Block widgets for rendering markdown content.
///
/// Provides individual widget components for each markdown block type
/// with support for text selection and proper styling.
library;

import 'package:flutter/material.dart';
import 'markdown_models.dart';

/// A widget that displays text with inline formatting.
///
/// Supports bold, italic, semibold, and inline code styles.
/// Text is selectable for copying on long-press.
class TextBlockWidget extends StatelessWidget {
  final List<MarkdownSpan> content;
  final bool isFirst;
  final bool isLast;

  const TextBlockWidget({
    super.key,
    required this.content,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            fontSize: 16,
            height: 1.5,
            color: theme.colorScheme.onSurface,
          ),
        );

    return SelectionArea(
      child: RichText(
        text: TextSpan(
          style: baseStyle,
          children: content.map(_buildSpan).toList(),
        ),
      ),
    );
  }

  Widget _buildSpan(MarkdownSpan span) {
    final style = <InlineSpan>[];
    final textStyle = TextStyle(
      color: span.url != null ? Colors.blue : null,
      decoration: span.url != null ? TextDecoration.underline : null,
      fontStyle: span.styles.contains(TextStyle.italic)
          ? FontStyle.italic
          : null,
      fontWeight: span.styles.contains(TextStyle.bold)
          ? FontWeight.bold
          : span.styles.contains(TextStyle.semibold)
              ? FontWeight.w600
              : null,
      fontFamily: span.styles.contains(TextStyle.code) ? 'monospace' : null,
      backgroundColor: span.styles.contains(TextStyle.code)
          ? Colors.black12
          : null,
    );

    if (span.url != null) {
      return TextSpan(
        text: span.text,
        style: textStyle,
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(span.url!),
      );
    }

    return TextSpan(text: span.text, style: textStyle);
  }

  void _launchUrl(String url) {
    // URL launching is handled by the parent widget via callback
  }
}

/// A widget that displays a header with the appropriate styling.
///
/// Headers are rendered with decreasing font sizes from H1 to H6.
class HeaderBlockWidget extends StatelessWidget {
  final int level;
  final List<MarkdownSpan> content;
  final bool isFirst;
  final bool isLast;

  const HeaderBlockWidget({
    super.key,
    required this.level,
    required this.content,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = DefaultTextStyle.of(context).style;

    final fontSize = switch (level) {
      1 => 28,
      2 => 24,
      3 => 20,
      4 => 18,
      _ => 16,
    };

    final fontWeight = switch (level) {
      1 => FontWeight.w900,
      2 || 3 => FontWeight.w600,
      _ => FontWeight.w600,
    };

    return SelectionArea(
      child: RichText(
        text: TextSpan(
          style: baseStyle.copyWith(
            fontSize: fontSize.toDouble(),
            fontWeight: fontWeight,
            height: 1.3,
            color: theme.colorScheme.onSurface,
          ),
          children: content.map(_buildSpan).toList(),
        ),
      ),
    );
  }

  Widget _buildSpan(MarkdownSpan span) {
    final textStyle = TextStyle(
      color: span.url != null ? Colors.blue : null,
      decoration: span.url != null ? TextDecoration.underline : null,
    );

    if (span.url != null) {
      return TextSpan(
        text: span.text,
        style: textStyle,
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(span.url!),
      );
    }

    return TextSpan(text: span.text, style: textStyle);
  }

  void _launchUrl(String url) {
    // URL launching is handled by the parent widget via callback
  }
}

/// A widget that displays an unordered (bulleted) list.
class ListBlockWidget extends StatelessWidget {
  final List<List<MarkdownSpan>> items;
  final bool isFirst;
  final bool isLast;

  const ListBlockWidget({
    super.key,
    required this.items,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                '•',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Expanded(
              child: SelectionArea(
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style.copyWith(
                          fontSize: 16,
                          height: 1.5,
                          color: theme.colorScheme.onSurface,
                        ),
                    children: item.map(_buildSpan).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSpan(MarkdownSpan span) {
    return TextSpan(
      text: span.text,
      style: TextStyle(
        fontStyle: span.styles.contains(TextStyle.italic)
            ? FontStyle.italic
            : null,
        fontWeight: span.styles.contains(TextStyle.bold)
            ? FontWeight.bold
            : null,
        fontFamily: span.styles.contains(TextStyle.code) ? 'monospace' : null,
        backgroundColor: span.styles.contains(TextStyle.code)
            ? Colors.black12
            : null,
      ),
    );
  }
}

/// A widget that displays a numbered list.
class NumberedListBlockWidget extends StatelessWidget {
  final List<NumberedItem> items;
  final bool isFirst;
  final bool isLast;

  const NumberedListBlockWidget({
    super.key,
    required this.items,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                '${item.number}.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Expanded(
              child: SelectionArea(
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style.copyWith(
                          fontSize: 16,
                          height: 1.5,
                          color: theme.colorScheme.onSurface,
                        ),
                    children: item.spans.map(_buildSpan).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSpan(MarkdownSpan span) {
    return TextSpan(
      text: span.text,
      style: TextStyle(
        fontStyle: span.styles.contains(TextStyle.italic)
            ? FontStyle.italic
            : null,
        fontWeight: span.styles.contains(TextStyle.bold)
            ? FontWeight.bold
            : null,
        fontFamily: span.styles.contains(TextStyle.code) ? 'monospace' : null,
        backgroundColor: span.styles.contains(TextStyle.code)
            ? Colors.black12
            : null,
      ),
    );
  }
}

/// A widget that displays a code block with optional syntax highlighting.
class CodeBlockWidget extends StatelessWidget {
  final String content;
  final String? language;
  final bool isFirst;
  final bool isLast;

  const CodeBlockWidget({
    super.key,
    required this.content,
    this.language,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (language != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                language!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectionArea(
              child: Text(
                content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
  final List<String> items;
  final bool isFirst;
  final bool isLast;
  final void Function(String option)? onOptionPress;

  const OptionsBlockWidget({
    super.key,
    required this.items,
    this.isFirst = false,
    this.isLast = false,
    this.onOptionPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        final child = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            item,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
        );

        if (onOptionPress != null) {
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onOptionPress!(item),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              margin: index > 0 ? const EdgeInsets.only(top: 8) : null,
              child: child,
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: index > 0 ? const EdgeInsets.only(top: 8) : null,
          child: child,
        );
      }).toList(),
    );
  }
}

/// A widget that displays a table with headers and data rows.
class TableBlockWidget extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final bool isFirst;
  final bool isLast;

  const TableBlockWidget({
    super.key,
    required this.headers,
    required this.rows,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columnCount = headers.length;
    final minWidth = columnCount > 0 ? (300 / columnCount).floor().toDouble() : 100;
    final safeMinWidth = minWidth < 100 ? 100 : minWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
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
                color: theme.colorScheme.surfaceVariant,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                ),
              ),
              child: Row(
                children: headers.map((header) {
                  return Container(
                    width: safeMinWidth,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      header,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
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
                    final cellText = row.length > cellIndex ? row[cellIndex] : '';

                    return Container(
                      width: safeMinWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        cellText,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
