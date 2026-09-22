import 'package:flutter/material.dart';

/// A progress bar with an explicitly owned indeterminate animation.
///
/// Like CircularProgressIndicator, Flutter 3.41's linear indicator otherwise
/// walks Theme ancestors on each animation tick. An explicit controller avoids
/// that traversal through potentially defunct ancestors during route removal.
class AppLinearProgressIndicator extends StatefulWidget {
  const AppLinearProgressIndicator({
    super.key,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.minHeight,
    this.borderRadius,
    this.semanticsLabel,
    this.semanticsValue,
  }) : assert(minHeight == null || minHeight > 0);

  final double? value;
  final Color? backgroundColor;
  final Color? color;
  final Animation<Color?>? valueColor;
  final double? minHeight;
  final BorderRadiusGeometry? borderRadius;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  State<AppLinearProgressIndicator> createState() =>
      _AppLinearProgressIndicatorState();
}

class _AppLinearProgressIndicatorState extends State<AppLinearProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: LinearProgressIndicator.defaultAnimationDuration,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(AppLinearProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.value == null) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void deactivate() {
    _controller.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _updateAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: widget.value,
    // A determinate value and controller cannot both be provided. Only the
    // indeterminate path resolves its controller repeatedly on animation ticks.
    controller: widget.value == null ? _controller : null,
    backgroundColor: widget.backgroundColor,
    color: widget.color,
    valueColor: widget.valueColor,
    minHeight: widget.minHeight,
    borderRadius: widget.borderRadius,
    semanticsLabel: widget.semanticsLabel,
    semanticsValue: widget.semanticsValue,
  );
}
