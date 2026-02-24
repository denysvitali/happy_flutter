/// Markdown view widgets using flutter_markdown_plus with custom extensions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Callback type for when an option is pressed in an options block.
typedef OptionPressedCallback = void Function(String option);

/// A widget that renders markdown content with full formatting support.
///
/// Supports:
/// - All standard markdown (headers, lists, code blocks, tables, etc.)
/// - `\<options\>` blocks with interactive chips
/// - GitHub Flavored Markdown
class MarkdownView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MarkdownBody(
      data: markdown,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      builders: {
        'options': OptionsElementBuilder(
          onOptionPress: onOptionPress,
          textColor: textColor,
        ),
      },
      blockSyntaxes: const [
        OptionsBlockSyntax(),
      ],
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        h1: theme.textTheme.headlineLarge?.copyWith(color: textColor),
        h2: theme.textTheme.headlineMedium?.copyWith(color: textColor),
        h3: theme.textTheme.headlineSmall?.copyWith(color: textColor),
        h4: theme.textTheme.titleLarge?.copyWith(color: textColor),
        h5: theme.textTheme.titleMedium?.copyWith(color: textColor),
        h6: theme.textTheme.titleSmall?.copyWith(color: textColor),
        listBullet: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

/// A simpler markdown view widget for basic text rendering.
///
/// This is a convenience widget that renders markdown without
/// the interactive options block support.
class SimpleMarkdownView extends StatelessWidget {
  /// Creates a [SimpleMarkdownView].
  const SimpleMarkdownView({required this.markdown, super.key});

  /// The markdown text to render.
  final String markdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MarkdownBody(
      data: markdown,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
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
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 14,
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
              borderRadius: BorderRadius.circular(100),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: Text(item),
        );
      }).toList(),
    );
  }
}
