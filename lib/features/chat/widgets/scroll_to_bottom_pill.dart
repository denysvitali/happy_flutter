import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_tokens.dart';

/// A pill-shaped button that scrolls to the bottom of the chat.
///
/// Enters with a scale+fade animation and bounces the arrow
/// icon subtly to draw the user's eye.
class ScrollToBottomPill extends StatefulWidget {
  /// Creates a scroll-to-bottom pill
  const ScrollToBottomPill({
    required this.onTap,
    super.key,
    this.unreadCount,
  });

  /// Callback when the pill is tapped
  final VoidCallback onTap;

  /// Optional unread message count to show as a badge.
  final int? unreadCount;

  @override
  State<ScrollToBottomPill> createState() =>
      _ScrollToBottomPillState();
}

class _ScrollToBottomPillState extends State<ScrollToBottomPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scale = Tween(begin: 0.6, end: 1.0).animate(
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
    final showBadge =
        widget.unreadCount != null && widget.unreadCount! > 0;

    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: child,
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
              Material(
                color: cs.surface,
                borderRadius: BorderRadius.circular(
                  AppRadius.pill,
                ),
                elevation: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      AppRadius.pill,
                    ),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            cs.shadow.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color:
                            cs.shadow.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onTap();
                    },
                    borderRadius: BorderRadius.circular(
                      AppRadius.pill,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
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
                    duration: const Duration(
                      milliseconds: 200,
                    ),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) =>
                        Transform.scale(
                      scale: value,
                      child: child,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(
                          AppRadius.pill,
                        ),
                      ),
                      constraints: const BoxConstraints(
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
