import 'package:flutter/material.dart';

/// A circular indicator whose indeterminate animation owns its controller.
///
/// Flutter 3.41 resolves an implicit controller by walking Theme ancestors on
/// every animation tick. During route removal this can reach a defunct element
/// (GlitchTip 3604/8780). Passing an explicit controller skips that lookup;
/// owning it here also scopes its ticks to this widget's lifetime/TickerMode.
class AppCircularProgressIndicator extends StatefulWidget {
  const AppCircularProgressIndicator({
    super.key,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.strokeWidth,
    this.strokeCap,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double? value;
  final Color? backgroundColor;
  final Color? color;
  final Animation<Color?>? valueColor;
  final double? strokeWidth;
  final StrokeCap? strokeCap;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  State<AppCircularProgressIndicator> createState() =>
      _AppCircularProgressIndicatorState();
}

class _AppCircularProgressIndicatorState
    extends State<AppCircularProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CircularProgressIndicator.defaultAnimationDuration,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(AppCircularProgressIndicator oldWidget) {
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
  Widget build(BuildContext context) => CircularProgressIndicator(
    value: widget.value,
    // Flutter disallows providing both a determinate value and a controller.
    // Determinate indicators already skip the animated ancestor lookup.
    controller: widget.value == null ? _controller : null,
    backgroundColor: widget.backgroundColor,
    color: widget.color,
    valueColor: widget.valueColor,
    strokeWidth: widget.strokeWidth,
    strokeCap: widget.strokeCap,
    semanticsLabel: widget.semanticsLabel,
    semanticsValue: widget.semanticsValue,
  );
}
