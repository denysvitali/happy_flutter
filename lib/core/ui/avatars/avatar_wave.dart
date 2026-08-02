import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'avatar.dart';
import 'avatar_palette.dart';

// ─── Palette definitions ─────────────────────────────────────────────────────

/// Sunset palette: warm oranges, pinks, and deep purples.
const _kSunsetBg = Color(0xFF1A0A1E);
const _kSunsetPalette = [
  Color(0xFFFF6B35),
  Color(0xFFFF4E8D),
  Color(0xFFFF9F1C),
  Color(0xFFFF3366),
  Color(0xFFFFB347),
];

/// Ocean palette: deep blues, cyans, and teals.
const _kOceanBg = Color(0xFF021628);
const _kOceanPalette = [
  Color(0xFF0077B6),
  Color(0xFF00B4D8),
  Color(0xFF48CAE4),
  Color(0xFF0096C7),
  Color(0xFF90E0EF),
];

/// Aurora palette: deep greens, violets, and teals.
const _kAuroraBg = Color(0xFF050D15);
const _kAuroraPalette = [
  Color(0xFF00FF87),
  Color(0xFF8B5CF6),
  Color(0xFF06D6A0),
  Color(0xFFBF5FFF),
  Color(0xFF38BDF8),
];

// ─── Wave avatar ─────────────────────────────────────────────────────────────

/// Wave-style avatar with layered sine wave landscapes.
class AvatarWave extends BaseAvatar {
  const AvatarWave({
    required super.id,
    super.key,
    super.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final hash = avatarHash(id);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        color: Colors.black,
      ),
      clipBehavior: Clip.hardEdge,
      child: CustomPaint(
        size: Size(size, size),
        painter: _WavePainter(hash: hash),
      ),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.hash});

  final int hash;

  @override
  void paint(Canvas canvas, Size size) {
    // Select palette from hash.
    final paletteIndex = hash % 3;
    final Color bg;
    final List<Color> palette;
    switch (paletteIndex) {
      case 0:
        bg = _kSunsetBg;
        palette = _kSunsetPalette;
      case 1:
        bg = _kOceanBg;
        palette = _kOceanPalette;
      default:
        bg = _kAuroraBg;
        palette = _kAuroraPalette;
    }

    // Fill background.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bg,
    );

    // Derive wave count: 3–5.
    final waveCount = 3 + (hash % 3);

    // Draw waves from back (top) to front (bottom).
    for (var i = waveCount - 1; i >= 0; i--) {
      _drawWave(canvas, size, palette, i, waveCount, hash);
    }
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    List<Color> palette,
    int index,
    int total,
    int hash,
  ) {
    // Each wave occupies a vertical band; front waves sit lower.
    final fraction = (index + 1) / (total + 1);
    // Baseline Y: spread waves across 30%–85% of height.
    final baseY = size.height * (0.30 + fraction * 0.55);

    // Per-wave deterministic values derived from hash + index.
    final seed = hash + index * 97;

    // Frequency: 1–3 full cycles across the width.
    final freq = 1.0 + (seed % 30) / 10.0;

    // Amplitude: 4%–18% of canvas height.
    final amp = size.height * (0.04 + (seed % 15) / 100.0);

    // Phase offset in radians.
    final phase = (seed % 628) / 100.0; // 0–2π

    // Color: cycle through palette with offset per wave.
    final color = palette[(seed % palette.length)]
        .withValues(alpha: 0.55 + (index % 3) * 0.12);

    const steps = 24;
    final path = Path();
    final dx = size.width / steps;

    // Start at bottom-left corner to create a closed filled shape.
    path
      ..moveTo(0, size.height)
      // Bottom edge to the first wave point.
      ..lineTo(0, _waveY(0, dx, freq, amp, phase, baseY, size));

    for (var s = 1; s <= steps; s++) {
      path.lineTo(
        s * dx,
        _waveY(s, dx, freq, amp, phase, baseY, size),
      );
    }

    // Close the path along the bottom.
    path
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  double _waveY(
    int step,
    double dx,
    double freq,
    double amp,
    double phase,
    double baseY,
    Size size,
  ) {
    final x = step * dx;
    final t = (x / size.width) * math.pi * 2 * freq;
    return baseY + math.sin(t + phase) * amp;
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.hash != hash;
}
