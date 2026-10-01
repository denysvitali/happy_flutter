import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// The only place a button's color is overridden.
///
/// Buttons take their size, shape and type from the theme (`FilledButton`
/// primary, `OutlinedButton` secondary, `TextButton` tertiary). A call site
/// that needs a destructive action asks for it here instead of hand-writing
/// `styleFrom(foregroundColor: cs.error)`, so every Delete, Sign out and Stop
/// is the same red.
abstract final class AppButtonStyle {
  /// Shorter button for dense rows and cards: [AppRowHeight.compact] tall,
  /// shrink-wrapped tap area. Combine with [ButtonStyle.merge].
  static const ButtonStyle compact = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(AppRowHeight.compact, AppRowHeight.compact),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// Error-colored label (and outline, for [OutlinedButton]) for a text or
  /// outlined destructive action.
  static ButtonStyle destructive(ColorScheme cs) => ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(cs.error),
    overlayColor: WidgetStatePropertyAll(cs.error.withValues(alpha: 0.08)),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(color: cs.error.withValues(alpha: 0.6)),
    ),
  );

  /// Solid error fill for the confirming button of a destructive dialog.
  ///
  /// The themed [FilledButton] paints a primary gradient through
  /// `backgroundBuilder`, which would cover a plain `backgroundColor`, so the
  /// solid fill is supplied through the builder as well.
  static ButtonStyle destructiveFilled(ColorScheme cs) =>
      FilledButton.styleFrom(foregroundColor: cs.onError).copyWith(
        backgroundBuilder: (context, states, child) => Ink(
          decoration: BoxDecoration(
            color: states.contains(WidgetState.disabled)
                ? cs.onSurface.withValues(alpha: 0.12)
                : cs.error,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: child,
        ),
      );
}
