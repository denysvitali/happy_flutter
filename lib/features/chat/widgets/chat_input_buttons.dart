import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';

// Animation duration constants.
const kBorderAnimDuration = AppDuration.fast;
const kSendAnimDuration = AppDuration.fast;
const kSwitchAnimDuration = AppDuration.fast;

// Checkmark morph duration — scale + fade in/out.
const kCheckMorphDuration = AppDuration.normal;

// How long the checkmark stays visible before reverting.
const kCheckHoldDuration = AppDuration.slower;

/// Explicit Codex follow-up action shown while a turn is active.
///
/// Unlike the primary send button, this asks the daemon to retain the
/// message for a fresh turn instead of steering the currently running one.
class QueueNextTurnButton extends StatelessWidget {
  const QueueNextTurnButton({
    required this.isDisabled,
    required this.onTap,
    super.key,
  });

  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = context.l10n.chatQueueNextTurn;
    final enabled = !isDisabled;
    return Semantics(
      key: const ValueKey<String>('queue-next-turn-button'),
      container: true,
      label: label,
      button: true,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: IconButton(
          onPressed: enabled ? onTap : null,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(AppTouchTarget.min),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: enabled
                    ? cs.primary.withValues(alpha: 0.6)
                    : cs.outlineVariant.withValues(alpha: 0.4),
                width: AppBorder.thin,
              ),
            ),
            child: Icon(
              Icons.schedule_send_rounded,
              size: AppIconSize.lg,
              color: enabled
                  ? cs.primary
                  : cs.onSurface.withValues(
                      alpha: AppMotion.disabledContentOpacity,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Send button — circular, matches iMessage's arrow-up design.
///
/// When [lastDeliveryStatus] transitions to `'sent'` the button
/// briefly morphs to a checkmark via a scale + fade animation
/// before returning to idle state.
class SendButton extends StatefulWidget {
  const SendButton({
    required this.isSending,
    required this.isSendDisabled,
    required this.onTap,
    required this.scaleAnimation,
    super.key,
    this.lastDeliveryStatus,
    this.actionLabel,
  });

  final bool isSending;
  final bool isSendDisabled;
  final VoidCallback onTap;
  final Animation<double> scaleAnimation;

  /// Overrides the default send tooltip and accessibility label.
  final String? actionLabel;

  /// Delivery status of the most-recently sent message.
  /// When this becomes `'sent'` the button plays a checkmark morph.
  final String? lastDeliveryStatus;

  @override
  State<SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<SendButton>
    with SingleTickerProviderStateMixin {
  bool _justSent = false;
  Timer? _revertTimer;
  late final AnimationController _morphCtrl;
  late final Animation<double> _morphScale;

  @override
  void initState() {
    super.initState();
    _morphCtrl = AnimationController(
      vsync: this,
      duration: kCheckMorphDuration,
    );
    // Scale sequence: 0.7 → 1.2 → 1.0 (elastic overshoot feel).
    _morphScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.7,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_morphCtrl);
  }

  @override
  void didUpdateWidget(SendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasDelivered = oldWidget.lastDeliveryStatus == 'sent';
    final isDelivered = widget.lastDeliveryStatus == 'sent';
    if (!wasDelivered && isDelivered && !_justSent) {
      _triggerMorph();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _morphCtrl.duration = AppMotion.duration(context, kCheckMorphDuration);
  }

  void _triggerMorph() {
    _revertTimer?.cancel();
    // Confirm delivery with a tactile tick alongside the checkmark.
    HapticFeedback.lightImpact();
    setState(() => _justSent = true);
    if (AppMotion.reduceMotion(context)) {
      _morphCtrl.value = 1;
    } else {
      _morphCtrl.forward(from: 0);
    }
    _revertTimer = Timer(kCheckMorphDuration + kCheckHoldDuration, () {
      if (mounted) {
        setState(() => _justSent = false);
      }
    });
  }

  @override
  void dispose() {
    _revertTimer?.cancel();
    _morphCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final l10n = AppLocalizations.of(context);
    final canSend = !widget.isSendDisabled && !widget.isSending;

    // A newly typed draft takes precedence over the transient confirmation.
    final showCheck = _justSent && !canSend;
    final isActive = canSend || showCheck || widget.isSending;
    final semanticLabel = widget.isSending
        ? l10n.chatSending
        : showCheck
        ? l10n.chatSent
        : widget.actionLabel ?? l10n.chatSendMessage;

    final icon = ScaleTransition(
      scale: widget.scaleAnimation,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, kBorderAnimDuration),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isActive ? appCs.accentLinearGradient : null,
          // Empty draft: inactive but still recognizably Send.
          color: isActive ? null : cs.onSurface.withValues(alpha: 0.08),
          boxShadow: isActive
              ? AppElevationShadow.interactive(theme.brightness)
              : null,
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.duration(context, kSwitchAnimDuration),
          switchInCurve: AppCurve.enter,
          switchOutCurve: AppCurve.exit,
          transitionBuilder: (child, animation) {
            if (AppMotion.reduceMotion(context)) return child;
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: showCheck
                    ? _morphScale
                    : animation.drive(Tween<double>(begin: 0.7, end: 1)),
                child: child,
              ),
            );
          },
          child: showCheck
              ? Icon(
                  key: const ValueKey('check'),
                  Icons.check_rounded,
                  size: AppIconSize.lg,
                  color: Colors.white,
                )
              : widget.isSending
              ? Padding(
                  key: const ValueKey('spinner'),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: AppCircularProgressIndicator(
                    strokeWidth: AppBorder.thin,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  key: const ValueKey('send'),
                  Icons.arrow_upward_rounded,
                  size: AppIconSize.lg,
                  color: canSend
                      ? Colors.white
                      : cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      button: true,
      enabled: canSend,
      liveRegion: widget.isSending || showCheck,
      onTap: canSend ? widget.onTap : null,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: IconButton(
          onPressed: canSend ? widget.onTap : null,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(AppTouchTarget.min),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: icon,
        ),
      ),
    );
  }
}
