import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// A themed card container with consistent shadow and padding.
///
/// Renders a [Material] surface with:
/// - [AppRadius.lg] (16 px) border radius
/// - Subtle border (`onSurface` at 8 % opacity)
/// - Soft drop-shadow via [AppShadow.card]
/// - White / dark-surface background from [ColorScheme.surface]
///
/// When [onTap] is provided, the card wraps [child] in an [InkWell]
/// with matching radius, optional haptic feedback, and a smooth
/// [AnimatedScale] press animation (scales to 0.98 on press).
class AppCard extends StatefulWidget {
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
  /// Defaults to `EdgeInsets.all(AppSpacing.lg)` when null.
  final EdgeInsets? padding;

  /// Called when the card is tapped. Adds an InkWell when set.
  final VoidCallback? onTap;

  /// External margin around the card.
  final EdgeInsets? margin;

  /// Whether to trigger [HapticFeedback.lightImpact] on tap.
  ///
  /// Defaults to true. Has no effect when [onTap] is null.
  final bool haptic;

  static const _radius =
      BorderRadius.all(Radius.circular(AppRadius.lg));

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectivePadding =
        widget.padding ?? const EdgeInsets.all(AppSpacing.lg);

    final borderColor = cs.onSurface.withValues(alpha: 0.08);

    final Widget content = Padding(
      padding: effectivePadding,
      child: widget.child,
    );

    // Wrap in Material so InkWell splashes render correctly.
    // DecoratedBox handles the visual decoration (shadow, border, bg)
    // outside the clipping region so box shadows are not clipped.
    final Widget inner = ClipRRect(
      clipBehavior: Clip.hardEdge,
      borderRadius: AppCard._radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: AppCard._radius,
          border: Border.all(color: borderColor),
        ),
        child: widget.onTap != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (widget.haptic) HapticFeedback.lightImpact();
                    widget.onTap!();
                  },
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) => setState(() => _pressed = false),
                  onTapCancel: () => setState(() => _pressed = false),
                  splashColor: cs.primary.withValues(alpha: 0.08),
                  highlightColor: cs.primary.withValues(alpha: 0.04),
                  splashFactory: InkRipple.splashFactory,
                  child: content,
                ),
              )
            : content,
      ),
    );

    // Box shadows must live outside ClipRRect to be visible.
    final card = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: AppCard._radius,
        boxShadow: AppShadow.card,
      ),
      child: inner,
    );

    if (widget.onTap == null) return card;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      child: card,
    );
  }
}
