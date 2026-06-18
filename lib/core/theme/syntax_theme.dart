import 'package:flutter/material.dart';

/// Theme extension carrying the syntax-highlight palette used by the
/// chat code blocks, the markdown code blocks, and the JSON viewer.
///
/// The dark palette is the Catppuccin Mocha palette (the prior inline
/// `_MochaColors` in `code_block_widget.dart` was a subset of these
/// hexes, hand-duplicated). The light palette is the same Tailwind-ish
/// hex set the project used before.
///
/// Resolved via `Theme.of(context).extension<SyntaxTheme>()` or the
/// `SyntaxTheme.of(context)` helper.
@immutable
class SyntaxTheme extends ThemeExtension<SyntaxTheme> {
  const SyntaxTheme({
    required this.tokens,
    required this.bracketNesting,
    required this.defaultText,
  });

  /// Foreground colour for each token type.
  final Map<String, Color> tokens;

  /// Rainbow-bracket colours, indexed by nesting level. Index 0 is an
  /// unused sentinel; 1..5 are the actual colours cycled across levels.
  final List<Color> bracketNesting;

  /// Fallback colour when a token type has no entry in [tokens] or when
  /// the highlighter encounters an unrecognised span.
  final Color defaultText;

  /// Resolves the colour for [tokenType]. Returns [defaultText] when the
  /// token has no entry.
  Color colorFor(String tokenType) =>
      tokens[tokenType] ?? defaultText;

  /// Returns the rainbow-bracket colour for [level].
  ///
  /// Level 0 is mapped to the highest tier (index 5) so the cycle stays
  /// contiguous; the same logic the prior in-file `_SyntaxColors` used.
  Color bracketFor(int level) {
    const span = 5;
    final normalized = level % span;
    final index = normalized == 0 ? span : normalized;
    return bracketNesting[index];
  }

  /// Light palette (Tailwind-ish — same hexes as the prior in-file map).
  static const SyntaxTheme light = SyntaxTheme(
    tokens: <String, Color>{
      'keyword': Color(0xFF1d4ed8),
      'controlFlow': Color(0xFF6d28d9),
      'type': Color(0xFF0f766e),
      'modifier': Color(0xFF1d4ed8),
      'string': Color(0xFF059669),
      'number': Color(0xFF0891b2),
      'boolean': Color(0xFF0891b2),
      'regex': Color(0xFF059669),
      'function': Color(0xFF7c3aed),
      'method': Color(0xFF9333ea),
      'property': Color(0xFF374151),
      'comment': Color(0xFF6b7280),
      'docstring': Color(0xFF6b7280),
      'operator': Color(0xFF374151),
      'assignment': Color(0xFF1d4ed8),
      'comparison': Color(0xFF1d4ed8),
      'logical': Color(0xFF1d4ed8),
      'decorator': Color(0xFFca8a04),
      'import': Color(0xFF1d4ed8),
      'variable': Color(0xFF374151),
      'parameter': Color(0xFF374151),
      'bracket': Color(0xFF374151),
      'punctuation': Color(0xFF374151),
      'default': Color(0xFF374151),
    },
    bracketNesting: <Color>[
      Color(0xFF374151), // 0 sentinel
      Color(0xFFE05252), // 1 – red
      Color(0xFF00897B), // 2 – teal
      Color(0xFF1976D2), // 3 – blue
      Color(0xFFF57F17), // 4 – amber
      Color(0xFF6A1B9A), // 5 – purple
    ],
    defaultText: Color(0xFF374151),
  );

  /// Dark palette (Catppuccin Mocha).
  /// Reference: https://github.com/catppuccin/catppuccin
  static const SyntaxTheme dark = SyntaxTheme(
    tokens: <String, Color>{
      // Keywords – blue (VSCode dark+ compatible)
      'keyword': Color(0xFF569CD6),
      // Control flow (if/else/for/return) – mauve/purple
      'controlFlow': Color(0xFFCBA6F7),
      // Types – teal
      'type': Color(0xFF94E2D5),
      // Modifiers (public/static/async) – blue
      'modifier': Color(0xFF89B4FA),
      // Strings – green
      'string': Color(0xFFA6E3A1),
      // Numbers – peach
      'number': Color(0xFFFAB387),
      // Booleans / null – peach
      'boolean': Color(0xFFFAB387),
      // Regex literals – green
      'regex': Color(0xFFA6E3A1),
      // Function names – yellow
      'function': Color(0xFFF9E2AF),
      // Method calls – sky
      'method': Color(0xFF89DCEB),
      // Property access – subtext0
      'property': Color(0xFFA6ADC8),
      // Comments – overlay0
      'comment': Color(0xFF6C7086),
      'docstring': Color(0xFF6C7086),
      // Arithmetic operators – text
      'operator': Color(0xFFCDD6F4),
      // Assignment operators – blue
      'assignment': Color(0xFF89B4FA),
      // Comparison operators – sapphire
      'comparison': Color(0xFF74C7EC),
      // Logical operators (&&/||) – mauve
      'logical': Color(0xFFCBA6F7),
      // Decorators / annotations – yellow
      'decorator': Color(0xFFF9E2AF),
      // Import statements – blue
      'import': Color(0xFF89B4FA),
      // Variables – text
      'variable': Color(0xFFCDD6F4),
      // Parameters – text
      'parameter': Color(0xFFCDD6F4),
      // Brackets – text (rainbow overrides via bracketFor)
      'bracket': Color(0xFFCDD6F4),
      // Punctuation (.,;) – overlay0
      'punctuation': Color(0xFF6C7086),
      // Default / plain text
      'default': Color(0xFFCDD6F4),
    },
    bracketNesting: <Color>[
      Color(0xFFCDD6F4), // 0 sentinel
      Color(0xFFF9E2AF), // 1 – yellow
      Color(0xFFCBA6F7), // 2 – mauve
      Color(0xFF89DCEB), // 3 – sky
      Color(0xFFFAB387), // 4 – peach
      Color(0xFF74C7EC), // 5 – sapphire
    ],
    defaultText: Color(0xFFCDD6F4),
  );

  @override
  SyntaxTheme copyWith({
    Map<String, Color>? tokens,
    List<Color>? bracketNesting,
    Color? defaultText,
  }) {
    return SyntaxTheme(
      tokens: tokens ?? this.tokens,
      bracketNesting: bracketNesting ?? this.bracketNesting,
      defaultText: defaultText ?? this.defaultText,
    );
  }

  @override
  SyntaxTheme lerp(ThemeExtension<SyntaxTheme>? other, double t) {
    if (other is! SyntaxTheme) return this;
    return SyntaxTheme(
      tokens: tokens,
      bracketNesting: <Color>[
        for (var i = 0; i < bracketNesting.length; i++)
          Color.lerp(bracketNesting[i], other.bracketNesting[i], t)!,
      ],
      defaultText: Color.lerp(defaultText, other.defaultText, t)!,
    );
  }
}

/// Convenience extension — `context.syntaxTheme` is shorter than
/// `Theme.of(context).extension<SyntaxTheme>()!` for the common case.
extension SyntaxThemeContext on BuildContext {
  /// The [SyntaxTheme] for the ambient [ThemeData], or [SyntaxTheme.dark]
  /// when no extension is registered. The fallback favours the dark
  /// palette because the existing chrome (terminal, code blocks in
  /// tool output) was always dark even when the app theme was light.
  SyntaxTheme get syntaxTheme =>
      Theme.of(this).extension<SyntaxTheme>() ?? SyntaxTheme.dark;
}
