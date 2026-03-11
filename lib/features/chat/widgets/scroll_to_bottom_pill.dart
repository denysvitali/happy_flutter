import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_tokens.dart';

/// A pill-shaped button that scrolls to the bottom of the
/// chat. Enters with a scale+fade+slide animation and
/// uses a subtle shadow for depth.
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
  State<ScrollToBottomPill> createState() =>
      _ScrollToBottomPillState();
}

class _ScrollToBottomPillState
    extends State<ScrollToBottomPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );
    _scale = Tween(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Curves.easeOutBack,
      ),
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Curves.easeOut,
      ),
    );
    _slide = Tween(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Curves.easeOutCubic,
      ),
    );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showBadge = widget.unreadCount != null &&
        widget.unreadCount! > 0;

    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (context, child) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: ScaleTransition(
            scale: _scale,
            child: child,
          ),
        ),
      ),
      child: Semantics(
        label: 'Scroll to latest message',
        button: true,
        child: Tooltip(
          message: 'Scroll to latest message',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    AppRadius.pill,
                  ),
                  boxShadow: AppShadow.card,
                ),
                child: Material(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(
                    AppRadius.pill,
                  ),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onTap();
                    },
                    borderRadius: BorderRadius.circular(
                      AppRadius.pill,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          AppRadius.pill,
                        ),
                        border: Border.all(
                          color: cs.outlineVariant
                              .withValues(alpha: 0.3),
                          width: AppBorder.hairline,
                        ),
                      ),
                      child: Icon(
                        Icons
                            .keyboard_double_arrow_down_rounded,
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
                    tween: Tween(
                      begin: 0.0,
                      end: 1.0,
                    ),
                    duration: AppDuration.fast,
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) =>
                        Transform.scale(
                      scale: value,
                      child: child,
                    ),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius:
                            BorderRadius.circular(
                          AppRadius.pill,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary
                                .withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset:
                                const Offset(0, 1),
                          ),
                        ],
                      ),
                      constraints:
                          const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        widget.unreadCount! > 99
                            ? '99+'
                            : '${widget.unreadCount}',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 10,
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
