import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';

// Animation duration constants.
const kBorderAnimDuration = Duration(milliseconds: 200);
const kSendAnimDuration = Duration(milliseconds: 120);
const kSwitchAnimDuration = Duration(milliseconds: 180);

// Checkmark morph duration — scale + fade in/out.
const kCheckMorphDuration = Duration(milliseconds: 300);

// How long the checkmark stays visible before reverting.
const kCheckHoldDuration = Duration(milliseconds: 900);

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
  });

  final bool isSending;
  final bool isSendDisabled;
  final VoidCallback onTap;
  final Animation<double> scaleAnimation;

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
        tween: Tween<double>(begin: 0.7, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_morphCtrl);
  }

  @override
  void didUpdateWidget(SendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasDelivered =
        oldWidget.lastDeliveryStatus == 'sent';
    final isDelivered =
        widget.lastDeliveryStatus == 'sent';
    if (!wasDelivered && isDelivered && !_justSent) {
      _triggerMorph();
    }
  }

  void _triggerMorph() {
    _revertTimer?.cancel();
    setState(() => _justSent = true);
    _morphCtrl.forward(from: 0);
    _revertTimer = Timer(
      kCheckMorphDuration + kCheckHoldDuration,
      () {
        if (mounted) {
          setState(() => _justSent = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _revertTimer?.cancel();
    _morphCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSend =
        !widget.isSendDisabled && !widget.isSending;

    // While morphed, keep button in an "active" appearance.
    final showCheck = _justSent;
    final effectiveCanSend = canSend || showCheck;

    return Semantics(
      label: 'Send',
      button: true,
      child: Tooltip(
        message: 'Send',
        child: GestureDetector(
          onTap: () {
            if (canSend) HapticFeedback.lightImpact();
            widget.onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppTouchTarget.min,
              minHeight: AppTouchTarget.min,
            ),
            child: Center(
              child: ScaleTransition(
                scale: widget.scaleAnimation,
                child: AnimatedContainer(
                  duration: kBorderAnimDuration,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: effectiveCanSend
                        ? cs.primary
                        : cs.onSurface
                            .withValues(alpha: 0.08),
                    boxShadow: effectiveCanSend
                        ? [
                            BoxShadow(
                              color: cs.primary
                                  .withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset:
                                  const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedSwitcher(
                    duration: kCheckMorphDuration,
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    transitionBuilder: (child, anim) {
                      return FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: showCheck
                              ? _morphScale
                              : anim.drive(
                                  Tween<double>(
                                    begin: 0.7,
                                    end: 1.0,
                                  ),
                                ),
                          child: child,
                        ),
                      );
                    },
                    child: showCheck
                        ? Icon(
                            key: const ValueKey(
                              'check',
                            ),
                            Icons.check_rounded,
                            size: 18,
                            color: cs.onPrimary,
                          )
                        : widget.isSending
                        ? Padding(
                            key: const ValueKey(
                              'spinner',
                            ),
                            padding:
                                const EdgeInsets.all(
                              AppSpacing.sm,
                            ),
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color:
                                  cs.onSurfaceVariant,
                            ),
                          )
                        : Icon(
                            key: const ValueKey(
                              'send',
                            ),
                            Icons
                                .arrow_upward_rounded,
                            size: 18,
                            color: canSend
                                ? cs.onPrimary
                                : cs.onSurface
                                    .withValues(
                                    alpha: 0.25,
                                  ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
