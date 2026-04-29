import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'avatar.dart';

/// Neon-style avatar with bright color beams and a glowing core.
class AvatarNeon extends BaseAvatar {
  const AvatarNeon({required super.id, super.key, super.size = 48});

  @override
  Widget build(BuildContext context) {
    final hash = id.codeUnits.fold(0, (acc, c) => acc * 33 + c);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _NeonPainter(hash: hash),
      ),
    );
  }
}

class _NeonPainter extends CustomPainter {
  const _NeonPainter({required this.hash});

  final int hash;

  double _value(int salt) {
    final mixed = (hash ^ salt) * 1103515245 + 12345;
    return (mixed.abs() % 10000) / 10000;
  }

  Color _color(int index, {double alpha = 1}) {
    final hue = ((hash + index * 79) % 360).toDouble();
    return HSLColor.fromAHSL(alpha, hue, 0.88, 0.58).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          HSLColor.fromAHSL(1, (hash % 360).toDouble(), 0.56, 0.13).toColor(),
          HSLColor.fromAHSL(
            1,
            ((hash + 140) % 360).toDouble(),
            0.62,
            0.18,
          ).toColor(),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.screen;

    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.18 + _value(i * 391) * 0.68);
      final amplitude = size.height * (0.07 + _value(i * 719) * 0.15);
      final phase = _value(i * 887) * math.pi * 2;
      final path = Path()..moveTo(-size.width * 0.1, y);

      for (var step = 0; step <= 8; step++) {
        final x = size.width * (step / 8);
        final nextY = y + math.sin(step * 0.9 + phase) * amplitude;
        path.lineTo(x, nextY);
      }

      beamPaint
        ..color = _color(i, alpha: 0.74)
        ..strokeWidth = size.width * (0.045 + _value(i * 521) * 0.045)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.035);
      canvas.drawPath(path, beamPaint);

      beamPaint
        ..color = Colors.white.withValues(alpha: 0.34)
        ..strokeWidth = size.width * 0.012
        ..maskFilter = null;
      canvas.drawPath(path, beamPaint);
    }

    final center = Offset(
      size.width * (0.38 + _value(17) * 0.24),
      size.height * (0.34 + _value(29) * 0.28),
    );
    canvas
      ..drawCircle(
        center,
        size.width * 0.22,
        Paint()
          ..color = _color(7, alpha: 0.42)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.16),
      )
      ..drawCircle(
        center,
        size.width * 0.055,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
  }

  @override
  bool shouldRepaint(_NeonPainter old) => old.hash != hash;
}
