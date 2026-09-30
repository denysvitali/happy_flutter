import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Shared metrics for the composer's permission / model / profile chips.
///
/// Compact pill: 11sp regular label, 14dp icons. The chevron glyph carries
/// ~4dp of side bearing, so it sits 2dp after the label.
abstract final class ComposerChipMetrics {
  static const double height = 28;
  static const double paddingStart = AppSpacing.smd;
  static const double paddingEnd = AppSpacing.sm;
  static const double paddingEndNoChevron = AppSpacing.smd;
  static const double iconSize = AppIconSize.sm;
  static const double iconLabelGap = AppSpacing.xs;
  static const double labelChevronGap = AppSpacing.xxs;
  static const double chevronSize = AppIconSize.sm;
  static const double labelFontSize = AppFontSize.xxs;
}

/// Compact pill selector chip used in the chat composer.
///
/// The visual chip is [ComposerChipMetrics.height] tall; the tap target is
/// expanded to [AppTouchTarget.min]. The ink ripple is clipped to the chip's
/// pill, not the enlarged hit area.
class ComposerSelectorChip extends StatelessWidget {
  const ComposerSelectorChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.borderColor,
    this.chevronColor,
    this.onTap,
    this.width,
    this.labelMaxWidth,
    super.key,
  });

  final IconData icon;
  final String label;

  /// Icon and label color.
  final Color foreground;
  final Color background;
  final Color borderColor;

  /// Trailing dropdown chevron color; `null` hides the chevron.
  final Color? chevronColor;
  final VoidCallback? onTap;
  final double? width;
  final double? labelMaxWidth;

  static const _shape = StadiumBorder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Pin the regular Inter file: the theme binds each weight to its own
    // family, so a weight override alone keeps the medium face and the
    // label reads as bold.
    final labelStyle = (theme.textTheme.bodySmall ?? const TextStyle())
        .copyWith(
          fontFamily: 'Inter_regular',
          fontSize: ComposerChipMetrics.labelFontSize,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          height: 1.2,
          color: foreground,
        );
    final hasChevron = chevronColor != null;

    Widget text = Text(
      label,
      style: labelStyle,
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
            start: ComposerChipMetrics.paddingStart,
            end: hasChevron
                ? ComposerChipMetrics.paddingEnd
                : ComposerChipMetrics.paddingEndNoChevron,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: ComposerChipMetrics.iconSize, color: foreground),
              const SizedBox(width: ComposerChipMetrics.iconLabelGap),
              text,
              if (hasChevron) ...[
                const SizedBox(width: ComposerChipMetrics.labelChevronGap),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: ComposerChipMetrics.chevronSize,
                  color: chevronColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // The outer detector widens the hit area to the minimum touch target;
    // taps on the chip itself are won by the inner InkWell (ripple).
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
        // Wrap places chips on one row; bare Align expands to full width.
        child: Align(widthFactor: 1, heightFactor: 1, child: chip),
      ),
    );
  }
}
