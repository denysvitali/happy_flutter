import 'package:flutter/material.dart';

/// Status dot widget with optional pulsing animation.
///
/// Matches the React Native StatusDot.tsx behavior for connection status indicators.
class StatusDot extends StatefulWidget {
  /// The color of the status dot
  final Color color;

  /// Whether the dot should pulse animation
  final bool isPulsing;

  /// Size of the dot (diameter)
  final double size;

  /// Optional additional style
  final BoxStyle? style;

  const StatusDot({
    super.key,
    required this.color,
    this.isPulsing = false,
    this.size = 6,
    this.style,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPulsing != widget.isPulsing) {
      if (widget.isPulsing) {
        _controller.repeat(reverse: true);
      } else {
        _controller
          ..stop()
          ..animateTo(1.0, duration: const Duration(milliseconds: 200));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(
              widget.isPulsing ? 0.3 + _animation.value * 0.7 : 1.0,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
