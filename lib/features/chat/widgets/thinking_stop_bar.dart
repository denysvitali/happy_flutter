import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
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

/// A compact **glass capsule** shown between the chat list and the input
/// while the agent is working. Provides a one-tap **Stop** button so the
/// user can interrupt a long-running turn without hunting through the
/// overflow menu, and stays mounted (same height, same layout) while the
/// stop request is in flight.
///
/// Aurora Glass material: translucent surface fill, hairline glass
/// border, soft floating shadow. The leading indicator carries state as
/// colour and motion, not extra labels — an accent-gradient dot that
/// breathes while thinking, a static muted ring while stopping, and the
/// warning icon for an unconfirmed stop.
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Bare-MaterialApp test hosts have no AppColorScheme extension;
    // fall back to a scheme-derived accent so the chrome still renders.
    final appScheme = theme.extension<AppColorScheme>();
    final accentGradient =
        appScheme?.accentLinearGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.secondary],
        );
    final glassBorder = appScheme?.glassBorder ?? colorScheme.outlineVariant;
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
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smd,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: glassBorder, width: AppBorder.hairline),
            boxShadow: AppShadow.floating,
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
                      // One primitive per live state: the accent dot
                      // breathes while the turn progresses and freezes
                      // into a static ring while it winds down. Muted
                      // while stopping — the copy already says so.
                      : stopping
                      ? _StatusRing(color: colorScheme.onSurfaceVariant)
                      : _BreathingAccentDot(gradient: accentGradient),
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
                    fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

/// Accent-gradient dot that breathes (scale + opacity) while the agent
/// works. Honours `MediaQuery.disableAnimations` by rendering the same
/// dot fully opaque and motionless — no ticker is ever started.
class _BreathingAccentDot extends StatefulWidget {
  const _BreathingAccentDot({required this.gradient});

  final LinearGradient gradient;

  @override
  State<_BreathingAccentDot> createState() => _BreathingAccentDotState();
}

class _BreathingAccentDotState extends State<_BreathingAccentDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _animationsDisabled;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: AppDuration.pulse, vsync: this);
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
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.gradient,
      ),
    );
    if (_animationsDisabled ?? false) return dot;
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.55,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.85,
          end: 1.0,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        alignment: Alignment.center,
        child: dot,
      ),
    );
  }
}

/// Static hollow ring for the winding-down state — same footprint as the
/// breathing dot, no animation, so a stop request visibly settles the
/// chrome instead of trading one pulse for another.
class _StatusRing extends StatelessWidget {
  const _StatusRing({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: AppBorder.thin),
      ),
    );
  }
}
