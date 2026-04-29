import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Displays a colored dot indicator with optional pulse animation.
///
/// Used to show connection/activity status throughout the app.
/// When [pulse] is true the dot animates with a combined opacity
/// and scale effect on a 1.5-second loop.
class AppStatusDot extends StatefulWidget {
  /// Creates a status dot.
  ///
  /// [color] is required. [size] defaults to 8 logical pixels.
  /// [pulse] enables the looping animation.
  /// [pulseColor] overrides the outer ring color when pulsing;
  /// defaults to [color] at reduced opacity.
  const AppStatusDot({
    required this.color,
    super.key,
    this.size = AppSpacing.xs,
    this.pulse = false,
    this.pulseColor,
    this.margin,
    this.semanticLabel,
  });

  /// The color of the dot.
  final Color color;

  /// Diameter of the dot in logical pixels.
  final double size;

  /// Whether to show the looping pulse animation.
  final bool pulse;

  /// Color used for the outer pulse ring.
  ///
  /// Defaults to [color] when null.
  final Color? pulseColor;

  /// Optional margin around the dot.
  final EdgeInsets? margin;

  /// Optional semantic label for screen readers.
  final String? semanticLabel;

  @override
  State<AppStatusDot> createState() => _AppStatusDotState();
}

class _AppStatusDotState extends State<AppStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500), // 1.5s pulse loop
      vsync: this,
    );
    _opacity = Tween<double>(
      begin: 1.0,
      end: 0.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _syncAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.maybeOf(context);
    final reduceMotion =
        (mediaQuery?.disableAnimations ?? false) ||
        (mediaQuery?.accessibleNavigation ?? false);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(AppStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.pulse && !_reduceMotion) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget dot;
    if (!widget.pulse || _reduceMotion) {
      dot = _buildDot();
    } else {
      dot = AnimatedBuilder(
        animation: _controller,
        child: _buildStaticDot(),
        builder: (context, child) {
          final ringColor = (widget.pulseColor ?? widget.color).withValues(
            alpha: _opacity.value * 0.4,
          );
          return SizedBox(
            width: widget.size * 2.4,
            height: widget.size * 2.4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Animated outer pulsing ring.
                Transform.scale(
                  scale: _scale.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ringColor,
                    ),
                  ),
                ),
                // Static inner dot (passed via child parameter).
                child!,
              ],
            ),
          );
        },
      );
    }
    if (widget.semanticLabel != null) {
      dot = Semantics(label: widget.semanticLabel, child: dot);
    }
    if (widget.margin != null) {
      return Padding(padding: widget.margin!, child: dot);
    }
    return dot;
  }

  Widget _buildDot() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.4),
            blurRadius: widget.size * 0.75,
            spreadRadius: widget.size * 0.1,
          ),
        ],
      ),
    );
  }

  Widget _buildStaticDot() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
    );
  }
}
