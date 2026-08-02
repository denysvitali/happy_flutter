import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'avatar.dart';
import 'avatar_palette.dart';

/// Prism-style avatar with crisp colorful facets.
class AvatarPrism extends BaseAvatar {
  const AvatarPrism({required super.id, super.key, super.size = 48});

  @override
  Widget build(BuildContext context) {
    final hash = avatarHashVariant(id, 11);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _PrismPainter(hash: hash),
      ),
    );
  }
}

class _PrismPainter extends CustomPainter {
  const _PrismPainter({required this.hash});

  final int hash;

  double _value(int salt) {
    final mixed = (hash + salt * 374761393) ^ (hash >> 13);
    return (mixed.abs() % 10000) / 10000;
  }

  Color _color(int index) {
    final hue = ((hash + index * 51) % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.82, 0.56).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _color(0).withValues(alpha: 0.92),
            _color(4).withValues(alpha: 0.92),
          ],
        ).createShader(rect),
    );

    final points = <Offset>[
      Offset(size.width * 0.5, size.height * 0.5),
      for (var i = 0; i < 10; i++)
        Offset(size.width * _value(i * 2 + 1), size.height * _value(i * 2 + 2)),
    ];
    final center = points.first;

    for (var i = 1; i < points.length; i++) {
      final a = points[i];
      final b = points[i == points.length - 1 ? 1 : i + 1];
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = _color(i).withValues(alpha: 0.62)
          ..style = PaintingStyle.fill,
      );
    }

    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width * 0.025);
    for (var i = 1; i < points.length; i += 2) {
      canvas.drawLine(center, points[i], highlight);
    }
  }

  @override
  bool shouldRepaint(_PrismPainter old) => old.hash != hash;
}
