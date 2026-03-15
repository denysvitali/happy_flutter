import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'avatar.dart';

/// Constellation-style avatar with connected star patterns.
///
/// Each unique [id] deterministically produces a unique star map:
/// 5–8 dots of varying sizes placed at pseudo-random positions,
/// connected by thin semi-transparent lines to their nearest
/// 1–2 neighbours. Primary stars have a subtle glow.
class AvatarConstellation extends BaseAvatar {
  const AvatarConstellation({
    required super.id,
    super.key,
    super.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D0D2B),
            Color(0xFF0B1A38),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: CustomPaint(
          size: Size(size, size),
          painter: _ConstellationPainter(id: id, size: size),
        ),
      ),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _ConstellationPainter extends CustomPainter {
  const _ConstellationPainter({
    required this.id,
    required this.size,
  });

  final String id;
  final double size;

  // Derive a stable integer seed from the id string.
  int _seed() {
    var h = 2166136261;
    for (final c in id.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }

  // A very small LCG so we can get multiple distinct values from one seed.
  List<double> _pseudoRandom(int seed, int count) {
    const a = 1664525;
    const c = 1013904223;
    const m = 0x100000000; // 2^32
    final result = <double>[];
    var state = seed;
    for (var i = 0; i < count; i++) {
      state = (a * state + c) & (m - 1);
      result.add(state / (m - 1));
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final seed = _seed();
    final margin = size * 0.12;
    final inner = size - margin * 2;

    // ── How many stars? (5–8) ────────────────────────────────────────────
    final countRng = _pseudoRandom(seed, 1);
    final starCount = 5 + (countRng[0] * 4).floor(); // 5..8

    // ── Generate star positions and radii ───────────────────────────────
    // Need 3 values per star: x, y, kind (large vs small).
    final rng = _pseudoRandom(seed ^ 0xDEADBEEF, starCount * 3);
    final positions = <Offset>[];
    final radii = <double>[];

    // First 2–3 stars are "primary" (larger); the rest are smaller.
    final primaryCount = 2 + ((rng[0] * 2).floor()); // 2 or 3

    for (var i = 0; i < starCount; i++) {
      final rx = rng[i * 3];
      final ry = rng[i * 3 + 1];
      final x = margin + rx * inner;
      final y = margin + ry * inner;
      positions.add(Offset(x, y));

      if (i < primaryCount) {
        // Primary star: 1.8–2.8 px at size=48; scale with avatar size
        final r = (1.8 + rng[i * 3 + 2] * 1.0) * (size / 48);
        radii.add(r);
      } else {
        // Secondary star: 0.8–1.4 px at size=48
        final r = (0.8 + rng[i * 3 + 2] * 0.6) * (size / 48);
        radii.add(r);
      }
    }

    // ── Build nearest-neighbour connection list ──────────────────────────
    // For each star find its 1–2 nearest neighbours and record the pair.
    final connections = <(int, int)>{};

    // Vary per-star neighbour count: 1 or 2.
    final connRng = _pseudoRandom(seed ^ 0xCAFEBABE, starCount);

    for (var i = 0; i < starCount; i++) {
      final neighbourCount = connRng[i] < 0.55 ? 1 : 2;

      // Compute distances to all other stars.
      final dists = <(double, int)>[];
      for (var j = 0; j < starCount; j++) {
        if (j == i) continue;
        final dx = positions[i].dx - positions[j].dx;
        final dy = positions[i].dy - positions[j].dy;
        dists.add((math.sqrt(dx * dx + dy * dy), j));
      }
      dists.sort((a, b) => a.$1.compareTo(b.$1));

      for (var k = 0; k < neighbourCount && k < dists.length; k++) {
        final j = dists[k].$2;
        // Store as ordered pair to avoid duplicates.
        final pair = i < j ? (i, j) : (j, i);
        connections.add(pair);
      }
    }

    // ── Paint connections ────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = const Color(0xFFCCDDFF).withValues(alpha: 0.30)
      ..strokeWidth = 0.7 * (size / 48)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final (a, b) in connections) {
      canvas.drawLine(positions[a], positions[b], linePaint);
    }

    // ── Paint glow on primary stars ──────────────────────────────────────
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * (size / 48));

    // Star colour palette: warm whites, pale blue-whites, pale yellow-whites.
    const starPalette = <Color>[
      Color(0xFFF8F8FF), // ghost white
      Color(0xFFE8F0FF), // pale blue-white
      Color(0xFFFFF8E7), // pale warm white
      Color(0xFFD0E8FF), // ice blue
      Color(0xFFFFFACD), // lemon chiffon
    ];

    final colorRng = _pseudoRandom(seed ^ 0x1234ABCD, starCount);

    for (var i = 0; i < primaryCount; i++) {
      final ci = (colorRng[i] * starPalette.length).floor() %
          starPalette.length;
      glowPaint.color =
          starPalette[ci].withValues(alpha: 0.45);
      canvas.drawCircle(positions[i], radii[i] * 2.2, glowPaint);
    }

    // ── Paint stars ──────────────────────────────────────────────────────
    final starPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < starCount; i++) {
      final ci = (colorRng[i] * starPalette.length).floor() %
          starPalette.length;
      final alpha = i < primaryCount ? 1.0 : 0.80;
      starPaint.color = starPalette[ci].withValues(alpha: alpha);
      canvas.drawCircle(positions[i], radii[i], starPaint);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) =>
      old.id != id || old.size != size;
}
