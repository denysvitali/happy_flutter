import 'package:flutter/material.dart';

/// Softly fades scrollable content out at its vertical edges so
/// items dissolve as they leave the viewport instead of clipping
/// against a hard boundary.
///
/// Wrap directly around a scrollable:
/// ```dart
/// ScrollEdgeFade(child: ListView(...))
/// ```
class ScrollEdgeFade extends StatelessWidget {
  /// Creates a scroll edge fade.
  const ScrollEdgeFade({
    required this.child,
    super.key,
    this.topExtent = 24,
    this.bottomExtent = 0,
  });

  /// The scrollable content to mask.
  final Widget child;

  /// Height in logical pixels of the top fade. Zero disables it.
  final double topExtent;

  /// Height in logical pixels of the bottom fade. Zero disables it.
  final double bottomExtent;

  @override
  Widget build(BuildContext context) {
    if (topExtent <= 0 && bottomExtent <= 0) return child;
    return ShaderMask(
      shaderCallback: (rect) {
        final h = rect.height;
        if (h <= 0) {
          return const LinearGradient(
            colors: [Colors.white, Colors.white],
          ).createShader(rect);
        }
        final topStop = (topExtent / h).clamp(0.0, 0.45);
        final bottomStop = 1.0 - (bottomExtent / h).clamp(0.0, 0.45);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, topStop, bottomStop, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
