import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// What the agent is doing right now, from the chat's point of view.
///
/// The three states share one bar so a stop request never stacks a
/// second live indicator on top of the "thinking" one, and never
/// changes the chrome's height mid-turn.
enum ChatAgentActivity {
  /// The agent is working and can be interrupted.
  thinking,

  /// A stop request is in flight, or has been sent and is still within
  /// the confirmation window.
  stopping,

  /// A stop request was accepted but the agent is still reporting work
  /// past the confirmation window — the stop is unconfirmed, so the
  /// action is offered again rather than pretending it landed.
  stopUnconfirmed,
}

/// A compact bar shown between the chat list and the input while the
/// agent is working. Provides a one-tap **Stop** button so the user can
/// interrupt a long-running turn without hunting through the overflow
/// menu, and stays mounted (same height, same layout) while the stop
/// request is in flight.
///
/// Placed in the activity-chrome stack (after TTS, before input) per
/// the banner-priority comment in `_ChatScreenState.build`.
class ThinkingStopBar extends StatelessWidget {
  const ThinkingStopBar({
    required this.onStop,
    this.activity = ChatAgentActivity.thinking,
    super.key,
  });

  final VoidCallback onStop;

  /// Current agent activity. Drives the leading indicator, the label,
  /// and whether the stop action is tappable.
  final ChatAgentActivity activity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final stopping = activity == ChatAgentActivity.stopping;
    final unconfirmed = activity == ChatAgentActivity.stopUnconfirmed;
    final label = switch (activity) {
      ChatAgentActivity.thinking => l10n.chatActivityThinking,
      ChatAgentActivity.stopping => l10n.chatActivityStopping,
      ChatAgentActivity.stopUnconfirmed => l10n.chatActivityStopUnconfirmed,
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            SizedBox(
              width: AppIconSize.sm,
              height: AppIconSize.sm,
              child: Center(
                child: unconfirmed
                    ? const Icon(
                        Icons.error_outline_rounded,
                        size: AppIconSize.sm,
                        color: AppColors.warning,
                      )
                    // Reduced-motion aware, and the same primitive in both
                    // live states so the row never swaps animation kinds
                    // mid-turn. Muted while stopping: the turn is winding
                    // down, not progressing.
                    : _PulsingDot(
                        color: stopping
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.primary,
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: unconfirmed
                      ? AppColors.warning
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              // Disabled (not removed) while the request is in flight:
              // the row keeps its width and the greyed label confirms the
              // tap registered, instead of the button vanishing.
              onPressed: stopping ? null : onStop,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xxs,
                ),
                minimumSize: const Size(0, AppTouchTarget.min),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.chatActivityStop),
            ),
          ],
        ),
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
