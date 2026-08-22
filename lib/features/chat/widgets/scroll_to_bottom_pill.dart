import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_tokens.dart';

/// Floating "jump to latest" pill above the composer while the
/// transcript is scrolled away from the bottom.
///
/// Aurora-glass capsule: a translucent low-emphasis surface under a
/// hairline glass border, lifted by the shared floating shadow, with
/// the unread badge as its single accent-gradient element. Visibility
/// gating stays with the parent overlay; this widget only plays a
/// short fade-and-rise entrance (skipped entirely under reduced
/// motion) and pops the badge when the unread count grows.
class ScrollToBottomPill extends StatefulWidget {
  /// Creates a scroll-to-bottom pill.
  const ScrollToBottomPill({
    required this.onTap,
    super.key,
    this.unreadCount,
  });

  /// Callback when the pill is tapped.
  final VoidCallback onTap;

  /// Optional unread message count badge.
  final int? unreadCount;

  @override
  State<ScrollToBottomPill> createState() => _ScrollToBottomPillState();
}

class _ScrollToBottomPillState extends State<ScrollToBottomPill>
    with TickerProviderStateMixin {
  /// Translucent glass fill — opaque enough to stay readable over any
  /// message content sliding beneath it.
  static const double _fillAlpha = 0.92;
  static const double _badgePopPeak = 1.28;
  static const double _entranceRisePx = 14;

  late final AnimationController _entryCtrl;
  late final CurvedAnimation _entryCurve;
  late final Animation<double> _entryRise;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  int? _prevUnreadCount;
  bool _entryArmed = false;

  @override
  void initState() {
    super.initState();
    _prevUnreadCount = widget.unreadCount;
    _entryCtrl = AnimationController(vsync: this);
    _entryCurve = CurvedAnimation(
      parent: _entryCtrl,
      curve: AppCurve.standard,
    );
    _entryRise = Tween<double>(begin: _entranceRisePx, end: 0)
        .animate(_entryCurve);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: AppDuration.fast,
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: _badgePopPeak,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _badgePopPeak,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_pulseCtrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entryArmed) return;
    _entryArmed = true;
    // Reduced motion: no entrance — the pill is simply there.
    if (AppMotion.reduceMotion(context)) {
      _entryCtrl.value = 1.0;
      return;
    }
    _entryCtrl.duration = AppMotion.duration(context, AppDuration.fast);
    _entryCtrl.forward();
  }

  @override
  void didUpdateWidget(ScrollToBottomPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.unreadCount ?? 0;
    final prev = _prevUnreadCount ?? 0;
    _prevUnreadCount = widget.unreadCount;
    if (next > prev && next > 0) {
      _pulseCtrl
        ..stop()
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final glass =
        theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final scrollLabel = context.l10n.chatScrollToLatest;
    final count = widget.unreadCount ?? 0;
    final showBadge = count > 0;
    final unreadValue = showBadge
        ? '${widget.unreadCount} ${context.l10n.missionControlStatUnread}'
        : null;
    final shape = BorderRadius.circular(AppRadius.pill);

    return Semantics(
      label: scrollLabel,
      value: unreadValue,
      button: true,
      child: Tooltip(
        message: scrollLabel,
        child: AnimatedBuilder(
          animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
          builder: (context, child) {
            return Opacity(
              opacity: _entryCurve.value,
              child: Transform.translate(
                offset: Offset(0, _entryRise.value),
                child: child,
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The capsule body is inlined here rather than extracted:
              // this Semantics wrapper must lexically contain the
              // InkWell for the icon-only a11y source scan to see it.
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shape,
                  boxShadow: AppShadow.floating,
                ),
                child: Material(
                  color: cs.surfaceContainerLow.withValues(alpha: _fillAlpha),
                  borderRadius: shape,
                  child: InkWell(
                    borderRadius: shape,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onTap();
                    },
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
                        borderRadius: shape,
                        border: Border.all(
                          color: glass.glassBorder,
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
                  child: ScaleTransition(
                    scale: _pulseScale,
                    child: _buildBadge(glass, cs, count),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Accent-gradient unread counter — the pill's single saturated
  /// element, popping once each time the count grows.
  Widget _buildBadge(AppColorScheme glass, ColorScheme cs, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        gradient: glass.accentLinearGradient,
        boxShadow: [
          BoxShadow(
            color: glass.accentGradient.first.withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: AppFontSize.xxs,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
    );
  }
}
