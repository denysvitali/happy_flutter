/// Data classes for markdown blocks and spans.
///
/// Represents the parsed markdown structure with type-safe block and span models.
library;

import 'package:meta/meta.dart';

/// Represents inline text styling within a block.
@immutable
class MarkdownSpan {
  /// Text styles applied to this span.
  final List<TextStyle> styles;

  /// The actual text content.
  final String text;

  /// Optional URL if this span is a link.
  final String? url;

  const MarkdownSpan({
    required this.styles,
    required this.text,
    this.url,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MarkdownSpan) return false;
    return other.styles == styles &&
        other.text == text &&
        other.url == url;
  }

  @override
  int get hashCode => Object.hash(styles, text, url);
}

/// Text style types for inline formatting.
enum TextStyle {
  italic,
  bold,
  semibold,
  code,
}

/// Base class for all markdown blocks.
sealed class MarkdownBlock {
  const MarkdownBlock();
}

/// Plain text block.
class TextBlock extends MarkdownBlock {
  final List<MarkdownSpan> content;

  const TextBlock({required this.content});
}

/// Header block (H1-H6).
class HeaderBlock extends MarkdownBlock {
  final int level;
  final List<MarkdownSpan> content;

  const HeaderBlock({required this.level, required this.content});
}

/// Unordered list block.
class ListBlock extends MarkdownBlock {
  final List<List<MarkdownSpan>> items;

  const ListBlock({required this.items});
}

/// Numbered list block.
class NumberedListBlock extends MarkdownBlock {
  final List<NumberedItem> items;

  const NumberedListBlock({required this.items});
}

/// A numbered list item with its number and content.
@immutable
class NumberedItem {
  final int number;
  final List<MarkdownSpan> spans;

  const NumberedItem({required this.number, required this.spans});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NumberedItem) return false;
    return other.number == number && other.spans == spans;
  }

  @override
  int get hashCode => Object.hash(number, spans);
}

/// Code block with optional language specification.
class CodeBlock extends MarkdownBlock {
  final String? language;
  final String content;

  const CodeBlock({this.language, required this.content});
}

/// Mermaid diagram block.
class MermaidBlock extends MarkdownBlock {
  final String content;

  const MermaidBlock({required this.content});
}

/// Horizontal rule separator.
class HorizontalRuleBlock extends MarkdownBlock {
  const HorizontalRuleBlock();
}

/// Options block for interactive choices.
class OptionsBlock extends MarkdownBlock {
  final List<String> items;

  const OptionsBlock({required this.items});
}

/// Table block with headers and rows.
class TableBlock extends MarkdownBlock {
  final List<String> headers;
  final List<List<String>> rows;

  const TableBlock({required this.headers, required this.rows});
}
