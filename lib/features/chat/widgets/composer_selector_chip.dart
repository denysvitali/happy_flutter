import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Shared metrics for the composer's permission / model / profile chips.
///
/// Material 3 assist-chip proportions. Gaps are tuned so the *visible* ink
/// spacing is an even ~8dp: the 16dp leading icons carry ~1.5dp of side
/// bearing and the chevron glyph ~4.5dp, so the chevron sits 2dp after the
/// label and 4dp before the edge.
abstract final class ComposerChipMetrics {
  static const double height = 32;
  static const double radius = AppRadius.sm;
  static const double paddingStart = AppSpacing.sm;
  static const double paddingEnd = AppSpacing.xs;
  static const double paddingEndNoChevron = AppSpacing.smd;
  static const double iconSize = AppIconSize.md;
  static const double iconLabelGap = AppSpacing.xsm;
  static const double labelChevronGap = AppSpacing.xxs;
  static const double chevronSize = AppIconSize.md;
  static const double labelFontSize = AppFontSize.xs;
}

/// Compact rounded-rectangle selector chip used in the chat composer.
///
/// The visual chip is [ComposerChipMetrics.height] tall; the tap target is
/// expanded to [AppTouchTarget.min]. The ink ripple is clipped to the chip's
/// rounded rectangle, not the enlarged hit area.
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

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(ComposerChipMetrics.radius)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // bodySmall resolves to the regular Inter face; label styles are bound
    // to the medium face and read as bold at this size.
    final labelStyle = (theme.textTheme.bodySmall ?? const TextStyle())
        .copyWith(
          fontSize: ComposerChipMetrics.labelFontSize,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          height: 16 / 12,
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
