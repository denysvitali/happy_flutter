import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// A pill-shaped button that scrolls to the bottom of the chat
class ScrollToBottomPill extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showBadge =
        unreadCount != null && unreadCount! > 0;

    return Semantics(
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
              elevation: 2,
              shadowColor: cs.shadow.withValues(alpha: 0.2),
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
                ),
                child: InkWell(
                  onTap: onTap,
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
                    '${unreadCount! > 99 ? '99+' : unreadCount}',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
