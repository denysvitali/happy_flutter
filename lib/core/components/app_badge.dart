import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A generic, token-standardized badge/chip: an optional [leading] widget, a
/// [label], and an optional [trailing] widget laid out in a rounded container.
///
/// Consolidates the many hand-rolled `Container` + `BoxDecoration` + `Row`
/// badge/chip widgets (status pills, count badges, type tags, info chips).
/// Colors and dimensions default to design tokens but every aspect is
/// overridable so callers can match their existing look.
class AppBadge extends StatelessWidget {
  /// Creates an [AppBadge].
  const AppBadge({
    required this.label,
    super.key,
    this.leading,
    this.trailing,
    this.backgroundColor,
    this.borderColor,
    this.foregroundColor,
    this.padding,
    this.labelStyle,
  });

  /// Optional widget shown before the label (e.g. an [Icon]).
  final Widget? leading;

  /// The badge text.
  final String label;

  /// Optional widget shown after the label.
  final Widget? trailing;

  /// Container fill color. Defaults to `surfaceContainerHighest`.
  final Color? backgroundColor;

  /// Border color. When null no border is drawn.
  final Color? borderColor;

  /// Color applied to the label (and to a leading/trailing [Icon] via
  /// [IconTheme]). Defaults to `onSurfaceVariant`.
  final Color? foregroundColor;

  /// Inner padding. Defaults to the standardized badge padding
  /// (horizontal `AppSpacing.xs + 2`, vertical `2`).
  final EdgeInsets? padding;

  /// Style override for the label text. Merged over the default compact style.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = foregroundColor ?? cs.onSurfaceVariant;

    final resolvedLabelStyle = TextStyle(
      fontSize: AppFontSize.xxs,
      fontWeight: FontWeight.w600,
      color: fg,
    ).merge(labelStyle);

    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs + 2,
            vertical: 2,
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: borderColor != null
            ? Border.all(color: borderColor!)
            : null,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: fg, size: AppFontSize.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(label, style: resolvedLabelStyle),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.xs),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
