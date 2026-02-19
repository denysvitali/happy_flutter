/// Data classes for markdown blocks and spans.
///
/// Represents the parsed markdown structure with type-safe
library;

import 'package:meta/meta.dart';

/// Represents inline text styling within a block.
@immutable
class MarkdownSpan {

  const MarkdownSpan({
    required this.styles,
    required this.text,
    this.url,
  });
  /// Text styles applied to this span.
  final List<MarkdownTextStyle> styles;

  /// The actual text content.
  final String text;

  /// Optional URL if this span is a link.
  final String? url;

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
enum MarkdownTextStyle {
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

  const TextBlock({required this.content});
  final List<MarkdownSpan> content;
}

/// Header block (H1-H6).
class HeaderBlock extends MarkdownBlock {

  const HeaderBlock({required this.level, required this.content});
  final int level;
  final List<MarkdownSpan> content;
}

/// Unordered list block.
class ListBlock extends MarkdownBlock {

  const ListBlock({required this.items});
  final List<List<MarkdownSpan>> items;
}

/// Numbered list block.
class NumberedListBlock extends MarkdownBlock {

  const NumberedListBlock({required this.items});
  final List<NumberedItem> items;
}

/// A numbered list item with its number and content.
@immutable
class NumberedItem {

  const NumberedItem({required this.number, required this.spans});
  final int number;
  final List<MarkdownSpan> spans;

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

  const CodeBlock({required this.content, this.language});
  final String? language;
  final String content;
}

/// Mermaid diagram block.
class MermaidBlock extends MarkdownBlock {

  const MermaidBlock({required this.content});
  final String content;
}

/// Horizontal rule separator.
class HorizontalRuleBlock extends MarkdownBlock {
  const HorizontalRuleBlock();
}

/// Options block for interactive choices.
class OptionsBlock extends MarkdownBlock {

  const OptionsBlock({required this.items});
  final List<String> items;
}

/// Table block with headers and rows.
class TableBlock extends MarkdownBlock {

  const TableBlock({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
}
