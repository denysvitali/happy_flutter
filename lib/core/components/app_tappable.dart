import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Material-style tap target with ripple effect and optional haptic
/// feedback.
///
/// Wraps [child] in an [InkWell] with the given [borderRadius].
/// When [haptic] is true (the default), a light impact is triggered
/// via [HapticFeedback.lightImpact] on each tap.
///
/// The splash and highlight animations run at [AppDuration.fast]
/// (150 ms) for a snappy micro-interaction feel.
class AppTappable extends StatelessWidget {
  /// Creates a tappable wrapper.
  const AppTappable({
    required this.child,
    super.key,
    this.onTap,
    this.borderRadius,
    this.haptic = true,
  });

  /// The widget below this widget in the tree.
  final Widget child;

  /// Called when the widget is tapped.
  final VoidCallback? onTap;

  /// The border radius of the ripple.
  ///
  /// Defaults to `BorderRadius.circular(AppRadius.sm)` when null.
  final BorderRadius? borderRadius;

  /// Whether to trigger haptic feedback on tap.
  ///
  /// Defaults to true.
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ?? BorderRadius.circular(AppRadius.sm);

    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              if (haptic) HapticFeedback.lightImpact();
              onTap!();
            },
      borderRadius: radius,
      splashColor: Theme.of(context)
          .colorScheme
          .primary
          .withValues(alpha: 0.08),
      highlightColor: Theme.of(context)
          .colorScheme
          .primary
          .withValues(alpha: 0.04),
      splashFactory: InkRipple.splashFactory,
      child: child,
    );
  }
}
