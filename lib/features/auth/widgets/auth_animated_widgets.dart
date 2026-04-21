import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/components/app_loading_indicator.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Wraps [child] in a subtly animated two-hue gradient
/// that shifts slowly to add depth to the landing screen.
class AnimatedGradientBackground extends StatefulWidget {
  const AnimatedGradientBackground({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surface;
    final hintA =
        Color.lerp(base, scheme.primary, 0.03)!;
    final hintB =
        Color.lerp(base, scheme.primary, 0.07)!;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final t =
            (math.sin(_ctrl.value * math.pi) + 1) / 2;
        final topColor =
            Color.lerp(hintA, hintB, t)!;
        final bottomColor =
            Color.lerp(hintB, hintA, t)!;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topColor, bottomColor],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A coloured notice bar for errors, warnings, and
/// success messages. Slides in with animation.
class StatusBanner extends StatefulWidget {
  const StatusBanner({
    required this.message,
    required this.color,
    required this.isLoading,
    required this.onDismiss,
    super.key,
    this.icon,
  });

  final IconData? icon;
  final String message;
  final Color color;
  final bool isLoading;
  final VoidCallback? onDismiss;

  @override
  State<StatusBanner> createState() =>
      _StatusBannerState();
}

class _StatusBannerState extends State<StatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );
    _slide = Tween<double>(begin: -0.15, end: 0.0)
        .animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: AppCurve.enter,
      ),
    );
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: AppCurve.enter,
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError =
        widget.color == scheme.error ||
            (widget.color.r * 255.0).round().clamp(0, 255) >
                200;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        return FractionalTranslation(
          translation: Offset(0, _slide.value),
          child: Opacity(
            opacity: _fade.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        margin: const EdgeInsets.only(
          bottom: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: widget.color.withValues(
            alpha: AppOpacity.faint,
          ),
          border: Border.all(
            color: widget.color.withValues(
              alpha: AppOpacity.medium,
            ),
          ),
          borderRadius: BorderRadius.circular(
            AppRadius.md,
          ),
        ),
        child: Row(
          children: [
            if (widget.isLoading)
              AppLoadingIndicator(
                size: 18,
                strokeWidth: 2,
                color: widget.color,
              )
            else if (widget.icon != null)
              Container(
                width: AppSpacing.xxxl,
                height: AppSpacing.xxxl,
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: AppOpacity.subtle,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 18,
                ),
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isError)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: AppSpacing.xxs,
                      ),
                      child: Text(
                        context.l10n.commonError,
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                          color: widget.color,
                          fontSize: AppFontSize.sm,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  Text(
                    widget.message,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: widget.color
                          .withValues(
                        alpha: AppOpacity.high,
                      ),
                      fontSize: AppFontSize.md,
                      height: AppLineHeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onDismiss != null)
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: AppSpacing.lg,
                ),
                color: widget.color.withValues(
                  alpha: AppOpacity.half,
                ),
                onPressed: widget.onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: AppTouchTarget.min,
                  minHeight: AppTouchTarget.min,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small dot that pulses in opacity to indicate
/// an ongoing waiting state.
class PulsingDot extends StatefulWidget {
  const PulsingDot({required this.color, super.key});

  final Color color;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final opacity = 0.4 + (_ctrl.value * 0.6);
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: Container(
        width: AppSpacing.sm,
        height: AppSpacing.sm,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
