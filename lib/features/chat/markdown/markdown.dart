/// Markdown rendering support for chat messages using flutter_markdown_plus.
///
/// This library provides markdown parsing with custom extensions for:
/// - `\<options\>` blocks with interactive chips
/// - Mermaid diagram support
///
/// ## Usage
///
/// ```dart
/// import 'package:happy_flutter/features/chat/markdown/markdown.dart';
///
/// // Basic usage
/// MarkdownView(markdown: '# Hello\n\nThis is **bold** text.');
///
/// // With option callback
/// MarkdownView(
///   markdown: '\<options\>\n\<option\>Option 1\</option\>\n\</options\>',
///   onOptionPress: (option) => print('Selected: \$option'),
/// );
/// ```
library;

export 'package:flutter_markdown_plus/flutter_markdown_plus.dart'
    hide Markdown, MarkdownBody;
export 'markdown_view.dart';
