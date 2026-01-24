import 'package:flutter/material.dart';

/// Status icons for tool execution states.
class ToolStatusIndicator extends StatelessWidget {
  /// The current state of the tool.
  final ToolState state;

  /// Size of the indicator icon.
  final double size;

  const ToolStatusIndicator({super.key, required this.state, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (state) {
      case ToolState.running:
        return SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      case ToolState.completed:
        return Icon(
          Icons.check_circle,
          size: size,
          color: theme.colorScheme.primary,
        );
      case ToolState.error:
        return Icon(Icons.error, size: size, color: theme.colorScheme.error);
      case ToolState.pending:
        return Icon(
          Icons.circle_outlined,
          size: size,
          color: theme.colorScheme.onSurfaceVariant,
        );
    }
  }
}

/// Enum representing the state of a tool execution.
enum ToolState { pending, running, completed, error }

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
        return SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      case ToolState.completed:
        return Icon(Icons.check_circle, size: size, color: effectiveColor);
      case ToolState.error:
        return Icon(Icons.cancel, size: size, color: effectiveColor);
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
