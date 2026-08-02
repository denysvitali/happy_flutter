import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'avatar.dart';
import 'avatar_palette.dart';

/// Bloom-style avatar with layered colorful petals.
class AvatarBloom extends BaseAvatar {
  const AvatarBloom({required super.id, super.key, super.size = 48});

  @override
  Widget build(BuildContext context) {
    final hash = avatarHashVariant(id, 7);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _BloomPainter(hash: hash),
      ),
    );
  }
}

class _BloomPainter extends CustomPainter {
  const _BloomPainter({required this.hash});

  final int hash;

  Color _hsl(int offset, double saturation, double lightness) {
    final hue = ((hash + offset) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.45),
        radius: 1.2,
        colors: [_hsl(20, 0.82, 0.34), _hsl(150, 0.76, 0.17)],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    final center = Offset(size.width / 2, size.height / 2);
    final petalCount = 8 + hash.abs() % 5;
    final petalPaint = Paint()..blendMode = BlendMode.screen;

    for (var i = 0; i < petalCount; i++) {
      final angle = math.pi * 2 * i / petalCount;
      final radius = size.width * (0.23 + (i % 3) * 0.018);
      final petalCenter =
          center + Offset(math.cos(angle), math.sin(angle)) * size.width * 0.18;
      final rect = Rect.fromCenter(
        center: petalCenter,
        width: radius * 1.35,
        height: radius * 0.68,
      );

      canvas
        ..save()
        ..translate(petalCenter.dx, petalCenter.dy)
        ..rotate(angle)
        ..translate(-petalCenter.dx, -petalCenter.dy);
      petalPaint.color = _hsl(i * 43, 0.86, 0.58).withValues(alpha: 0.64);
      canvas
        ..drawOval(rect, petalPaint)
        ..restore();
    }

    canvas.drawCircle(
      center,
      size.width * 0.19,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.92),
                _hsl(260, 0.94, 0.63).withValues(alpha: 0.78),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.width * 0.2),
            ),
    );
  }

  @override
  bool shouldRepaint(_BloomPainter old) => old.hash != hash;
}
