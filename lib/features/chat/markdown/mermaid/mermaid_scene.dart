/// Paint primitives produced by the Mermaid layouts.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Colours and text settings a diagram is laid out with.
class MermaidTheme {
  /// Creates a theme.
  const MermaidTheme({
    required this.dark,
    required this.surface,
    required this.text,
    required this.mutedText,
    required this.edge,
    required this.palette,
    required this.textScaler,
    required this.fontFamily,
  });

  /// Derives the diagram theme from the ambient [ThemeData].
  factory MermaidTheme.of(ThemeData theme, TextScaler textScaler) {
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    return MermaidTheme(
      dark: dark,
      surface: scheme.surfaceContainerHighest,
      text: scheme.onSurface,
      mutedText: scheme.onSurfaceVariant,
      edge: scheme.onSurfaceVariant.withValues(alpha: 0.85),
      palette: dark ? _darkPalette : _lightPalette,
      textScaler: textScaler,
      fontFamily: theme.textTheme.bodyMedium?.fontFamily,
    );
  }

  static const List<Color> _lightPalette = [
    Color(0xFF4F46E5), // indigo
    Color(0xFF0284C7), // sky
    Color(0xFF059669), // emerald
    Color(0xFFD97706), // amber
    Color(0xFFE11D48), // rose
    Color(0xFF7C3AED), // violet
    Color(0xFF0D9488), // teal
    Color(0xFFEA580C), // orange
  ];

  static const List<Color> _darkPalette = [
    Color(0xFF818CF8),
    Color(0xFF38BDF8),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
    Color(0xFFFB7185),
    Color(0xFFA78BFA),
    Color(0xFF2DD4BF),
    Color(0xFFFB923C),
  ];

  /// Whether the ambient theme is dark.
  final bool dark;

  /// Diagram background.
  final Color surface;

  /// Primary text colour.
  final Color text;

  /// Secondary text colour.
  final Color mutedText;

  /// Default edge / line colour.
  final Color edge;

  /// Accent colours cycled through clusters, participants and slices.
  final List<Color> palette;

  /// Accessibility text scaling.
  final TextScaler textScaler;

  /// Font family for labels.
  final String? fontFamily;

  /// Palette colour [index], cycling.
  Color accent(int index) => palette[index % palette.length];

  /// [color] tinted over the diagram surface, used for default fills.
  Color tint(Color color, [double amount = 1]) => Color.alphaBlend(
    color.withValues(alpha: (dark ? 0.24 : 0.14) * amount),
    surface,
  );

  /// Readable text colour on top of [fill].
  Color onFill(Color fill) {
    final effective = fill.a < 1 ? Color.alphaBlend(fill, surface) : fill;
    if (fill.a < 0.35) return text;
    return effective.computeLuminance() > 0.45
        ? const Color(0xFF111827)
        : Colors.white;
  }

  /// Lays out [text] for painting.
  TextPainter label(
    String text, {
    required Color color,
    double fontSize = 13,
    FontWeight weight = FontWeight.w500,
    double maxWidth = 180,
    TextAlign align = TextAlign.center,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          fontFamily: fontFamily,
          height: 1.25,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    return painter;
  }
}

/// A single paint operation.
sealed class MermaidOp {
  const MermaidOp();

  /// Bounds covered by the operation.
  Rect get bounds;
}

/// Fills and/or strokes a path.
class MermaidPathOp extends MermaidOp {
  /// Creates a path op.
  MermaidPathOp(
    this.path, {
    this.fill,
    this.stroke,
    this.strokeWidth = 1.5,
    this.dashed = false,
  });

  /// Path to paint.
  final Path path;

  /// Fill colour.
  final Color? fill;

  /// Stroke colour.
  final Color? stroke;

  /// Stroke width.
  final double strokeWidth;

  /// Whether the stroke is dashed.
  final bool dashed;

  @override
  Rect get bounds => path.getBounds().inflate(strokeWidth);
}

/// Paints laid-out text with its top-left at [offset].
class MermaidTextOp extends MermaidOp {
  /// Creates a text op.
  MermaidTextOp(this.painter, this.offset);

  /// Laid-out text.
  final TextPainter painter;

  /// Top-left position.
  final Offset offset;

  @override
  Rect get bounds => offset & painter.size;
}

/// A laid-out diagram ready to paint.
class MermaidScene {
  /// Creates a scene from [ops], computing its bounds.
  MermaidScene(this.ops, {required this.labels, double padding = 12}) {
    var rect = Rect.zero;
    var first = true;
    for (final op in ops) {
      final b = op.bounds;
      if (!b.isFinite) continue;
      rect = first ? b : rect.expandToInclude(b);
      first = false;
    }
    _origin = rect.topLeft - Offset(padding, padding);
    size = Size(rect.width + padding * 2, rect.height + padding * 2);
  }

  /// Paint operations in z-order.
  final List<MermaidOp> ops;

  /// Text labels in reading order (for semantics).
  final List<String> labels;

  /// Painted size.
  late final Size size;

  late final Offset _origin;

  /// Paints the scene with its top-left at the canvas origin.
  void paint(Canvas canvas) {
    canvas
      ..save()
      ..translate(-_origin.dx, -_origin.dy);
    final paint = Paint()..isAntiAlias = true;
    for (final op in ops) {
      switch (op) {
        case MermaidPathOp():
          if (op.fill != null && op.fill!.a > 0) {
            paint
              ..style = PaintingStyle.fill
              ..color = op.fill!;
            canvas.drawPath(op.path, paint);
          }
          if (op.stroke != null && op.stroke!.a > 0 && op.strokeWidth > 0) {
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = op.strokeWidth
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = op.stroke!;
            canvas.drawPath(
              op.dashed ? _dash(op.path, op.strokeWidth) : op.path,
              paint,
            );
          }
        case MermaidTextOp():
          op.painter.paint(canvas, op.offset);
      }
    }
    canvas.restore();
  }

  /// Releases the text layouts.
  void dispose() {
    // A painter may be painted more than once (sequence headers and
    // footers share one layout); dispose each exactly once.
    final painters = <TextPainter>{
      for (final op in ops)
        if (op is MermaidTextOp) op.painter,
    };
    for (final painter in painters) {
      painter.dispose();
    }
  }

  static Path _dash(Path source, double width) {
    final on = math.max(4.0, width * 3);
    final off = math.max(3.0, width * 2);
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + on, metric.length);
        out.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + off;
      }
    }
    return out;
  }
}

/// Paints a [MermaidScene].
class MermaidScenePainter extends CustomPainter {
  /// Creates a painter.
  const MermaidScenePainter(this.scene);

  /// Scene to paint.
  final MermaidScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / scene.size.width;
    final sy = size.height / scene.size.height;
    canvas
      ..save()
      ..scale(sx, sy);
    scene.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(MermaidScenePainter oldDelegate) =>
      !identical(oldDelegate.scene, scene);
}
