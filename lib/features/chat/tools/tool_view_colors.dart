import 'package:flutter/material.dart';
import 'package:happy_flutter/core/ui/diff/diff_types.dart';

/// Theme-aware color palette for tool views (terminal, diff, file
/// operations). Resolves to GitHub-light or GitHub-dark colors
/// depending on [Brightness].
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
  factory ToolViewColors.of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? ToolViewColors._dark()
        : ToolViewColors._light();
  }

  factory ToolViewColors._dark() {
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
      diffTheme: const DiffTheme(
        addedBg: Color(0xFF0D2818),
        addedText: Color(0xFF3FB950),
        removedBg: Color(0xFF2D1117),
        removedText: Color(0xFFF85149),
        contextBg: Colors.transparent,
        contextText: Color(0xFFE6EDF3),
        lineNumberBg: Color(0xFF161B22),
        lineNumberText: Color(0xFF484F58),
        hunkHeaderBg: Color(0xFF1C2128),
        hunkHeaderText: Color(0xFF8B949E),
        inlineAddedBg: Color(0xFF1A4328),
        inlineAddedText: Color(0xFF3FB950),
        inlineRemovedBg: Color(0xFF5A1E1E),
        inlineRemovedText: Color(0xFFF85149),
        leadingSpaceDot: Color(0xFF484F58),
      ),
      copyIcon: const Color(0xFF8B949E),
      copyIconDone: const Color(0xFF3FB950),
    );
  }

  factory ToolViewColors._light() {
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
      diffTheme: const DiffTheme(
        addedBg: Color(0xFFE6FFEC),
        addedText: Color(0xFF1A7F37),
        removedBg: Color(0xFFFFEBE9),
        removedText: Color(0xFFCF222E),
        contextBg: Colors.transparent,
        contextText: Color(0xFF24292F),
        lineNumberBg: Color(0xFFF5F5F5),
        lineNumberText: Color(0xFF6E7781),
        hunkHeaderBg: Color(0xFFF0F0F0),
        hunkHeaderText: Color(0xFF656D76),
        inlineAddedBg: Color(0xFFACEDBE),
        inlineAddedText: Color(0xFF1A7F37),
        inlineRemovedBg: Color(0xFFFFCECB),
        inlineRemovedText: Color(0xFFCF222E),
        leadingSpaceDot: Color(0xFFD4D4D4),
      ),
      copyIcon: const Color(0xFF656D76),
      copyIconDone: const Color(0xFF1A7F37),
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
  final DiffTheme diffTheme;
  final Color copyIcon;
  final Color copyIconDone;
}
