import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';

// Animation duration constants.
const kBorderAnimDuration = Duration(milliseconds: 200);
const kSendAnimDuration = Duration(milliseconds: 120);
const kSwitchAnimDuration = Duration(milliseconds: 180);

/// Abort button — minimal pill with stop icon.
class AbortButton extends StatelessWidget {
  const AbortButton({
    required this.isAborting,
    super.key,
    this.onTap,
  });

  final bool isAborting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isAborting ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        child: Center(
          child: AnimatedContainer(
            duration: kBorderAnimDuration,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.1),
              borderRadius:
                  BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: cs.error.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: AnimatedSwitcher(
              duration: kSwitchAnimDuration,
              child: isAborting
                  ? SizedBox(
                      key: const ValueKey('abort-spinner'),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: cs.error,
                      ),
                    )
                  : Row(
                      key: const ValueKey('abort-icon'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stop_rounded,
                          size: 14,
                          color: cs.error,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Stop',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.error,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

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

    return GestureDetector(
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
                    : cs.onSurface.withValues(alpha: 0.08),
                boxShadow: canSend
                    ? [
                        BoxShadow(
                          color: cs.primary
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: kSwitchAnimDuration,
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, anim) =>
                    FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: isSending
                    ? Padding(
                        key: const ValueKey('spinner'),
                        padding: const EdgeInsets.all(
                          AppSpacing.sm,
                        ),
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : Icon(
                        key: const ValueKey('send'),
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: canSend
                            ? cs.onPrimary
                            : cs.onSurface
                                .withValues(alpha: 0.25),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
