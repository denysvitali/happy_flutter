import 'package:flutter/material.dart';

/// Terminal-specific color palette, exposed as a [ThemeExtension] so the
/// terminal screen can resolve colors via `Theme.of(context).extension`
/// instead of hardcoding `Color(0xFF...)` literals scattered through the
/// widget tree.
///
/// The terminal intentionally uses a fixed dark palette (VS Code–style)
/// in both light and dark app themes, so this extension carries a single
/// palette rather than light/dark variants. If a future light-terminal
/// variant is needed, add a brightness-aware constructor and resolve
/// from `Theme.of(context).brightness`.
///
/// Usage:
/// ```dart
/// final term = Theme.of(context).extension<AppTerminalColors>()!;
/// backgroundColor: term.background,
/// ```
@immutable
class AppTerminalColors extends ThemeExtension<AppTerminalColors> {
  const AppTerminalColors({
    required this.background,
    required this.surface,
    required this.foreground,
    required this.border,
    required this.hint,
    required this.commandPrompt,
    required this.commandText,
    required this.accent,
    required this.cursor,
  });

  /// Scaffold background — the deepest "page" surface.
  final Color background;

  /// AppBar / command-input bar surface — one step lighter than
  /// [background].
  final Color surface;

  /// Default text colour for terminal output.
  final Color foreground;

  /// Hairline divider between output and input bar.
  final Color border;

  /// Hint text in the command input.
  final Color hint;

  /// The `> ` / `$ ` prompt prefix and the success-green send icon.
  final Color commandPrompt;

  /// Colour for echoed user commands (`> ls -la`).
  final Color commandText;

  /// Accent — spinner colour while a command is in flight.
  final Color accent;

  /// TextField cursor colour.
  final Color cursor;

  /// Default VS Code–style dark palette.
  static const AppTerminalColors dark = AppTerminalColors(
    background: Color(0xFF1E1E1E),
    surface: Color(0xFF2D2D2D),
    foreground: Color(0xFFD4D4D4),
    border: Color(0xFF3C3C3C),
    hint: Color(0xFF6B6B6B),
    commandPrompt: Color(0xFF4EC94E),
    commandText: Color(0xFF569CD6),
    accent: Color(0xFF4EC94E),
    cursor: Color(0xFFD4D4D4),
  );

  @override
  AppTerminalColors copyWith({
    Color? background,
    Color? surface,
    Color? foreground,
    Color? border,
    Color? hint,
    Color? commandPrompt,
    Color? commandText,
    Color? accent,
    Color? cursor,
  }) {
    return AppTerminalColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      foreground: foreground ?? this.foreground,
      border: border ?? this.border,
      hint: hint ?? this.hint,
      commandPrompt: commandPrompt ?? this.commandPrompt,
      commandText: commandText ?? this.commandText,
      accent: accent ?? this.accent,
      cursor: cursor ?? this.cursor,
    );
  }

  @override
  AppTerminalColors lerp(ThemeExtension<AppTerminalColors>? other, double t) {
    if (other is! AppTerminalColors) return this;
    return AppTerminalColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      border: Color.lerp(border, other.border, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      commandPrompt: Color.lerp(commandPrompt, other.commandPrompt, t)!,
      commandText: Color.lerp(commandText, other.commandText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      cursor: Color.lerp(cursor, other.cursor, t)!,
    );
  }
}
