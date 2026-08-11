import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Animated "thinking" indicator shown at the bottom of the chat
/// while the agent is working.
///
/// Instead of the generic three bouncing dots this renders a small
/// living **aurora orb**: a softly morphing blob filled with a
/// rotating brand gradient, wrapped in a drifting glow halo, with a
/// bright spark glinting around its rim. The motion is smooth and
/// continuous (no vertical jumping) and the palette is derived from
/// the theme's [ColorScheme.primary] / [ColorScheme.tertiary] so it
/// stays on-brand in both light and dark mode.
///
/// A single [AnimationController] drives every animated property.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _animationsDisabled;

  // Footprint of the orb plus its glow bleed. Kept close to the old
  // bubble's box so the chat layout does not shift.
  static const double _boxWidth = 46;
  static const double _boxHeight = 30;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _controller
        ..stop()
        ..value = 0.5;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _boxWidth,
            height: _boxHeight,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AuroraOrbPainter(
                    progress: _controller.value,
                    primary: scheme.primary,
                    tertiary: scheme.tertiary,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the morphing gradient orb, its drifting glow and the
/// orbiting spark. All motion is a pure function of [progress]
/// (0..1) so a single animation controller is enough.
class _AuroraOrbPainter extends CustomPainter {
  _AuroraOrbPainter({
    required this.progress,
    required this.primary,
    required this.tertiary,
  });

  final double progress;
  final Color primary;
  final Color tertiary;

  static const double _baseRadius = 6.5;
  static const int _blobPoints = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final tau = 2 * math.pi;
    final center = Offset(size.width / 2, size.height / 2);

    // Breathing scale for the whole orb.
    final breathe = 1 + 0.05 * math.sin(tau * t * 1.3);
    final radius = _baseRadius * breathe;

    _paintGlow(canvas, center, t, tau);
    _paintBlob(canvas, center, radius, t, tau);
    _paintSpark(canvas, center, radius, t, tau);
  }

  void _paintGlow(Canvas canvas, Offset center, double t, double tau) {
    final pulse = 12 + 2.5 * math.sin(tau * t);

    // Primary halo, centred on the orb.
    final primaryGlow = RadialGradient(
      colors: [primary.withValues(alpha: 0.30), primary.withValues(alpha: 0)],
    );
    canvas.drawCircle(
      center,
      pulse,
      Paint()
        ..shader = primaryGlow.createShader(
          Rect.fromCircle(center: center, radius: pulse),
        ),
    );

    // Tertiary halo, drifting around the centre for an aurora feel.
    final drift = Offset(math.cos(tau * t) * 3, math.sin(tau * t * 0.8) * 3);
    final tertiaryCenter = center + drift;
    final tertiaryRadius = pulse * 0.8;
    final tertiaryGlow = RadialGradient(
      colors: [tertiary.withValues(alpha: 0.24), tertiary.withValues(alpha: 0)],
    );
    canvas.drawCircle(
      tertiaryCenter,
      tertiaryRadius,
      Paint()
        ..shader = tertiaryGlow.createShader(
          Rect.fromCircle(center: tertiaryCenter, radius: tertiaryRadius),
        ),
    );
  }

  void _paintBlob(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double tau,
  ) {
    // Sample a wobbly radius around the circle so the blob feels
    // liquid rather than a perfect disc.
    final points = List<Offset>.generate(_blobPoints, (i) {
      final angle = (i / _blobPoints) * tau;
      final wobble =
          1 +
          0.14 * math.sin(3 * angle + tau * t) +
          0.06 * math.sin(2 * angle - tau * t * 0.7);
      final r = radius * wobble;
      return Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    });

    final path = Path();
    final first = _midpoint(points.last, points.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final mid = _midpoint(current, next);
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();

    // Rotating brand gradient fill (smooth four-stop loop).
    final mid = Color.lerp(primary, tertiary, 0.5)!;
    final gradient = SweepGradient(
      transform: GradientRotation(tau * t),
      colors: [primary, mid, tertiary, mid],
      stops: const [0, 0.33, 0.66, 1],
    );
    final rect = Rect.fromCircle(center: center, radius: radius * 1.2);
    canvas.drawPath(
      path,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill,
    );
  }

  void _paintSpark(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double tau,
  ) {
    final angle = tau * ((t * 1.6) % 1.0);
    final orbit = radius * 0.82;
    final pos = Offset(
      center.dx + orbit * math.cos(angle),
      center.dy + orbit * math.sin(angle),
    );

    // Soft glint halo with a crisp core on top.
    const sparkRadius = 2.6;
    final glint = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0),
      ],
    );
    canvas
      ..drawCircle(
        pos,
        sparkRadius,
        Paint()
          ..shader = glint.createShader(
            Rect.fromCircle(center: pos, radius: sparkRadius),
          ),
      )
      ..drawCircle(
        pos,
        1.0,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
  }

  Offset _midpoint(Offset a, Offset b) =>
      Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  @override
  bool shouldRepaint(_AuroraOrbPainter old) {
    return old.progress != progress ||
        old.primary != primary ||
        old.tertiary != tertiary;
  }
}
