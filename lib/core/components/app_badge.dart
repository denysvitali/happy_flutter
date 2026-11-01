import 'package:flutter/material.dart';

import '../theme/app_color_scheme.dart';
import '../theme/app_colors.dart' show AppOpacity;
import '../theme/app_tokens.dart';

/// Semantic appearance for an [AppBadge].
///
/// Non-neutral tones include a distinct default icon so state remains
/// understandable without relying on color alone.
enum AppBadgeTone { neutral, info, success, warning, danger }

/// The one pill: an optional [leading] widget, a [label], and an optional
/// [trailing] widget in a full-radius container.
///
/// Geometry and type are fixed — every badge has the same padding, radius,
/// label size and weight — so pills line up and match wherever they appear.
/// Callers choose only *meaning*: a semantic [tone], or a categorical [color]
/// hue, optionally [solid] (filled counters), [outlined] or [monospace].
class AppBadge extends StatelessWidget {
  /// The one padding every pill uses. Exposed for the few non-badge pills
  /// (e.g. gradient counters) that must match badge height.
  static const EdgeInsets defaultPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.xsm,
    vertical: AppSpacing.xxs,
  );

  /// Creates an [AppBadge].
  const AppBadge({
    required this.label,
    super.key,
    this.leading,
    this.trailing,
    this.tone = AppBadgeTone.neutral,
    this.color,
    this.solid = false,
    this.outlined = false,
    this.monospace = false,
    this.minWidth,
    this.showToneIcon = true,
  }) : assert(
         color == null || tone == AppBadgeTone.neutral,
         'Pass either a semantic tone or a categorical color, not both.',
       );

  /// Optional widget shown before the label (e.g. an [Icon]). Icons inherit
  /// the badge's icon color and size unless they set their own.
  final Widget? leading;

  /// The badge text.
  final String label;

  /// Optional widget shown after the label.
  final Widget? trailing;

  /// Semantic appearance. Non-neutral tones add a default icon.
  final AppBadgeTone tone;

  /// Categorical hue (file type, priority, lane) for meaning that is not a
  /// status tone. Tinted at one fixed strength unless [solid].
  final Color? color;

  /// Fill with the full hue and contrasting text — for counters that must
  /// pop (unread counts).
  final bool solid;

  /// Adds a hairline `outlineVariant` border.
  final bool outlined;

  /// Renders the label in the monospace family (extensions, exit codes).
  final bool monospace;

  /// Minimum badge width; the label centers inside it. Keeps one- and
  /// two-digit counters the same width.
  final double? minWidth;

  /// Whether a semantic default icon is shown when [leading] is null.
  ///
  /// Neutral badges never add an icon. Defaults to true for semantic tones.
  final bool showToneIcon;

  @override
  Widget build(BuildContext context) {
    final visuals = AppToneColors.of(context, tone);
    final hue = color ?? (solid ? visuals.iconColor : null);
    final Color fg;
    final Color iconColor;
    final Color background;
    if (hue == null) {
      fg = visuals.foreground;
      iconColor = visuals.iconColor;
      background = visuals.background;
    } else if (solid) {
      fg = ThemeData.estimateBrightnessForColor(hue) == Brightness.dark
          ? Colors.white
          : Colors.black;
      iconColor = fg;
      background = hue;
    } else {
      fg = hue;
      iconColor = hue;
      background = hue.withValues(alpha: AppOpacity.soft);
    }
    final effectiveLeading =
        leading ??
        (showToneIcon && visuals.icon != null
            ? Icon(visuals.icon, size: AppFontSize.sm)
            : null);

    final resolvedLabelStyle = TextStyle(
      fontSize: AppFontSize.sm,
      fontWeight: FontWeight.w600,
      fontFamily: monospace ? 'monospace' : null,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: fg,
    );

    return Container(
      constraints: minWidth == null
          ? null
          : BoxConstraints(minWidth: minWidth!),
      alignment: minWidth == null ? null : Alignment.center,
      padding: defaultPadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      // Painted over, not laid out: an outline must not make the pill taller.
      foregroundDecoration: outlined
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: AppBorder.hairline,
              ),
            )
          : null,
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
            Flexible(
              child: AnimatedSwitcher(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
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
}

/// The one semantic palette for every toned surface: [AppBadge] pills and
/// [AppBanner] alerts resolve their colors here, so a warning pill and a
/// warning banner can never drift apart.
@immutable
class AppToneColors {
  /// Creates a resolved tone palette.
  const AppToneColors({
    required this.background,
    required this.foreground,
    required this.iconColor,
    required this.border,
    this.icon,
  });

  /// Resolves [tone] against the current theme.
  factory AppToneColors.of(BuildContext context, AppBadgeTone tone) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Same palette with or without the theme extension, so a bare
    // ThemeData never forks the semantic colors.
    final app =
        theme.extension<AppColorScheme>() ??
        (theme.brightness == Brightness.dark
            ? AppColorScheme.dark()
            : AppColorScheme.light());

    return switch (tone) {
      AppBadgeTone.neutral => AppToneColors(
        background: cs.surfaceContainerHighest,
        foreground: cs.onSurfaceVariant,
        iconColor: cs.onSurfaceVariant,
        border: cs.outlineVariant,
      ),
      // Info is the primary hue, never amber: it must read differently from
      // warning at a glance.
      AppBadgeTone.info => AppToneColors(
        background: cs.primaryContainer,
        foreground: cs.onPrimaryContainer,
        iconColor: cs.primary,
        border: cs.primary,
        icon: Icons.info_outline_rounded,
      ),
      AppBadgeTone.success => AppToneColors(
        background: app.successContainer,
        foreground: app.textPrimary,
        iconColor: app.success,
        border: app.success,
        icon: Icons.check_circle_outline_rounded,
      ),
      AppBadgeTone.warning => AppToneColors(
        background: app.warningContainer,
        foreground: app.onWarningContainer,
        iconColor: app.warning,
        border: app.warning,
        icon: Icons.warning_amber_rounded,
      ),
      AppBadgeTone.danger => AppToneColors(
        background: app.dangerContainer,
        foreground: app.textPrimary,
        iconColor: app.danger,
        border: app.danger,
        icon: Icons.error_outline_rounded,
      ),
    };
  }

  /// Container fill.
  final Color background;

  /// Text color on [background].
  final Color foreground;

  /// Icon/indicator color; the saturated tone hue.
  final Color iconColor;

  /// Outline color; banners draw it at reduced opacity.
  final Color border;

  /// Default glyph for the tone; null for neutral.
  final IconData? icon;
}
