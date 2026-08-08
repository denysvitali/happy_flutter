import 'package:flutter/material.dart';

import '../theme/app_color_scheme.dart';
import '../theme/app_tokens.dart';

/// Semantic appearance for an [AppBadge].
///
/// Non-neutral tones include a distinct default icon so state remains
/// understandable without relying on color alone.
enum AppBadgeTone { neutral, info, success, warning, danger }

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
    this.tone = AppBadgeTone.neutral,
    this.showToneIcon = true,
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

  /// Semantic appearance used when explicit colors are not provided.
  ///
  /// Defaults to [AppBadgeTone.neutral], which preserves the original badge
  /// appearance and does not add an icon.
  final AppBadgeTone tone;

  /// Whether a semantic default icon is shown when [leading] is null.
  ///
  /// Neutral badges never add an icon. Defaults to true for semantic tones.
  final bool showToneIcon;

  @override
  Widget build(BuildContext context) {
    final visuals = _visualsFor(context);
    final fg = foregroundColor ?? visuals.foreground;
    final iconColor = foregroundColor ?? visuals.iconColor;
    final effectiveLeading =
        leading ??
        (showToneIcon && visuals.icon != null
            ? Icon(visuals.icon, size: AppFontSize.sm)
            : null);

    final resolvedLabelStyle = TextStyle(
      fontSize: AppFontSize.xxs,
      fontWeight: FontWeight.w600,
      color: fg,
    ).merge(labelStyle);

    return Container(
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs + 2,
            vertical: 2,
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? visuals.background,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: iconColor, size: AppFontSize.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (effectiveLeading != null) ...[
              effectiveLeading,
              const SizedBox(width: AppSpacing.xs),
            ],
            // Label changes (e.g. counts ticking up) crossfade with a
            // slight upward slide instead of snapping.
            AnimatedSwitcher(
              duration: AppMotion.duration(context, AppDuration.fast),
              switchInCurve: AppCurve.enter,
              switchOutCurve: AppCurve.exit,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                label,
                key: ValueKey(label),
                style: resolvedLabelStyle,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.xs),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

  _AppBadgeVisuals _visualsFor(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColorScheme>();

    return switch (tone) {
      AppBadgeTone.neutral => _AppBadgeVisuals(
        background: cs.surfaceContainerHighest,
        foreground: cs.onSurfaceVariant,
        iconColor: cs.onSurfaceVariant,
      ),
      AppBadgeTone.info => _AppBadgeVisuals(
        background: appColors?.infoContainer ?? cs.primaryContainer,
        foreground: appColors?.textPrimary ?? cs.onPrimaryContainer,
        iconColor: appColors?.info ?? cs.primary,
        icon: Icons.info_outline_rounded,
      ),
      AppBadgeTone.success => _AppBadgeVisuals(
        background: appColors?.successContainer ?? cs.secondaryContainer,
        foreground: appColors?.textPrimary ?? cs.onSecondaryContainer,
        iconColor: appColors?.success ?? cs.secondary,
        icon: Icons.check_circle_outline_rounded,
      ),
      AppBadgeTone.warning => _AppBadgeVisuals(
        background: appColors?.warningContainer ?? cs.tertiaryContainer,
        foreground: appColors?.textPrimary ?? cs.onTertiaryContainer,
        iconColor: appColors?.warning ?? cs.tertiary,
        icon: Icons.warning_amber_rounded,
      ),
      AppBadgeTone.danger => _AppBadgeVisuals(
        background: appColors?.dangerContainer ?? cs.errorContainer,
        foreground: appColors?.textPrimary ?? cs.onErrorContainer,
        iconColor: appColors?.danger ?? cs.error,
        icon: Icons.error_outline_rounded,
      ),
    };
  }
}

class _AppBadgeVisuals {
  const _AppBadgeVisuals({
    required this.background,
    required this.foreground,
    required this.iconColor,
    this.icon,
  });

  final Color background;
  final Color foreground;
  final Color iconColor;
  final IconData? icon;
}
