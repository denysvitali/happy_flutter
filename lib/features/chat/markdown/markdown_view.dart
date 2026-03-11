/// Markdown view widgets using flutter_markdown_plus with custom extensions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme/app_tokens.dart';
import '../code_block_widget.dart';

/// Callback type for when an option is pressed in an options block.
typedef OptionPressedCallback = void Function(String option);

/// A widget that renders markdown content with full formatting support.
///
/// Supports:
/// - All standard markdown (headers, lists, code blocks, tables, etc.)
/// - `\<options\>` blocks with interactive chips
/// - GitHub Flavored Markdown
///
/// The [MarkdownStyleSheet] is built once and cached; it is only rebuilt
/// when the theme or [textColor] changes. This prevents [MarkdownBody] from
/// re-parsing the document on every parent rebuild (e.g. sync events).
class MarkdownView extends StatefulWidget {
  /// Creates a [MarkdownView].
  const MarkdownView({
    required this.markdown,
    super.key,
    this.onOptionPress,
    this.textColor,
  });

  /// The raw markdown text to render.
  final String markdown;

  /// Optional callback when an option in an options block is pressed.
  final OptionPressedCallback? onOptionPress;

  /// Optional text color override for the markdown content.
  final Color? textColor;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  MarkdownStyleSheet? _styleSheet;
  ThemeData? _lastTheme;
  Color? _lastTextColor;

  MarkdownStyleSheet _buildStyleSheet(ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    // When a textColor override is set (e.g. white-on-primary user bubble),
    // use it for links too — with an underline so they remain distinguishable.
    final linkStyle = widget.textColor != null
        ? TextStyle(
            color: widget.textColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.textColor?.withValues(alpha: 0.7),
          )
        : null;
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      a: linkStyle,
      p: theme.textTheme.bodyMedium?.copyWith(color: widget.textColor),
      h1: theme.textTheme.headlineLarge?.copyWith(color: widget.textColor),
      h2: theme.textTheme.headlineMedium?.copyWith(color: widget.textColor),
      h3: theme.textTheme.headlineSmall?.copyWith(color: widget.textColor),
      h4: theme.textTheme.titleLarge?.copyWith(color: widget.textColor),
      h5: theme.textTheme.titleMedium?.copyWith(color: widget.textColor),
      h6: theme.textTheme.titleSmall?.copyWith(color: widget.textColor),
      listBullet:
          theme.textTheme.bodyMedium?.copyWith(color: widget.textColor),
      blockquoteDecoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.05),
        border: Border(
          left: BorderSide(
            color: onSurface.withValues(alpha: 0.3),
            width: 4,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: (widget.textColor ?? onSurface).withValues(alpha: 0.75),
        fontStyle: FontStyle.italic,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: AppFontSize.base,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_styleSheet == null ||
        !identical(theme, _lastTheme) ||
        widget.textColor != _lastTextColor) {
      _styleSheet = _buildStyleSheet(theme);
      _lastTheme = theme;
      _lastTextColor = widget.textColor;
    }

    return MarkdownBody(
      data: widget.markdown,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      builders: {
        'pre': _CodeBlockBuilder(),
        'options': OptionsElementBuilder(
          onOptionPress: widget.onOptionPress,
          textColor: widget.textColor,
        ),
      },
      blockSyntaxes: const [
        OptionsBlockSyntax(),
      ],
      styleSheet: _styleSheet!,
    );
  }
}

/// A simpler markdown view widget for basic text rendering.
///
/// This is a convenience widget that renders markdown without
/// the interactive options block support. Like [MarkdownView], the
/// [MarkdownStyleSheet] is cached and rebuilt only on theme changes.
class SimpleMarkdownView extends StatefulWidget {
  /// Creates a [SimpleMarkdownView].
  const SimpleMarkdownView({required this.markdown, super.key});

  /// The markdown text to render.
  final String markdown;

  @override
  State<SimpleMarkdownView> createState() => _SimpleMarkdownViewState();
}

class _SimpleMarkdownViewState extends State<SimpleMarkdownView> {
  MarkdownStyleSheet? _styleSheet;
  ThemeData? _lastTheme;

  MarkdownStyleSheet _buildStyleSheet(ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      blockquoteDecoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.05),
        border: Border(
          left: BorderSide(
            color: onSurface.withValues(alpha: 0.3),
            width: 4,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: onSurface.withValues(alpha: 0.75),
        fontStyle: FontStyle.italic,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: AppFontSize.base,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_styleSheet == null || !identical(theme, _lastTheme)) {
      _styleSheet = _buildStyleSheet(theme);
      _lastTheme = theme;
    }

    return MarkdownBody(
      data: widget.markdown,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      builders: {
        'pre': _CodeBlockBuilder(),
      },
      styleSheet: _styleSheet!,
    );
  }
}

/// Builder that renders fenced code blocks using [CodeBlockWidget].
///
/// Extracts the language from the `code` child element's `class` attribute
/// (e.g. `language-dart`) and renders a fully styled code block with syntax
/// highlighting, line numbers, and a copy button.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.textContent;
    String? language;

    // Fenced code: <pre><code class="language-dart">…</code></pre>
    final children = element.children;
    if (children != null && children.isNotEmpty) {
      final first = children.first;
      if (first is md.Element && first.tag == 'code') {
        final cls = first.attributes['class'] ?? '';
        if (cls.startsWith('language-')) {
          language = cls.substring('language-'.length);
        }
      }
    }

    // Strip trailing newline that the parser appends.
    final trimmed =
        code.endsWith('\n') ? code.substring(0, code.length - 1) : code;

    return CodeBlockWidget(
      code: trimmed,
      language: language,
    );
  }
}

/// A custom block syntax for parsing `\<options\>` blocks.
///
/// Syntax:
/// ```
/// \<options\>
/// \<option\>Option 1\</option\>
/// \<option\>Option 2\</option\>
/// \</options\>
/// ```
class OptionsBlockSyntax extends md.BlockSyntax {
  /// Creates an [OptionsBlockSyntax].
  const OptionsBlockSyntax();

  @override
  RegExp get pattern => RegExp(r'^\s*\u003coptions\u003e\s*$');

  @override
  md.Node parse(md.BlockParser parser) {
    final items = <String>[];

    // Skip the opening tag
    parser.advance();

    // Parse option tags until we hit the closing tag
    while (!parser.isDone) {
      final line = parser.current.content;

      // Check for closing tag
      if (RegExp(r'^\s*\u003c/options\u003e\s*$').hasMatch(line)) {
        parser.advance();
        break;
      }

      // Extract content from <option> tags
      final match = RegExp(r'\u003coption\u003e(.*?)\u003c/option\u003e').firstMatch(line);
      if (match != null) {
        items.add(match.group(1) ?? '');
      }

      parser.advance();
    }

    // Create a custom element that will be rendered by OptionsElementBuilder
    return md.Element('options', [md.Text(items.join('\n'))]);
  }
}

/// Builder for rendering `\<options\>` elements as interactive chips.
class OptionsElementBuilder extends MarkdownElementBuilder {
  /// Creates an [OptionsElementBuilder].
  OptionsElementBuilder({this.onOptionPress, this.textColor});

  /// Callback when an option is pressed.
  final OptionPressedCallback? onOptionPress;

  /// Optional text color for non-interactive option chips.
  final Color? textColor;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Parse the items from the element text content
    final items =
        element.textContent.split('\n').where((s) => s.isNotEmpty).toList();

    return _OptionsChips(
      items: items,
      onOptionPress: onOptionPress,
      textColor: textColor,
    );
  }
}

/// Widget that displays options as interactive chips.
class _OptionsChips extends StatelessWidget {
  const _OptionsChips({
    required this.items,
    this.onOptionPress,
    this.textColor,
  });

  final List<String> items;
  final OptionPressedCallback? onOptionPress;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInteractive = onOptionPress != null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        if (!isInteractive) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              item,
              style: TextStyle(
                fontSize: AppFontSize.base,
                color: textColor ?? theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return OutlinedButton(
          onPressed: () => onOptionPress!(item),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            textStyle: const TextStyle(
              fontSize: AppFontSize.base,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Text(item),
        );
      }).toList(),
    );
  }
}
