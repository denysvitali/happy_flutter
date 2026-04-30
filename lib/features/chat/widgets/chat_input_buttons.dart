import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';

// Animation duration constants.
const kBorderAnimDuration = Duration(milliseconds: 200);
const kSendAnimDuration = Duration(milliseconds: 120);
const kSwitchAnimDuration = Duration(milliseconds: 180);

/// Send button — circular, matches iMessage's arrow-up design.
class SendButton extends StatelessWidget {
  const SendButton({
    required this.isSending,
    required this.isSendDisabled,
    required this.onTap,
    required this.scaleAnimation,
    super.key,
  });

  final bool isSending;
  final bool isSendDisabled;
  final VoidCallback onTap;
  final Animation<double> scaleAnimation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSend = !isSendDisabled && !isSending;

    return Semantics(
      label: 'Send',
      button: true,
      child: Tooltip(
        message: 'Send',
        child: GestureDetector(
          onTap: () {
            if (canSend) HapticFeedback.lightImpact();
            onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppTouchTarget.min,
              minHeight: AppTouchTarget.min,
            ),
            child: Center(
              child: ScaleTransition(
                scale: scaleAnimation,
                child: AnimatedContainer(
                  duration: kBorderAnimDuration,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canSend
                        ? cs.primary
                        : cs.onSurface
                            .withValues(alpha: 0.08),
                    boxShadow: canSend
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
                    duration: kSwitchAnimDuration,
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    transitionBuilder:
                        (child, anim) =>
                            FadeTransition(
                      opacity: anim,
                      child: child,
                    ),
                    child: isSending
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
