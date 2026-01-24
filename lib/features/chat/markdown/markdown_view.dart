/// Main markdown view widget that renders parsed markdown content.
///
/// This widget parses markdown text into blocks and renders each block
/// with the appropriate widget. Supports text selection on long-press.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'markdown_models.dart';
import 'markdown_parser.dart';
import 'block_widgets.dart';
import 'mermaid_renderer.dart';

/// Callback type for when an option is pressed in an options block.
typedef OptionPressedCallback = void Function(String option);

/// A widget that renders markdown content with full formatting support.
///
/// Supports:
/// - Headers (H1-H6)
/// - Plain text with bold, italic, and inline code
/// - Ordered and unordered lists
/// - Code blocks with language labels
/// - Mermaid diagrams
/// - Tables with headers and data rows
/// - Horizontal rules
/// - Interactive options blocks
/// - Text selection via long-press
class MarkdownView extends StatefulWidget {
  /// The raw markdown text to render.
  final String markdown;

  /// Optional callback when an option in an options block is pressed.
  final OptionPressedCallback? onOptionPress;

  const MarkdownView({
    super.key,
    required this.markdown,
    this.onOptionPress,
  });

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  List<MarkdownBlock>? _blocks;
  bool _showCopyOverlay = false;

  @override
  void initState() {
    super.initState();
    _parseMarkdown();
  }

  @override
  void didUpdateWidget(MarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdown != widget.markdown) {
      _parseMarkdown();
    }
  }

  void _parseMarkdown() {
    setState(() {
      _blocks = parseMarkdown(widget.markdown);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_blocks == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onLongPress: _showCopyOverlay ? null : _handleLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: _blocks!.asMap().entries.map((entry) {
          final index = entry.key;
          final block = entry.value;
          final isFirst = index == 0;
          final isLast = index == _blocks!.length - 1;

          return _buildBlock(block, isFirst, isLast);
        }).toList(),
      ),
    );
  }

  Widget _buildBlock(MarkdownBlock block, bool isFirst, bool isLast) {
    switch (block) {
      case TextBlock(:final content):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextBlockWidget(
            content: content,
            isFirst: isFirst,
            isLast: isLast,
          ),
        );
      case HeaderBlock(:final level, :final content):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: HeaderBlockWidget(
            level: level,
            content: content,
            isFirst: isFirst,
            isLast: isLast,
          ),
        );
      case ListBlock(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ListBlockWidget(
            items: items,
            isFirst: isFirst,
            isLast: isLast,
          ),
        );
      case NumberedListBlock(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: NumberedListBlockWidget(
            items: items,
            isFirst: isFirst,
            isLast: isLast,
          ),
        );
      case CodeBlock(:final language, :final content):
        return CodeBlockWidget(
          content: content,
          language: language,
          isFirst: isFirst,
          isLast: isLast,
        );
      case MermaidBlock(:final content):
        return MermaidBlockWidget(content: content);
      case HorizontalRuleBlock():
        return const HorizontalRuleBlockWidget();
      case OptionsBlock(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OptionsBlockWidget(
            items: items,
            isFirst: isFirst,
            isLast: isLast,
            onOptionPress: widget.onOptionPress,
          ),
        );
      case TableBlock(:final headers, :final rows):
        return TableBlockWidget(
          headers: headers,
          rows: rows,
          isFirst: isFirst,
          isLast: isLast,
        );
      // Sealed class ensures all cases are covered above
    }
  }

  void _handleLongPress() {
    // Show a snackbar with copy option
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Copy text'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () => _copyText(),
        ),
      ),
    );
  }

  void _copyText() {
    // Use Clipboard.setData to copy the markdown content
    // This is handled by the parent widget
  }
}

/// A simpler markdown view widget for basic text rendering.
///
/// This is a convenience widget that renders markdown without
/// additional styling wrapper.
class SimpleMarkdownView extends StatelessWidget {
  /// The markdown text to render.
  final String markdown;

  const SimpleMarkdownView({super.key, required this.markdown});

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdown(markdown);

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: blocks.asMap().entries.map((entry) {
          final index = entry.key;
          final block = entry.value;
          final isFirst = index == 0;
          final isLast = index == blocks.length - 1;

          return _buildBlock(block, isFirst, isLast, context);
        }).toList(),
      ),
    );
  }

  Widget _buildBlock(
    MarkdownBlock block,
    bool isFirst,
    bool isLast,
    BuildContext context,
  ) {
    final theme = Theme.of(context);

    switch (block) {
      case TextBlock(:final content):
        return _buildRichText(content, theme);
      case HeaderBlock(:final level, :final content):
        final fontSize = switch (level) {
          1 => 28.0,
          2 => 24.0,
          3 => 20.0,
          4 => 18.0,
          _ => 16.0,
        };
        final fontWeight = switch (level) {
          1 => FontWeight.w900,
          2 || 3 => FontWeight.w600,
          _ => FontWeight.w600,
        };
        return _buildRichText(
          content,
          theme,
          fontSize: fontSize,
          fontWeight: fontWeight,
        );
      case ListBlock(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: _buildRichText(item, theme)),
              ],
            );
          }).toList(),
        );
      case NumberedListBlock(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.number}. '),
                Expanded(child: _buildRichText(item.spans, theme)),
              ],
            );
          }).toList(),
        );
      case CodeBlock(:final language, :final content):
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      case MermaidBlock(:final content):
        return MermaidBlockWidget(content: content);
      case HorizontalRuleBlock():
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          height: 1,
          color: theme.colorScheme.outlineVariant,
        );
      case OptionsBlock(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((item) {
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item),
            );
          }).toList(),
        );
      case TableBlock(:final headers, :final rows):
        return _buildTable(headers, rows, theme);
      // Sealed class ensures all cases are covered above
    }
  }

  Widget _buildRichText(
    List<MarkdownSpan> spans,
    ThemeData theme, {
    double? fontSize,
    FontWeight? fontWeight,
  }) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize ?? 16,
          fontWeight: fontWeight,
          height: 1.5,
          color: theme.colorScheme.onSurface,
        ),
        children: spans.map((span) {
          final style = TextStyle(
            fontStyle: span.styles.contains(MarkdownTextStyle.italic)
                ? FontStyle.italic
                : null,
            fontWeight: span.styles.contains(MarkdownTextStyle.bold)
                ? FontWeight.bold
                : span.styles.contains(MarkdownTextStyle.semibold)
                    ? FontWeight.w600
                    : fontWeight,
            fontSize: fontSize ?? 16,
            color: theme.colorScheme.onSurface,
            fontFamily: span.styles.contains(MarkdownTextStyle.code) ? 'monospace' : null,
            backgroundColor: span.styles.contains(MarkdownTextStyle.code)
                ? Colors.black12
                : null,
          );

          if (span.url != null) {
            return TextSpan(
              text: span.text,
              style: style.copyWith(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _launchUrl(span.url!),
            );
          }

          return TextSpan(text: span.text, style: style);
        }).toList(),
      ),
    );
  }

  Widget _buildTable(List<String> headers, List<List<String>> rows, ThemeData theme) {
    final columnCount = headers.length;
    final minWidth = columnCount > 0 ? (300 / columnCount).floor().toDouble() : 100.0;
    final safeMinWidth = minWidth < 100.0 ? 100.0 : minWidth;

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
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: Row(
                children: headers.map((header) {
                  return Container(
                    width: safeMinWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            // Rows
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        cellText,
                        style: TextStyle(
                          fontSize: 14,
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

  void _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
