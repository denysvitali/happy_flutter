import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'avatar.dart';
import 'avatar_palette.dart';

/// Geometric-style avatar with layered shape compositions.
///
/// Draws 3–5 overlapping semi-transparent geometric primitives
/// (circles, rounded rects, triangles, hexagons) at deterministic
/// positions derived from the [id] hash. Uses HSL color space with
/// golden-angle hue rotation for harmonious palettes.
class AvatarGeometric extends BaseAvatar {
  const AvatarGeometric({
    required super.id,
    super.key,
    super.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final hash = avatarHash(id);
    // Base plate takes the session's palette hue so the shape art reads as
    // the same identity colour used by the solid avatar styles.
    final bgHue = avatarHue(id);
    final bgColor = HSLColor.fromAHSL(
      1.0,
      bgHue,
      0.45,
      0.22,
    ).toColor();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: bgColor,
          child: CustomPaint(
            size: Size(size, size),
            painter: _GeometricPainter(id: id, hash: hash),
          ),
        ),
      ),
    );
  }
}

// ─── Shape types ────────────────────────────────────────────────────────────

enum _ShapeType { circle, roundedRect, triangle, hexagon, diamond }

// ─── Painter ─────────────────────────────────────────────────────────────────

class _GeometricPainter extends CustomPainter {
  const _GeometricPainter({required this.id, required this.hash});

  final String id;
  final int hash;

  // Golden angle in degrees for hue rotation
  static const double _goldenAngle = 137.508;

  /// Derive a pseudo-random integer in [0, max) from [seed].
  int _rng(int seed, int max) {
    // Simple xorshift-like mix
    var x = seed ^ seed << 13;
    x ^= x >> 7;
    x ^= x << 17;
    return x.abs() % max;
  }

  /// Derive a pseudo-random double in [0, 1) from [seed].
  double _rngF(int seed) => _rng(seed, 10000) / 10000.0;

  Color _shapeColor(int shapeIndex, double baseHue) {
    final hue =
        (baseHue + _goldenAngle * (shapeIndex + 1)) % 360;
    final sat = 0.55 + _rngF(hash ^ (shapeIndex * 4441)) * 0.30;
    final light = 0.50 + _rngF(hash ^ (shapeIndex * 7919)) * 0.25;
    final opacity =
        0.30 + _rngF(hash ^ (shapeIndex * 3307)) * 0.50;
    return HSLColor.fromAHSL(
      opacity.clamp(0.30, 0.80),
      hue,
      sat.clamp(0.0, 1.0),
      light.clamp(0.0, 1.0),
    ).toColor();
  }

  void _drawHexagon(
    Canvas canvas,
    Paint paint,
    Offset center,
    double radius,
    double rotation,
  ) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = rotation + (math.pi / 3) * i;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawTriangle(
    Canvas canvas,
    Paint paint,
    Offset center,
    double radius,
    double rotation,
  ) {
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final angle = rotation + (2 * math.pi / 3) * i - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawDiamond(
    Canvas canvas,
    Paint paint,
    Offset center,
    double radiusX,
    double radiusY,
    double rotation,
  ) {
    final path = Path();
    final angles = [0.0, math.pi / 2, math.pi, 3 * math.pi / 2];
    for (var i = 0; i < 4; i++) {
      final angle = angles[i] + rotation;
      final r = i.isEven ? radiusX : radiusY;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final baseHue = (hash % 360).toDouble();
    final w = size.width;
    final h = size.height;

    // Determine number of shapes: 3–5
    final shapeCount = 3 + _rng(hash ^ 0xDEAD, 3);

    final shapeTypes = _ShapeType.values;

    for (var i = 0; i < shapeCount; i++) {
      final seed = hash ^ (i * 6551 + 1);

      // Position: allow shapes to overflow edges slightly
      final cx = (_rngF(seed ^ 0xA1) * 1.3 - 0.15) * w;
      final cy = (_rngF(seed ^ 0xB2) * 1.3 - 0.15) * h;
      final center = Offset(cx, cy);

      // Radius: 20–60 % of width
      final radius = (0.20 + _rngF(seed ^ 0xC3) * 0.40) * w;

      // Rotation
      final rotation = _rngF(seed ^ 0xD4) * math.pi * 2;

      // Shape type
      final typeIdx = _rng(seed ^ 0xE5, shapeTypes.length);
      final shapeType = shapeTypes[typeIdx];

      final color = _shapeColor(i, baseHue);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      switch (shapeType) {
        case _ShapeType.circle:
          canvas.drawCircle(center, radius, paint);

        case _ShapeType.roundedRect:
          final rr = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: radius * 1.6,
              height: radius * 1.1,
            ),
            Radius.circular(radius * 0.28),
          );
          canvas.save();
          canvas.translate(cx, cy);
          canvas.rotate(rotation);
          canvas.translate(-cx, -cy);
          canvas.drawRRect(rr, paint);
          canvas.restore();

        case _ShapeType.triangle:
          _drawTriangle(canvas, paint, center, radius, rotation);

        case _ShapeType.hexagon:
          _drawHexagon(canvas, paint, center, radius, rotation);

        case _ShapeType.diamond:
          _drawDiamond(
            canvas,
            paint,
            center,
            radius * 0.75,
            radius * 1.15,
            rotation,
          );
      }
    }
  }

  @override
  bool shouldRepaint(_GeometricPainter old) =>
      old.id != id || old.hash != hash;
}
