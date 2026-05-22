import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

// ─── Confetti particle model ──────────────────────────────────────────────────

/// A single confetti particle used in the burst animation.
class _Particle {
  _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.radius,
  });

  /// Upward angle in radians from vertical (negative = left, positive = right).
  final double angle;
  final double speed;
  final Color color;
  final double radius;
}

// ─── Confetti painter ─────────────────────────────────────────────────────────

/// Paints 3–5 small circles bursting upward from the center-bottom of the
/// canvas over [progress] (0.0 → 1.0), then fading out.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final origin = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Ease-out position curve so they decelerate upward.
      final t = 1 - math.pow(1 - progress, 2).toDouble();
      final dist = p.speed * t;

      final dx = math.sin(p.angle) * dist;
      final dy = -math.cos(p.angle) * dist; // negative = upward

      // Fade in quickly, then fade out in the last 40%.
      final opacity = progress < 0.2
          ? progress / 0.2
          : math.max(0.0, 1.0 - (progress - 0.2) / 0.8);

      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.drawCircle(
        origin.translate(dx, dy),
        p.radius * (1 - progress * 0.3), // slight shrink over time
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ─── Animated check icon ──────────────────────────────────────────────────────

/// Draws a custom check circle with an animated stroke.
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.strokeProgress, required this.color});

  final double strokeProgress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    // Outer circle stroke
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - 0.9, circlePaint);

    if (strokeProgress <= 0) return;

    // Animate the check mark stroke
    final checkPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Check path: down-left leg then up-right leg.
    // Relative to a 18x18 canvas centered.
    final s = size.width;
    final leg1Start = Offset(s * 0.22, s * 0.52);
    final leg1End = Offset(s * 0.42, s * 0.72);
    final leg2End = Offset(s * 0.78, s * 0.30);

    // Split progress across two segments (40% / 60%).
    const split = 0.4;
    final path = Path();
    path.moveTo(leg1Start.dx, leg1Start.dy);

    if (strokeProgress <= split) {
      final t = strokeProgress / split;
      final mid = Offset.lerp(leg1Start, leg1End, t)!;
      path.lineTo(mid.dx, mid.dy);
    } else {
      path.lineTo(leg1End.dx, leg1End.dy);
      final t = (strokeProgress - split) / (1 - split);
      final mid = Offset.lerp(leg1End, leg2End, t)!;
      path.lineTo(mid.dx, mid.dy);
    }

    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.strokeProgress != strokeProgress || old.color != color;
}

// ─── Public widget ────────────────────────────────────────────────────────────

/// A todo list item widget that animates when marked complete.
///
/// When [isCompleted] transitions from `false` to `true`, the checkbox
/// plays a scale bounce (1.0 → 1.3 → 1.0 with [Curves.easeOutBack]) while
/// a stroke-draw animation completes the check mark.  Simultaneously, 5 tiny
/// confetti particles burst upward and fade over ~600 ms.
///
/// When [isCompleted] is `true` on first build (e.g. restored state) the
/// widget renders the completed state without animation.
class ZenTodoItem extends StatefulWidget {
  const ZenTodoItem({
    required this.content,
    required this.isCompleted,
    super.key,
    this.priority,
    this.onToggle,
  });

  final String content;
  final bool isCompleted;

  /// Optional priority label: 'low', 'medium', 'high', 'critical'.
  final String? priority;

  /// Called when the user taps the checkbox.
  final VoidCallback? onToggle;

  @override
  State<ZenTodoItem> createState() => _ZenTodoItemState();
}

class _ZenTodoItemState extends State<ZenTodoItem>
    with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 600);

  late AnimationController _controller;

  /// Scale animation for the checkbox: 1.0 → 1.3 → 1.0.
  late Animation<double> _scaleAnim;

  /// Check-stroke draw progress: 0.0 → 1.0.
  late Animation<double> _strokeAnim;

  /// Confetti particle burst progress: 0.0 → 1.0.
  late Animation<double> _confettiAnim;

  late List<_Particle> _particles;

  bool _wasCompleted = false;

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.isCompleted;
    _particles = _buildParticles();

    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_controller);

    _strokeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _confettiAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(ZenTodoItem old) {
    super.didUpdateWidget(old);
    if (!_wasCompleted && widget.isCompleted) {
      // Newly completed — rebuild particles and play animation.
      _particles = _buildParticles();
      _controller.forward(from: 0);
    }
    _wasCompleted = widget.isCompleted;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Particle> _buildParticles() {
    final rng = math.Random();
    const particleColors = [
      AppColors.success,
      Color(0xFF34AADC), // sky blue
      Color(0xFFFFCC00), // amber
      Color(0xFFFF6B6B), // coral
      Color(0xFF5AC8FA), // light blue
    ];
    return List.generate(5, (i) {
      // Spread particles in a ±45° arc pointing upward.
      final angle = (rng.nextDouble() - 0.5) * math.pi * 0.5;
      return _Particle(
        angle: angle,
        speed: 14 + rng.nextDouble() * 10,
        color: particleColors[i % particleColors.length],
        radius: 2.5 + rng.nextDouble() * 1.5,
      );
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkColor = widget.isCompleted
        ? AppColors.success
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCheckbox(checkColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _buildLabel(theme)),
        ],
      ),
    );
  }

  Widget _buildCheckbox(Color checkColor) {
    return GestureDetector(
      onTap: widget.onToggle,
      child: SizedBox(
        width: 22,
        height: 22,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final scale = _controller.isAnimating ? _scaleAnim.value : 1.0;
            final strokeProgress = widget.isCompleted
                ? (_controller.isAnimating ? _strokeAnim.value : 1.0)
                : 0.0;
            final confettiProgress = _controller.isAnimating
                ? _confettiAnim.value
                : 0.0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Confetti layer (outside the checkbox bounds)
                Positioned.fill(
                  child: OverflowBox(
                    maxWidth: 60,
                    maxHeight: 60,
                    child: CustomPaint(
                      size: const Size(60, 60),
                      painter: _ConfettiPainter(
                        progress: confettiProgress,
                        particles: _particles,
                      ),
                    ),
                  ),
                ),
                // Checkbox with scale + stroke-draw
                Center(
                  child: Transform.scale(
                    scale: scale,
                    child: widget.isCompleted
                        ? CustomPaint(
                            size: const Size(18, 18),
                            painter: _CheckPainter(
                              strokeProgress: strokeProgress,
                              color: AppColors.success,
                            ),
                          )
                        : Icon(
                            Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: checkColor,
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(ThemeData theme) {
    final textColor = widget.isCompleted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    final decoration =
        widget.isCompleted ? TextDecoration.lineThrough : TextDecoration.none;

    return Text(
      widget.content,
      style: theme.textTheme.bodySmall?.copyWith(
        color: textColor,
        decoration: decoration,
        decorationColor: textColor,
      ),
    );
  }
}
