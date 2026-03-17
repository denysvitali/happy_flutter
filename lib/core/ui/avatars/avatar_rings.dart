import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'avatar.dart';

/// Ring-style avatar with concentric colored rings,
/// like a cross-section of a tree trunk or a topographic map.
class AvatarRings extends BaseAvatar {
  const AvatarRings({
    required super.id,
    super.key,
    super.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final hash = id.codeUnits.fold(0, (acc, c) => acc * 31 + c);
    final bgHue = (hash % 360).toDouble();
    final bgColor = HSLColor.fromAHSL(
      1.0,
      bgHue,
      0.25,
      0.12,
    ).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      clipBehavior: Clip.hardEdge,
      child: CustomPaint(
        size: Size(size, size),
        painter: _RingsPainter(id: id, hash: hash),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.id, required this.hash});

  final String id;
  final int hash;

  /// Golden angle in degrees — produces maximally-spaced hues.
  static const double _goldenAngle = 137.508;

  /// Derive an int in [0, max) from the running hash.
  static int _next(int h, int max) => h.abs() % max;

  /// Linear congruential generator step using constants safe for both
  /// VM (64-bit int) and web (JavaScript double).
  static int _lcg(int h) => h * 214013 + 2531011;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = cx * 0.92; // leave a tiny margin

    // Seed separate per-property hashes from the original hash so that
    // ring count, hue start, widths and gaps all vary independently.
    final hCount = (hash >> 3) ^ (hash << 5);
    final hHue = (hash >> 7) ^ (hash * 13);
    var hWidth = (hash >> 11) ^ (hash + 0xDEAD);
    var hGap = (hash >> 2) ^ (hash - 0xBEEF);
    var hDash = (hash >> 9) ^ (hash ^ 0xCAFE);
    var hLight = (hash >> 1) ^ (hash * 7);

    // 4–7 rings
    final ringCount = 4 + _next(hCount, 4);

    // Base hue rotated by golden angle for each ring.
    final baseHue = _next(hHue, 360).toDouble();

    // Accumulate radii inward from maxR.
    var outerR = maxR;

    // Scale factor so widths/gaps feel proportional to avatar size.
    final scale = size.width / 48.0;

    // Draw outermost ring first so inner rings paint on top.
    for (var i = 0; i < ringCount; i++) {
      // Stroke width: 2–6 px (scaled).
      hWidth = _lcg(hWidth);
      final rawWidth = 2.0 + _next(hWidth, 5).toDouble(); // 2–6
      final strokeW = rawWidth * scale;

      // Gap before this ring (ring sits at outerR - strokeW/2).
      hGap = _lcg(hGap);
      final rawGap = 1.0 + _next(hGap, 4).toDouble(); // 1–4
      final gap = rawGap * scale;

      // Centre of the stroke.
      final r = outerR - gap - strokeW / 2;
      if (r <= 0) break;

      // Hue: rotate by golden angle per ring, vary lightness slightly.
      final hue = (baseHue + i * _goldenAngle) % 360;
      hLight = _lcg(hLight);
      final lightness = 0.50 + _next(hLight, 26) * 0.01; // 0.50–0.75
      final saturation = 0.60 + _next(hLight >> 4, 25) * 0.01; // 0.60–0.84
      final color = HSLColor.fromAHSL(
        1.0,
        hue,
        saturation.clamp(0.0, 1.0),
        lightness.clamp(0.0, 1.0),
      ).toColor();

      // Decide whether this ring is dashed (≈1 in 3 rings).
      hDash = _lcg(hDash);
      final isDashed = _next(hDash, 3) == 0;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;

      if (isDashed) {
        _drawDashedCircle(canvas, cx, cy, r, paint);
      } else {
        canvas.drawCircle(Offset(cx, cy), r, paint);
      }

      // Advance outer boundary past this ring.
      outerR = r - strokeW / 2;
    }

    // Center dot — bright accent derived from base hue.
    final accentHue = (baseHue + 60) % 360;
    final accentColor = HSLColor.fromAHSL(
      1.0,
      accentHue,
      0.90,
      0.70,
    ).toColor();
    final dotR = (1.8 * scale).clamp(1.0, 5.0);
    canvas.drawCircle(
      Offset(cx, cy),
      dotR,
      Paint()..color = accentColor,
    );
  }

  /// Draws a circle as a series of short arcs (dashed appearance).
  void _drawDashedCircle(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    Paint paint,
  ) {
    // Aim for dash + gap ≈ 16° of arc each.
    const dashDeg = 8.0;
    const gapDeg = 8.0;
    const step = dashDeg + gapDeg;
    const stepRad = step * math.pi / 180;
    const dashRad = dashDeg * math.pi / 180;

    final steps = (360 / step).floor();
    for (var i = 0; i < steps; i++) {
      final startAngle = i * stepRad - math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        dashRad,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.id != id || old.hash != hash;
}
