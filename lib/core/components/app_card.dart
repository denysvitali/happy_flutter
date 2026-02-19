import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A themed card container with consistent shadow and padding.
///
/// Renders a [Material] surface with:
/// - 12 px border radius
/// - Subtle border (`onSurface` at 8 % opacity)
/// - Soft drop-shadow (offset 0,2 – blur 8 – black12)
/// - White / dark-surface background from [ColorScheme.surface]
///
/// When [onTap] is provided, the card wraps [child] in an [InkWell]
/// with matching radius and optional haptic feedback.
class AppCard extends StatelessWidget {
  /// Creates a card.
  const AppCard({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.margin,
    this.haptic = true,
  });

  /// The widget to display inside the card.
  final Widget child;

  /// Internal padding applied to [child].
  ///
  /// Defaults to `EdgeInsets.all(16)` when null.
  final EdgeInsets? padding;

  /// Called when the card is tapped. Adds an InkWell when set.
  final VoidCallback? onTap;

  /// External margin around the card.
  final EdgeInsets? margin;

  /// Whether to trigger [HapticFeedback.lightImpact] on tap.
  ///
  /// Defaults to true. Has no effect when [onTap] is null.
  final bool haptic;

  static const _radius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectivePadding =
        padding ?? const EdgeInsets.all(16);

    final borderColor = cs.onSurface.withValues(alpha: 0.08);

    Widget content = Padding(
      padding: effectivePadding,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: () {
          if (haptic) HapticFeedback.lightImpact();
          onTap!();
        },
        borderRadius: _radius,
        child: content,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: _radius,
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: content,
      ),
    );
  }
}
