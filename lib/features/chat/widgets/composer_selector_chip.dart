import 'package:flutter/material.dart';

import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Shared metrics for the composer's model / approvals / profile selectors.
abstract final class ComposerChipMetrics {
  static const double height = 32;
  static const double paddingStart = AppSpacing.md;
  static const double paddingEnd = AppSpacing.sm;
  static const double paddingEndNoChevron = AppSpacing.md;
  static const double iconSize = AppIconSize.md;
  static const double iconLabelGap = AppSpacing.xsm;
  static const double labelChevronGap = AppSpacing.xxs;
  static const double chevronSize = AppIconSize.md;
  static const double labelFontSize = AppFontSize.sm;
}

/// Compact, neutral pill showing a composer setting's current value —
/// e.g. `Ask ▾` or `Opus ▾`; the setting's name lives in its semantics.
///
/// Routine configuration stays quiet: a hairline outline and a
/// regular-weight value. Only [warning] states (settings that
/// let the agent act without confirmation) get color and a leading icon, so
/// the one setting that deserves attention is the one that stands out.
///
/// The visual pill is [ComposerChipMetrics.height] tall; the tap target is
/// expanded to [AppTouchTarget.min]. The ink ripple is clipped to the pill.
class ComposerSelectorChip extends StatelessWidget {
  const ComposerSelectorChip({
    required this.label,
    this.icon,
    this.warning = false,
    this.onTap,
    this.width,
    this.labelMaxWidth,
    super.key,
  });

  /// The current value, e.g. `Opus`.
  final String label;

  /// Optional leading icon; shown in [warning] color when [warning].
  final IconData? icon;
  final bool warning;

  /// Null renders a non-interactive chip without the dropdown chevron.
  final VoidCallback? onTap;
  final double? width;
  final double? labelMaxWidth;

  static const _shape = StadiumBorder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final enabled = onTap != null;

    final valueColor = warning
        ? AppColors.warning
        : enabled
        ? cs.onSurface
        : cs.onSurfaceVariant;
    final mutedColor = warning
        ? AppColors.warning.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;
    final background = warning
        ? AppColors.warning.withValues(alpha: 0.10)
        : cs.onSurface.withValues(alpha: 0.04);
    final borderColor = warning
        ? AppColors.warning.withValues(alpha: 0.45)
        : appCs.glassBorder;

    // Pin the regular Inter file: the theme binds each weight to its own
    // family, so a weight override alone keeps the medium face and the
    // label reads as bold.
    final base = (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      fontFamily: 'Inter_regular',
      fontSize: ComposerChipMetrics.labelFontSize,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.25,
    );

    Widget text = Text(
      label,
      style: base.copyWith(color: valueColor),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textHeightBehavior: const TextHeightBehavior(
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
    if (labelMaxWidth != null) {
      text = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: labelMaxWidth!),
        child: text,
      );
    } else if (width != null) {
      text = Flexible(child: text);
    }

    final chip = Material(
      color: background,
      shape: _shape.copyWith(
        side: BorderSide(color: borderColor, width: AppBorder.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: _shape,
        child: Container(
          width: width,
          height: ComposerChipMetrics.height,
          padding: EdgeInsetsDirectional.only(
            start: icon == null
                ? ComposerChipMetrics.paddingStart
                : ComposerChipMetrics.paddingEnd,
            end: enabled
                ? ComposerChipMetrics.paddingEnd
                : ComposerChipMetrics.paddingEndNoChevron,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: ComposerChipMetrics.iconSize,
                  color: valueColor,
                ),
                const SizedBox(width: ComposerChipMetrics.iconLabelGap),
              ],
              text,
              if (enabled) ...[
                const SizedBox(width: ComposerChipMetrics.labelChevronGap),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: ComposerChipMetrics.chevronSize,
                  color: mutedColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // The outer detector widens the hit area to the minimum touch target;
    // taps on the pill itself are won by the inner InkWell (ripple).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      excludeFromSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppTouchTarget.min,
          minWidth: AppTouchTarget.min,
        ),
        // widthFactor/heightFactor keep Align intrinsic-sized so a parent
        // Row places chips on one line; bare Align expands to full width.
        child: Align(widthFactor: 1, heightFactor: 1, child: chip),
      ),
    );
  }
}

/// Icon-only toolbar control that matches [ComposerSelectorChip]'s height,
/// outline and fill, so utilities (attach, options, expand) line up with
/// the setting pills instead of floating as bare glyphs.
class ComposerIconChip extends StatelessWidget {
  const ComposerIconChip({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    const shape = CircleBorder();
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          excludeFromSemantics: true,
          child: SizedBox.square(
            dimension: AppTouchTarget.min,
            child: Center(
              child: Material(
                color: cs.onSurface.withValues(alpha: 0.04),
                shape: shape.copyWith(
                  side: BorderSide(
                    color: appCs.glassBorder,
                    width: AppBorder.hairline,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  customBorder: shape,
                  child: SizedBox.square(
                    dimension: ComposerChipMetrics.height,
                    child: Icon(
                      icon,
                      size: AppIconSize.lg,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
