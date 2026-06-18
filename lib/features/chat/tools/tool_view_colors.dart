import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/diff_theme.dart' as ext;
import 'package:happy_flutter/core/ui/diff/diff_types.dart' as ui;

/// Theme-aware color palette for tool views (terminal, diff, file
/// operations). Resolves to GitHub-light or GitHub-dark colors
/// depending on [Brightness].
///
/// The diff palette is sourced from the [ext.DiffTheme] `ThemeExtension`
/// registered in ThemeHelper. The remaining chrome (bg, border, chip,
/// badges, copy icon, blue/green/red, error) is unique to this class
/// and not part of the diff palette.
class ToolViewColors {
  ToolViewColors._({
    required this.bg,
    required this.headerBg,
    required this.border,
    required this.mutedText,
    required this.primaryText,
    required this.lineNumberText,
    required this.chipBg,
    required this.chipBorder,
    required this.blue,
    required this.green,
    required this.red,
    required this.errorText,
    required this.greenBadgeBg,
    required this.greenBadgeBorder,
    required this.redBadgeBg,
    required this.redBadgeBorder,
    required this.errorBg,
    required this.errorBorder,
    required this.diffTheme,
    required this.copyIcon,
    required this.copyIconDone,
  });

  /// Resolve colors from the current [BuildContext].
  ///
  /// The diff palette is sourced from `context.diffTheme` (the
  /// [ext.DiffTheme] extension). All other fields are local to this
  /// class.
  factory ToolViewColors.of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? ToolViewColors._dark(context)
        : ToolViewColors._light(context);
  }

  factory ToolViewColors._dark(BuildContext context) {
    return ToolViewColors._(
      bg: const Color(0xFF0D1117),
      headerBg: const Color(0xFF161B22),
      border: const Color(0xFF30363D),
      mutedText: const Color(0xFF8B949E),
      primaryText: const Color(0xFFE6EDF3),
      lineNumberText: const Color(0xFF484F58),
      chipBg: const Color(0xFF1C2128),
      chipBorder: const Color(0xFF30363D),
      blue: const Color(0xFF58A6FF),
      green: const Color(0xFF3FB950),
      red: const Color(0xFFF85149),
      errorText: const Color(0xFFFFA198),
      greenBadgeBg: const Color(0xFF0D2818),
      greenBadgeBorder: const Color(0xFF1A4328),
      redBadgeBg: const Color(0xFF2D1117),
      redBadgeBorder: const Color(0xFF5A1E1E),
      errorBg: const Color(0xFF160B0B),
      errorBorder: const Color(0xFF5A1E1E),
      diffTheme: _diffThemeFromExtension(context),
      copyIcon: const Color(0xFF8B949E),
      copyIconDone: const Color(0xFF3FB950),
    );
  }

  factory ToolViewColors._light(BuildContext context) {
    return ToolViewColors._(
      bg: const Color(0xFFF6F8FA),
      headerBg: const Color(0xFFEBEDF0),
      border: const Color(0xFFD0D7DE),
      mutedText: const Color(0xFF656D76),
      primaryText: const Color(0xFF24292F),
      lineNumberText: const Color(0xFF6E7781),
      chipBg: const Color(0xFFE4E7EB),
      chipBorder: const Color(0xFFCED5DC),
      blue: const Color(0xFF0969DA),
      green: const Color(0xFF1A7F37),
      red: const Color(0xFFCF222E),
      errorText: const Color(0xFFCF222E),
      greenBadgeBg: const Color(0xFFDCFFE4),
      greenBadgeBorder: const Color(0xFFA8EDBA),
      redBadgeBg: const Color(0xFFFFE2E0),
      redBadgeBorder: const Color(0xFFFFADAD),
      errorBg: const Color(0xFFFFF0EE),
      errorBorder: const Color(0xFFFFADAD),
      diffTheme: _diffThemeFromExtension(context),
      copyIcon: const Color(0xFF656D76),
      copyIconDone: const Color(0xFF1A7F37),
    );
  }

  /// Bridge the new [ext.DiffTheme] `ThemeExtension` palette onto the
  /// legacy [ui.DiffTheme] value type expected by the `DiffView`
  /// widget. The two share the same field set, so the mapping is
  /// field-for-field.
  static ui.DiffTheme _diffThemeFromExtension(BuildContext context) {
    final ext = context.diffTheme;
    return ui.DiffTheme(
      addedBg: ext.addedBg,
      addedText: ext.addedText,
      removedBg: ext.removedBg,
      removedText: ext.removedText,
      contextBg: ext.contextBg,
      contextText: ext.contextText,
      lineNumberBg: ext.lineNumberBg,
      lineNumberText: ext.lineNumberText,
      hunkHeaderBg: ext.hunkHeaderBg,
      hunkHeaderText: ext.hunkHeaderText,
      inlineAddedBg: ext.inlineAddedBg,
      inlineAddedText: ext.inlineAddedText,
      inlineRemovedBg: ext.inlineRemovedBg,
      inlineRemovedText: ext.inlineRemovedText,
      leadingSpaceDot: ext.leadingSpaceDot,
    );
  }

  final Color bg;
  final Color headerBg;
  final Color border;
  final Color mutedText;
  final Color primaryText;
  final Color lineNumberText;
  final Color chipBg;
  final Color chipBorder;
  final Color blue;
  final Color green;
  final Color red;
  final Color errorText;
  final Color greenBadgeBg;
  final Color greenBadgeBorder;
  final Color redBadgeBg;
  final Color redBadgeBorder;
  final Color errorBg;
  final Color errorBorder;
  final ui.DiffTheme diffTheme;
  final Color copyIcon;
  final Color copyIconDone;
}
