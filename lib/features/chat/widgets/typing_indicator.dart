import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_tokens.dart';

/// Animated "thinking" indicator shown at the bottom of the chat
/// while the agent is working.
///
/// Instead of the generic three bouncing dots this renders a small
/// living **aurora orb**: a softly morphing blob filled with a
/// rotating brand gradient, wrapped in a drifting glow halo, with a
/// bright spark glinting around its rim. The motion is smooth and
/// continuous (no vertical jumping) and the palette comes from the
/// theme's Aurora accent gradient ([AppColorScheme.accentGradient]) so
/// the orb matches the activity chrome's breathing dot exactly — one
/// accent language for everything that means "the agent is alive".
///
/// A single [AnimationController] drives every animated property, and
/// `MediaQuery.disableAnimations` swaps the whole painter out for one
/// static accent dot — no ticker runs at all.
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
  static const double _staticDotSize = 13;

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
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Aurora accent pair for this brightness, with a scheme-derived
  /// fallback for bare-MaterialApp test hosts that register no
  /// [AppColorScheme] extension.
  List<Color> _accentColors(ThemeData theme) {
    return theme.extension<AppColorScheme>()?.accentGradient ??
        [theme.colorScheme.primary, theme.colorScheme.secondary];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentColors(theme);

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
            // Reduced motion: one static accent dot in the same box —
            // zero tickers, zero painters, same footprint.
            child: (_animationsDisabled ?? false)
                ? Center(
                    child: Container(
                      width: _staticDotSize,
                      height: _staticDotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: accent),
                      ),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _AuroraOrbPainter(
                          progress: _controller.value,
                          accent: accent,
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
/// (0..1) so a single animation controller is enough. [accent] is the
/// theme's Aurora pair; the old primary/tertiary mix is gone so the
/// orb and the thinking bar share one gradient identity.
class _AuroraOrbPainter extends CustomPainter {
  _AuroraOrbPainter({required this.progress, required this.accent});

  final double progress;
  final List<Color> accent;

  static const double _baseRadius = 6.5;
  static const int _blobPoints = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final first = accent.first;
    final last = accent.last;
    final t = progress;
    final tau = 2 * math.pi;
    final center = Offset(size.width / 2, size.height / 2);

    // Breathing scale for the whole orb.
    final breathe = 1 + 0.05 * math.sin(tau * t * 1.3);
    final radius = _baseRadius * breathe;

    _paintGlow(canvas, center, t, tau, first, last);
    _paintBlob(canvas, center, radius, t, tau, first, last);
    _paintSpark(canvas, center, radius, t, tau);
  }

  void _paintGlow(
    Canvas canvas,
    Offset center,
    double t,
    double tau,
    Color first,
    Color last,
  ) {
    final pulse = 12 + 2.5 * math.sin(tau * t);

    // Primary halo, centred on the orb.
    final primaryGlow = RadialGradient(
      colors: [first.withValues(alpha: 0.30), first.withValues(alpha: 0)],
    );
    canvas.drawCircle(
      center,
      pulse,
      Paint()
        ..shader = primaryGlow.createShader(
          Rect.fromCircle(center: center, radius: pulse),
        ),
    );

    // Second accent halo, drifting around the centre for an aurora feel.
    final drift = Offset(math.cos(tau * t) * 3, math.sin(tau * t * 0.8) * 3);
    final secondaryCenter = center + drift;
    final secondaryRadius = pulse * 0.8;
    final secondaryGlow = RadialGradient(
      colors: [last.withValues(alpha: 0.24), last.withValues(alpha: 0)],
    );
    canvas.drawCircle(
      secondaryCenter,
      secondaryRadius,
      Paint()
        ..shader = secondaryGlow.createShader(
          Rect.fromCircle(center: secondaryCenter, radius: secondaryRadius),
        ),
    );
  }

  void _paintBlob(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    double tau,
    Color first,
    Color last,
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
    final lead = _midpoint(points.last, points.first);
    path.moveTo(lead.dx, lead.dy);
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final mid = _midpoint(current, next);
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();

    // Rotating accent gradient fill (smooth four-stop loop).
    final mid = Color.lerp(first, last, 0.5)!;
    final gradient = SweepGradient(
      transform: GradientRotation(tau * t),
      colors: [first, mid, last, mid],
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
    return old.progress != progress || !old.accent.sameColors(accent);
  }
}

extension on List<Color> {
  bool sameColors(List<Color> other) {
    if (identical(this, other)) return true;
    if (length != other.length) return false;
    for (var i = 0; i < length; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }
}
