import 'package:flutter/material.dart';

/// Status icons for tool execution states.
class ToolStatusIndicator extends StatelessWidget {
  /// The current state of the tool.
  final ToolState state;

  /// Size of the indicator icon.
  final double size;

  const ToolStatusIndicator({
    super.key,
    required this.state,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (state) {
      case ToolState.running:
        return _PulsingRunningIndicator(size: size);
      case ToolState.completed:
        return Icon(
          Icons.check_circle_rounded,
          size: size,
          color: const Color(0xFF34C759),
        );
      case ToolState.error:
        return Icon(
          Icons.cancel_rounded,
          size: size,
          color: theme.colorScheme.error,
        );
      case ToolState.pending:
        return Icon(
          Icons.radio_button_unchecked,
          size: size,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        );
    }
  }
}

/// Enum representing the state of a tool execution.
enum ToolState { pending, running, completed, error }

/// A pulsing animated indicator for the running state.
class _PulsingRunningIndicator extends StatefulWidget {
  final double size;

  const _PulsingRunningIndicator({required this.size});

  @override
  State<_PulsingRunningIndicator> createState() =>
      _PulsingRunningIndicatorState();
}

class _PulsingRunningIndicatorState extends State<_PulsingRunningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseScale = Tween<double>(begin: 0.7, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ringColor = theme.colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ring
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseScale.value,
                child: Opacity(
                  opacity: _pulseOpacity.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Inner spinner
          SizedBox(
            width: widget.size * 0.7,
            height: widget.size * 0.7,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation<Color>(ringColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// A simpler status indicator that shows just the appropriate icon.
class StatusIcon extends StatelessWidget {
  /// The tool state to display.
  final ToolState state;

  /// Size of the icon.
  final double size;

  /// Optional custom color override.
  final Color? color;

  const StatusIcon({
    super.key,
    required this.state,
    this.size = 22,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? _getColorForState(theme);

    switch (state) {
      case ToolState.running:
        return _PulsingRunningIndicator(size: size);
      case ToolState.completed:
        return Icon(
          Icons.check_circle_rounded,
          size: size,
          color: effectiveColor,
        );
      case ToolState.error:
        return Icon(Icons.cancel_rounded, size: size, color: effectiveColor);
      case ToolState.pending:
        return const SizedBox.shrink();
    }
  }

  Color _getColorForState(ThemeData theme) {
    switch (state) {
      case ToolState.running:
        return theme.colorScheme.primary;
      case ToolState.completed:
        return const Color(0xFF34C759);
      case ToolState.error:
        return theme.colorScheme.error;
      case ToolState.pending:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
