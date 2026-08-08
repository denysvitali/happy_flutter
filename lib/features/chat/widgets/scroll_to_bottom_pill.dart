import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// A pill-shaped button that scrolls to the bottom of the
/// chat. Enters with a scale+fade+slide animation and
/// uses a subtle shadow for depth.
class ScrollToBottomPill extends StatefulWidget {
  /// Creates a scroll-to-bottom pill.
  const ScrollToBottomPill({required this.onTap, super.key, this.unreadCount});

  /// Callback when the pill is tapped.
  final VoidCallback onTap;

  /// Optional unread message count badge.
  final int? unreadCount;

  @override
  State<ScrollToBottomPill> createState() => _ScrollToBottomPillState();
}

class _ScrollToBottomPillState extends State<ScrollToBottomPill>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseGlow;

  int? _prevUnreadCount;

  @override
  void initState() {
    super.initState();
    // Physics-driven entry: the pill pops in on a real spring
    // (AppSpring.standard) rather than a fixed-duration curve, so the
    // overshoot and settle follow natural motion.
    _entryCtrl = AnimationController.unbounded(vsync: this);
    _entryCtrl.animateWith(SpringSimulation(AppSpring.standard, 0.0, 1.0, 0.0));

    _pulseCtrl = AnimationController(vsync: this, duration: AppDuration.fast);
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.28,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.28,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_pulseCtrl);
    _pulseGlow = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.3,
          end: 0.7,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.7,
          end: 0.3,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_pulseCtrl);

    _prevUnreadCount = widget.unreadCount;
  }

  @override
  void didUpdateWidget(ScrollToBottomPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prev = _prevUnreadCount ?? 0;
    final next = widget.unreadCount ?? 0;
    if (next > prev && next > 0) {
      _pulseCtrl
        ..stop()
        ..forward(from: 0);
    }
    _prevUnreadCount = widget.unreadCount;
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scrollLabel = context.l10n.chatScrollToLatest;
    final showBadge = widget.unreadCount != null && widget.unreadCount! > 0;
    final unreadValue = showBadge
        ? '${widget.unreadCount} ${context.l10n.missionControlStatUnread}'
        : null;

    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (context, child) {
        // Spring value overshoots 1.0 slightly; scale and slide may
        // follow the overshoot, but opacity must stay in range.
        final t = _entryCtrl.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: Transform.scale(
              scale: lerpDouble(0.7, 1.0, t)!,
              child: child,
            ),
          ),
        );
      },
      child: Semantics(
        label: scrollLabel,
        value: unreadValue,
        button: true,
        child: Tooltip(
          message: scrollLabel,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: AppShadow.card,
                ),
                child: Material(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onTap();
                    },
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: AppTouchTarget.min,
                        minHeight: AppTouchTarget.min,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.3),
                          width: AppBorder.hairline,
                        ),
                      ),
                      child: Icon(
                        Icons.keyboard_double_arrow_down_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              if (showBadge)
                Positioned(
                  top: -4,
                  right: -4,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: AppDuration.fast,
                    curve: Curves.easeOutBack,
                    builder: (context, entryValue, child) =>
                        Transform.scale(scale: entryValue, child: child),
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseScale.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withValues(
                                  alpha: _pulseGlow.value,
                                ),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: child,
                        ),
                      ),
                      child: Text(
                        widget.unreadCount! > 99
                            ? '99+'
                            : '${widget.unreadCount}',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: AppFontSize.xxs,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
