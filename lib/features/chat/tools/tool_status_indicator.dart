import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Status icons for tool execution states.
///
/// Each state is wrapped in a [Semantics] node with [liveRegion] so screen
/// readers announce tool-state transitions as they happen.
class ToolStatusIndicator extends StatelessWidget {
  const ToolStatusIndicator({required this.state, super.key, this.size = 20});

  /// The current state of the tool.
  final ToolState state;

  /// Size of the indicator icon.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (state) {
      case ToolState.running:
        return Semantics(
          label: context.l10n.toolStateRunning,
          liveRegion: true,
          child: _PulsingRunningIndicator(size: size),
        );
      case ToolState.completed:
        return Semantics(
          label: context.l10n.toolStateDone,
          liveRegion: true,
          child: _StateHalo(
            color: AppColors.success,
            size: size,
            child: Icon(
              Icons.check_circle_rounded,
              size: size,
              color: AppColors.success,
            ),
          ),
        );
      case ToolState.error:
        return Semantics(
          label: context.l10n.toolStateFailed,
          liveRegion: true,
          child: _StateHalo(
            color: theme.colorScheme.error,
            size: size,
            child: Icon(
              Icons.cancel_rounded,
              size: size,
              color: theme.colorScheme.error,
            ),
          ),
        );
      case ToolState.pending:
        return Semantics(
          label: context.l10n.toolStateQueued,
          child: Icon(
            Icons.radio_button_unchecked,
            size: size,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        );
    }
  }
}

/// Soft circular halo behind a settled-state glyph.
///
/// Gives completed / error indicators a tinted landing pad so the row's
/// outcome reads as material rather than a floating glyph. Pure decoration:
/// the pinned glyphs and hit size are unchanged.
class _StateHalo extends StatelessWidget {
  const _StateHalo({
    required this.color,
    required this.size,
    required this.child,
  });

  final Color color;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: size + 6,
        height: size + 6,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: AppOpacity.faint),
          border: Border.all(
            color: color.withValues(alpha: 0.22),
            width: AppBorder.hairline,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Enum representing the state of a tool execution.
enum ToolState { pending, running, completed, error }

/// A pulsing animated indicator for the running state.
class _PulsingRunningIndicator extends StatefulWidget {
  const _PulsingRunningIndicator({required this.size});
  final double size;

  @override
  State<_PulsingRunningIndicator> createState() =>
      _PulsingRunningIndicatorState();
}

class _PulsingRunningIndicatorState extends State<_PulsingRunningIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;
  bool? _reduceMotion;
  bool _settled = false;
  int _animationRun = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppDuration.pulse);

    _pulseScale = Tween<double>(
      begin: 0.7,
      end: 1.35,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _pulseOpacity = Tween<double>(
      begin: 0.55,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AppMotion.reduceMotion(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    final run = ++_animationRun;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 0;
      _settled = true;
    } else {
      _settled = false;
      _controller
          .repeat(count: AppMotion.activityPulseCount)
          .whenCompleteOrCancel(() {
            if (!mounted || run != _animationRun) return;
            _controller.value = 0;
            setState(() => _settled = true);
          });
    }
  }

  @override
  void dispose() {
    _animationRun++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final ringColor = theme.colorScheme.primary;
    // The sheen ring carries the signature gradient so a running tool reads
    // as "live" from across the room; the glyph keeps the plain primary.
    final gradient = cs.accentLinearGradient;

    if ((_reduceMotion ?? AppMotion.reduceMotion(context)) || _settled) {
      return Icon(Icons.autorenew_rounded, size: widget.size, color: ringColor);
    }

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing gradient ring (the "sheen")
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(scale: _pulseScale.value, child: child);
              },
              child: FadeTransition(
                opacity: _pulseOpacity,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                  ),
                ),
              ),
            ),
            // Canvas-colored core punches the donut hole out of the ring.
            Container(
              width: widget.size - 4,
              height: widget.size - 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.scaffoldBackgroundColor,
              ),
            ),
            // Rotate a concrete running glyph with the bounded controller.
            // An indeterminate CircularProgressIndicator owns a second
            // perpetual ticker even after the outer pulse is stopped.
            RotationTransition(
              turns: _controller,
              child: Icon(
                Icons.autorenew_rounded,
                size: widget.size * 0.75,
                color: ringColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simpler status indicator that shows just the appropriate icon.
class StatusIcon extends StatelessWidget {
  const StatusIcon({
    required this.state,
    super.key,
    this.size = 22,
    this.color,
  });

  /// The tool state to display.
  final ToolState state;

  /// Size of the icon.
  final double size;

  /// Optional custom color override.
  final Color? color;

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
        return AppColors.success;
      case ToolState.error:
        return theme.colorScheme.error;
      case ToolState.pending:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
