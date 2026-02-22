import 'package:flutter/material.dart';

/// Animated shimmer gradient loading effect
class Shimmer extends StatefulWidget {

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
  final Widget child;
  final List<Color> colors;
  final double shimmerWidthPercent;
  final Duration duration;
  final bool enabled;

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
        return RepaintBoundary(
          child: ShaderMask(
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
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Custom gradient transform for shimmer effect
class _ShimmerGradientTransform extends GradientTransform {

  const _ShimmerGradientTransform({
    required this.animation,
    required this.widthPercent,
    required this.boundsWidth,
  });
  final Animation<double> animation;
  final double widthPercent;
  final double boundsWidth;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final shimmerWidth = bounds.width * (widthPercent / 100);
    final start =
        -shimmerWidth + (bounds.width + shimmerWidth) * animation.value;

    // Clamp values to bounds
    final clampedStart = start.clamp(-shimmerWidth, bounds.width);
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
    required BuildContext context,
    required double height,
    double? width,
    BorderRadiusGeometry borderRadius =
        const BorderRadius.all(Radius.circular(12)),
  }) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  /// Shimmer for text lines
  static Widget textLine({
    required BuildContext context,
    double height = 16,
    double width = double.infinity,
    BorderRadiusGeometry borderRadius =
        const BorderRadius.all(Radius.circular(4)),
  }) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  /// Shimmer for avatar placeholder
  static Widget avatar({
    required BuildContext context,
    double size = 48,
  }) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Multi-line text shimmer
  static Widget textLines({
    required BuildContext context,
    int lines = 3,
    double lineHeight = 16,
    double width = double.infinity,
    double spacing = 8,
  }) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines, (index) {
          return Padding(
            padding: index > 0
                ? EdgeInsets.only(top: spacing)
                : EdgeInsets.zero,
            child: Container(
              height: lineHeight,
              width: index == lines - 1 ? width * 0.6 : width,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    const BorderRadius.all(Radius.circular(4)),
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

  const ShimmerImagePlaceholder({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    super.key,
  });
  final double width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Pulse loading indicator
class ShimmerPulse extends StatefulWidget {

  const ShimmerPulse({
    this.size = 48,
    this.color,
    super.key,
  });
  final double size;

  /// Dot color. Defaults to [ColorScheme.surfaceContainerHighest] when null.
  final Color? color;

  @override
  State<ShimmerPulse> createState() => _ShimmerPulseState();
}

class _ShimmerPulseState extends State<ShimmerPulse>
    with SingleTickerProviderStateMixin {
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
    final resolvedColor = widget.color ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
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
          color: resolvedColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
