import 'package:flutter/material.dart';

/// Theme extension for the chrome around syntax-highlighted code blocks:
/// the outer block background, the language header strip, the
/// copy-button states, the line-number gutter, and the truncation
/// notice.
///
/// The previous in-file `_MochaColors` getter class in
/// `code_block_widget.dart` carried a subset of these hexes for the
/// dark side; the light side was inlined as raw `Color(0xFF...)` literals
/// scattered through the build method. Both now live here.
///
/// `message_detail_screen.dart` previously had a third hardcoded
/// variant of "tool-output code bg" (`#1E1E1E`) and "text on dark code"
/// (`#D4D4D4`) — also consolidated to [CodeViewerTheme.dark].
@immutable
class CodeViewerTheme extends ThemeExtension<CodeViewerTheme> {
  const CodeViewerTheme({
    required this.background,
    required this.headerBackground,
    required this.headerHover,
    required this.headerLabel,
    required this.divider,
    required this.border,
    required this.foreground,
    required this.muted,
    required this.successAccent,
    required this.idleAccent,
    required this.lineNumberText,
  });

  /// Outer block background.
  final Color background;

  /// Language header strip (the row that says "dart" + copy button).
  final Color headerBackground;

  /// Header strip on mouse-over (web/desktop only — informational).
  final Color headerHover;

  /// Header label colour ("dart", filename, etc.).
  final Color headerLabel;

  /// Hairline divider under the header / beside the line-number gutter.
  final Color divider;

  /// Outer 1 px border.
  final Color border;

  /// Default code text colour.
  final Color foreground;

  /// Secondary text colour (truncation notice, etc.).
  final Color muted;

  /// Copy-button "copied!" success state.
  final Color successAccent;

  /// Copy-button idle state.
  final Color idleAccent;

  /// Line-number gutter digit colour.
  final Color lineNumberText;

  /// Light palette (matches the prior inlined values from
  /// `code_block_widget.dart`).
  static const CodeViewerTheme light = CodeViewerTheme(
    background: Color(0xFFF1F5F9),
    headerBackground: Color(0xFFEFF1F3),
    headerHover: Color(0xFFE2E5E9),
    headerLabel: Color(0xFF6E7781),
    divider: Color(0xFFD0D7DE),
    border: Color(0xFFD0D7DE),
    foreground: Color(0xFF374151),
    muted: Color(0xFF6E7781),
    successAccent: Color(0xFF1A7F37),
    idleAccent: Color(0xFF6E7781),
    lineNumberText: Color(0xFF8C959F),
  );

  /// Dark palette (Catppuccin Mocha surface tones — supersedes the
  /// `_mocha.crust`/`_mocha.mantle`/`_mocha.surface0` getter class).
  static const CodeViewerTheme dark = CodeViewerTheme(
    background: Color(0xFF11111B), // crust
    headerBackground: Color(0xFF181825), // mantle
    headerHover: Color(0xFF313244), // surface0
    headerLabel: Color(0xFFA6ADC8), // subtext0
    divider: Color(0xFF313244), // surface0
    border: Color(0xFF313244),
    foreground: Color(0xFFCDD6F4), // text
    muted: Color(0xFFA6ADC8),
    successAccent: Color(0xFFA6E3A1), // green
    idleAccent: Color(0xFF6C7086), // overlay0
    lineNumberText: Color(0xFF45475A), // surface1
  );

  @override
  CodeViewerTheme copyWith({
    Color? background,
    Color? headerBackground,
    Color? headerHover,
    Color? headerLabel,
    Color? divider,
    Color? border,
    Color? foreground,
    Color? muted,
    Color? successAccent,
    Color? idleAccent,
    Color? lineNumberText,
  }) {
    return CodeViewerTheme(
      background: background ?? this.background,
      headerBackground: headerBackground ?? this.headerBackground,
      headerHover: headerHover ?? this.headerHover,
      headerLabel: headerLabel ?? this.headerLabel,
      divider: divider ?? this.divider,
      border: border ?? this.border,
      foreground: foreground ?? this.foreground,
      muted: muted ?? this.muted,
      successAccent: successAccent ?? this.successAccent,
      idleAccent: idleAccent ?? this.idleAccent,
      lineNumberText: lineNumberText ?? this.lineNumberText,
    );
  }

  @override
  CodeViewerTheme lerp(
    ThemeExtension<CodeViewerTheme>? other,
    double t,
  ) {
    if (other is! CodeViewerTheme) return this;
    return CodeViewerTheme(
      background: Color.lerp(background, other.background, t)!,
      headerBackground:
          Color.lerp(headerBackground, other.headerBackground, t)!,
      headerHover: Color.lerp(headerHover, other.headerHover, t)!,
      headerLabel: Color.lerp(headerLabel, other.headerLabel, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      border: Color.lerp(border, other.border, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      successAccent: Color.lerp(successAccent, other.successAccent, t)!,
      idleAccent: Color.lerp(idleAccent, other.idleAccent, t)!,
      lineNumberText:
          Color.lerp(lineNumberText, other.lineNumberText, t)!,
    );
  }
}

/// Convenience extension — same shape as [SyntaxThemeContext].
extension CodeViewerThemeContext on BuildContext {
  /// The [CodeViewerTheme] for the ambient [ThemeData], or
  /// [CodeViewerTheme.dark] when no extension is registered.
  CodeViewerTheme get codeViewerTheme =>
      Theme.of(this).extension<CodeViewerTheme>() ??
      CodeViewerTheme.dark;
}
