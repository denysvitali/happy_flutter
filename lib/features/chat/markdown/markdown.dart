/// Markdown rendering support for chat messages.
///
/// This library provides comprehensive markdown parsing and rendering
/// for chat messages, supporting headers, lists, code blocks, tables,
/// mermaid diagrams, and more.
///
/// ## Usage
///
/// ```dart
/// import 'package:happy_flutter/features/chat/markdown/markdown.dart';
///
/// // Simple usage
/// MarkdownView(markdown: '# Hello\n\nThis is **bold** text.');
///
/// // With option callback
/// MarkdownView(
///   markdown: '<options>\n<option>Option 1</option>\n</options>',
///   onOptionPress: (option) => print('Selected: $option'),
/// );
/// ```
library;

export 'markdown_models.dart';
export 'markdown_parser.dart';
export 'markdown_view.dart';
export 'block_widgets.dart';
export 'mermaid_renderer.dart';
