import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;

/// Animated shimmer gradient loading effect
class Shimmer extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final double shimmerWidthPercent;
  final Duration duration;
  final bool enabled;

  const Shimmer({
    required this.child,
    this.colors = const [
      Color(0xFFE0E0E0),
      Color(0xFFF0F0F0),
      Color(0xFFF8F8F8),
      Color(0xFFF0F0F0),
      Color(0xFFE0E0E0),
    ],
    this.shimmerWidthPercent = 80,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
    super.key,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) {
      _controller.repeat(reverse: true);
    } else if (oldWidget.enabled && !widget.enabled) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: widget.colors,
              stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.topRight,
              transform: _ShimmerGradientTransform(
                animation: _animation,
                widthPercent: widget.shimmerWidthPercent,
                boundsWidth: bounds.width,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: widget.child,
      ),
    );
  }
}

/// Custom gradient transform for shimmer effect
class _ShimmerGradientTransform extends GradientTransform {
  final Animation<double> animation;
  final double widthPercent;
  final double boundsWidth;

  const _ShimmerGradientTransform({
    required this.animation,
    required this.widthPercent,
    required this.boundsWidth,
  });

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final shimmerWidth = bounds.width * (widthPercent / 100);
    final start = -shimmerWidth + (bounds.width + shimmerWidth) * animation.value;
    final end = start + shimmerWidth;

    // Clamp values to bounds
    final clampedStart = start.clamp(-shimmerWidth, bounds.width);
    final clampedEnd = end.clamp(0, bounds.width + shimmerWidth);

    // Normalize to 0-1 range
    final tStart = (clampedStart - (-shimmerWidth)) / (bounds.width + shimmerWidth * 2);
    final tEnd = (clampedEnd - (-shimmerWidth)) / (bounds.width + shimmerWidth * 2);

    return Matrix4.translationValues(clampedStart - bounds.left, 0, 0);
  }
}

/// Pre-configured shimmer styles for common use cases
class ShimmerStyles {
  /// Default shimmer for list items
  static Widget listTile({
    required Widget leading,
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
  }) {
    return Shimmer(
      child: ListTile(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }

  /// Shimmer for card-like content
  static Widget card({
    required double height,
    double? width,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) {
    return Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  /// Shimmer for text lines
  static Widget textLine({
    double height = 16,
    double width = double.infinity,
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(4)),
  }) {
    return Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  /// Shimmer for avatar placeholder
  static Widget avatar({double size = 48}) {
    return Shimmer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFE0E0E0),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Multi-line text shimmer
  static Widget textLines({
    int lines = 3,
    double lineHeight = 16,
    double width = double.infinity,
    double spacing = 8,
  }) {
    return Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines, (index) {
          return Padding(
            padding: index > 0 ? EdgeInsets.only(top: spacing) : EdgeInsets.zero,
            child: Container(
              height: lineHeight,
              width: index == lines - 1 ? width * 0.6 : width,
              decoration: const BoxDecoration(
                color: Color(0xFFE0E0E0),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Loading shimmer placeholder for images
class ShimmerImagePlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const ShimmerImagePlaceholder({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Pulse loading indicator
class ShimmerPulse extends StatefulWidget {
  final double size;
  final Color color;

  const ShimmerPulse({
    this.size = 48,
    this.color = const Color(0xFFE0E0E0),
    super.key,
  });

  @override
  State<ShimmerPulse> createState() => _ShimmerPulseState();
}

class _ShimmerPulseState extends State<ShimmerPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + 0.4 * _controller.value,
          child: Opacity(
            opacity: 0.3 + 0.7 * _controller.value,
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
