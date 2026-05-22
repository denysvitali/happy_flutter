import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Animated viewfinder corner brackets drawn over a QR code.
///
/// Four L-shaped corner brackets pulse with a subtle
/// opacity/scale cycle while [isActive] is true, indicating
/// the app is polling for scan approval. The brackets fade
/// out when [isActive] becomes false.
class QRViewfinderOverlay extends StatefulWidget {
  const QRViewfinderOverlay({
    required this.size,
    required this.isActive,
    super.key,
    this.color,
    this.bracketLength = 20.0,
    this.strokeWidth = 2.5,
  });

  /// Total width/height of the area to cover (matches QR
  /// container including padding).
  final double size;

  /// Whether the polling animation should run.
  final bool isActive;

  /// Bracket color — defaults to [ColorScheme.primary].
  final Color? color;

  /// Length of each arm of the L-shaped corner bracket.
  final double bracketLength;

  /// Stroke thickness of the bracket lines.
  final double strokeWidth;

  @override
  State<QRViewfinderOverlay> createState() =>
      _QRViewfinderOverlayState();
}

class _QRViewfinderOverlayState
    extends State<QRViewfinderOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.55)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.96, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.96)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(QRViewfinderOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.animateTo(0.0, duration: AppDuration.normal);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: _scale.value,
          child: Opacity(
            opacity: _opacity.value,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _CornerBracketsPainter(
                  color: color,
                  bracketLength: widget.bracketLength,
                  strokeWidth: widget.strokeWidth,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws four L-shaped corner brackets inside a square.
class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter({
    required this.color,
    required this.bracketLength,
    required this.strokeWidth,
  });

  final Color color;
  final double bracketLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final bl = bracketLength;

    // Top-left
    canvas
      ..drawLine(
        Offset(0, bl),
        const Offset(0, 0),
        paint,
      )
      ..drawLine(
        const Offset(0, 0),
        Offset(bl, 0),
        paint,
      );

    // Top-right
    canvas
      ..drawLine(
        Offset(w - bl, 0),
        Offset(w, 0),
        paint,
      )
      ..drawLine(
        Offset(w, 0),
        Offset(w, bl),
        paint,
      );

    // Bottom-left
    canvas
      ..drawLine(
        Offset(0, h - bl),
        Offset(0, h),
        paint,
      )
      ..drawLine(
        Offset(0, h),
        Offset(bl, h),
        paint,
      );

    // Bottom-right
    canvas
      ..drawLine(
        Offset(w - bl, h),
        Offset(w, h),
        paint,
      )
      ..drawLine(
        Offset(w, h),
        Offset(w, h - bl),
        paint,
      );
  }

  @override
  bool shouldRepaint(_CornerBracketsPainter old) =>
      old.color != color ||
      old.bracketLength != bracketLength ||
      old.strokeWidth != strokeWidth;
}
