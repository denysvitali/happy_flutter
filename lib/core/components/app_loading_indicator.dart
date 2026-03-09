import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Centered loading indicator using the theme primary color.
///
/// Wraps [CircularProgressIndicator] in a [Center] widget.
/// Use [size] to constrain the indicator's bounding box and
/// [strokeWidth] to control line thickness.
///
/// The default [size] of [AppSpacing.xxl] (24 px) aligns the indicator
/// to the design-token grid.
class AppLoadingIndicator extends StatelessWidget {
  /// Creates a centered loading indicator.
  const AppLoadingIndicator({
    super.key,
    this.size = AppSpacing.xxl,
    this.strokeWidth = 2.5,
    this.color,
    this.label,
  });

  /// The width and height of the indicator's bounding box.
  ///
  /// Defaults to [AppSpacing.xxl] (24 px).
  final double size;

  /// The thickness of the circular arc.
  final double strokeWidth;

  /// The indicator color.
  ///
  /// Defaults to [ColorScheme.primary] when null.
  final Color? color;

  /// Optional text label shown below the spinner.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor =
        color ?? theme.colorScheme.primary;

    final spinner = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        strokeCap: StrokeCap.round,
        valueColor:
            AlwaysStoppedAnimation<Color>(effectiveColor),
      ),
    );

    if (label == null) {
      return Center(child: spinner);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          spinner,
          const SizedBox(height: AppSpacing.md),
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
