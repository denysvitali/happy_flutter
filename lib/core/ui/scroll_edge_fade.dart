import 'package:flutter/material.dart';

/// Softly fades scrollable content out at its vertical edges so
/// items dissolve as they leave the viewport instead of clipping
/// against a hard boundary.
///
/// Wrap directly around a scrollable:
/// ```dart
/// ScrollEdgeFade(child: ListView(...))
/// ```
///
/// Implemented as a thin gradient painted *over* the edges rather than a
/// [ShaderMask]. A ShaderMask around a full-screen list forces an offscreen
/// `saveLayer` of the whole viewport on every scrolled frame, which showed
/// up as raster-side jank while dragging the chat. Because the fade already
/// blends to `colorScheme.surface` — the color behind the list — painting
/// that gradient on top is visually identical and costs one small quad.
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
    // Sample the parent surface so the fade is invisible in light mode
    // and dark mode alike (was hardcoded to Colors.white, which rendered
    // as a white blob on dark surfaces).
    final surface = Theme.of(context).colorScheme.surface;
    return Stack(
      children: [
        child,
        if (topExtent > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topExtent,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [surface, surface.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        if (bottomExtent > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: bottomExtent,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [surface, surface.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
