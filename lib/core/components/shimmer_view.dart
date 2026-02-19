import 'package:flutter/material.dart';

/// Shimmer loading view widget that wraps content with animated shimmer effect.
///
/// This widget provides a loading skeleton animation similar to React Native's
/// ShimmerView using Reanimated. It uses AnimationController and ShaderMask
/// with LinearGradient to achieve the same visual effect.
///
/// Example usage:
/// ```dart
/// ShimmerView(
///   child: Container(
///     width: double.infinity,
///     height: 100,
///     color: Colors.grey[300],
///   ),
/// )
/// ```
class ShimmerView extends StatefulWidget {

  const ShimmerView({
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
  /// The child widget to display with shimmer effect
  final Widget child;

  /// Colors for the shimmer gradient animation
  ///
  /// Default: ['#E0E0E0', '#F0F0F0', '#F8F8F8', '#F0F0F0', '#E0E0E0']
  final List<Color> colors;

  /// Width of the shimmer band as a percentage of the widget width
  ///
  /// Default: 80
  final double shimmerWidthPercent;

  /// Duration of one complete shimmer animation cycle
  ///
  /// Default: 1500ms
  final Duration duration;

  /// Whether the shimmer animation is enabled
  ///
  /// Default: true
  final bool enabled;

  @override
  State<ShimmerView> createState() => _ShimmerViewState();
}

class _ShimmerViewState extends State<ShimmerView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    if (widget.enabled) _controller.repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(ShimmerView oldWidget) {
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
    final start = -shimmerWidth +
        (bounds.width + shimmerWidth) * animation.value;
    final clampedStart = start.clamp(-shimmerWidth, bounds.width);

    return Matrix4.translationValues(clampedStart - bounds.left, 0, 0);
  }
}
