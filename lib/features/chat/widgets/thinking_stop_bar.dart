import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// A compact bar shown between the chat list and the input when the
/// agent is actively thinking. Provides a one-tap **Stop** button so
/// the user can interrupt a long-running turn without hunting through
/// the overflow menu.
///
/// Placed in the activity-chrome stack (after TTS, before input) per
/// the banner-priority comment in `_ChatScreenState.build`.
class ThinkingStopBar extends StatelessWidget {
  const ThinkingStopBar({required this.onStop, super.key});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          // Animated dot to signal live activity.
          _PulsingDot(color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Thinking\u2026',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: onStop,
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xxs,
              ),
              minimumSize: const Size(0, AppTouchTarget.min),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}

/// A small dot that pulses to signal live activity.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _controller
        ..stop()
        ..value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.3,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}
