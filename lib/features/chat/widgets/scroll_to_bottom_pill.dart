import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';

/// A pill-shaped button that scrolls to the bottom of the chat
class ScrollToBottomPill extends StatelessWidget {
  /// Creates a scroll-to-bottom pill
  const ScrollToBottomPill({required this.onTap, super.key});

  /// Callback when the pill is tapped
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
