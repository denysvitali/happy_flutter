import 'dart:async';

import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_inline_row.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'chat_chrome_density.dart';

/// What the agent is doing right now, from the chat's point of view.
///
/// The activity states share one bar so a stop request never stacks a
/// second live indicator on top of the "thinking" one, and never
/// changes the chrome's height mid-turn.
enum ChatAgentActivity {
  /// The request is being delivered; the agent has not acknowledged it.
  sending,

  /// Delivery succeeded; awaiting the first agent response.
  waiting,

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

/// Shared inline status row above the composer with a persistent Stop action.
/// The indicator conveys activity while the text explains delivery/stop state.
class ThinkingStopBar extends StatelessWidget {
  const ThinkingStopBar({
    required this.onStop,
    this.activity = ChatAgentActivity.thinking,
    this.workLabel,
    this.startedAt,
    super.key,
  });

  final VoidCallback onStop;

  /// Current agent activity. Drives the leading indicator, the label,
  /// and whether the stop action is tappable.
  final ChatAgentActivity activity;
  final String? workLabel;
  final int? startedAt;

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
    final l10n = context.l10n;
    final stopping = activity == ChatAgentActivity.stopping;
    final unconfirmed = activity == ChatAgentActivity.stopUnconfirmed;
    final awaiting =
        activity == ChatAgentActivity.sending ||
        activity == ChatAgentActivity.waiting;
    final label = switch (activity) {
      ChatAgentActivity.sending => l10n.chatSending,
      ChatAgentActivity.waiting => l10n.chatActivityWaiting,
      ChatAgentActivity.thinking => workLabel ?? l10n.chatActivityThinking,
      ChatAgentActivity.stopping => l10n.chatActivityStopping,
      ChatAgentActivity.stopUnconfirmed => l10n.chatActivityStopUnconfirmed,
    };
    // Short panes shed the capsule's floating margin and inner padding: the
    // bar still sits between the list and the composer with the same Stop
    // affordance, it just stops costing a full touch target of margin.
    final dense = chatChromeIsSlim(context);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: dense ? 0 : AppSpacing.xxs,
        ),
        child: AppInlineRow(
          leading: unconfirmed
              ? const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.warning,
                )
              : stopping || awaiting
              ? _StatusRing(color: colorScheme.onSurfaceVariant)
              : _BreathingAccentDot(gradient: accentGradient),
          trailing: startedAt == null
              ? null
              : ExcludeSemantics(child: _ElapsedLabel(startedAt: startedAt!)),
          action: AppInlineAction(
            label: l10n.chatActivityStop,
            icon: Icons.stop_rounded,
            color: colorScheme.error,
            onPressed: stopping || awaiting ? null : onStop,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppInlineText.secondary(
              context,
            ).copyWith(color: unconfirmed ? AppColors.warning : null),
          ),
        ),
      ),
    );
  }
}

/// One low-frequency clock, scoped to a visible active bar. Never ticks when
/// the route/window has muted its tickers, and never announces every second.
class _ElapsedLabel extends StatefulWidget {
  const _ElapsedLabel({required this.startedAt});
  final int startedAt;

  @override
  State<_ElapsedLabel> createState() => _ElapsedLabelState();
}

class _ElapsedLabelState extends State<_ElapsedLabel> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (TickerMode.valuesOf(context).enabled) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().millisecondsSinceEpoch - widget.startedAt;
    final seconds = elapsed.clamp(0, 1 << 53) ~/ 1000;
    final minutes = seconds ~/ 60;
    // Past an hour, "545m 3s" is unreadable — switch to hours and minutes.
    final label = seconds >= 3600
        ? '${seconds ~/ 3600}h ${minutes % 60}m'
        : minutes == 0
        ? '${seconds}s'
        : '${minutes}m ${seconds % 60}s';
    return Text(
      label,
      style: AppInlineText.secondary(
        context,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(
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
