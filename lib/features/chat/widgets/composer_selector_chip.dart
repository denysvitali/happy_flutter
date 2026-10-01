import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_inline_row.dart';

import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Shared metrics for the composer's model / approvals / profile selectors.
abstract final class ComposerChipMetrics {
  static const double height = 24;
  static const double paddingStart = AppSpacing.smd;
  static const double paddingStartWithIcon = AppSpacing.xsm;
  static const double paddingEnd = AppSpacing.xs;
  static const double paddingEndNoChevron = AppSpacing.smd;
  static const double iconSize = AppIconSize.xs;
  static const double iconLabelGap = AppSpacing.xxs;
  static const double labelChevronGap = 0;
  static const double chevronSize = AppIconSize.sm;
  static const double labelFontSize = AppFontSize.xs;
}

/// Compact, neutral pill showing a composer setting's current value —
/// e.g. `Default ▾` or `Opus ▾`; the setting's name lives in its semantics.
///
/// Routine configuration stays quiet: a hairline outline and a small
/// 12sp medium-weight value (the draft above it is 14sp). Only [warning]
/// states (settings that let the agent act without confirmation) get color
/// and a leading icon, so the one setting that deserves attention is the one
/// that stands out.
///
/// The visual pill is [ComposerChipMetrics.height] tall; the tap target is
/// expanded to [AppTouchTarget.min]. The ink ripple is clipped to the pill.
class ComposerSelectorChip extends StatelessWidget {
  const ComposerSelectorChip({
    required this.label,
    this.icon,
    this.warning = false,
    this.warningColor,
    this.onTap,
    this.bordered = true,
    this.width,
    this.labelMaxWidth,
    super.key,
  });

  /// Draws the hairline outline; false leaves just the tinted fill.
  final bool bordered;

  /// The current value, e.g. `Opus`.
  final String label;

  /// Optional leading icon; shown in [warning] color when [warning].
  final IconData? icon;
  final bool warning;

  /// Overrides [AppColors.warning] so the chip matches the setting's own
  /// color elsewhere (e.g. the permission picker).
  final Color? warningColor;

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
    final accent = warningColor ?? AppColors.warning;

    // Quiet by default: the value is muted grey; only a warning gets color.
    final valueColor = warning ? accent : cs.onSurfaceVariant;
    final mutedColor = warning
        ? accent.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;
    final background = warning
        ? accent.withValues(alpha: 0.10)
        : cs.onSurface.withValues(alpha: 0.04);
    final borderColor = warning
        ? accent.withValues(alpha: 0.45)
        : appCs.glassBorder;

    final base = AppInlineText.chip(context);

    Widget text = Text(
      label,
      // Same size and weight in every state: the warning state is carried by
      // color and the leading icon, never by heavier type (an all-caps label
      // such as YOLO already reads larger than lowercase neighbours).
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
      shape: bordered
          ? _shape.copyWith(
              side: BorderSide(color: borderColor, width: AppBorder.hairline),
            )
          : _shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: _shape,
        child: Container(
          width: width,
          constraints: const BoxConstraints(
            minHeight: ComposerChipMetrics.height,
          ),
          padding: EdgeInsetsDirectional.only(
            start: icon == null
                ? ComposerChipMetrics.paddingStart
                : ComposerChipMetrics.paddingStartWithIcon,
            top: 0,
            bottom: 0,
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
                  color: warning ? accent : cs.onSurfaceVariant,
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
                      size: AppIconSize.sm,
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
