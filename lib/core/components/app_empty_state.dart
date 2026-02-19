import 'package:flutter/material.dart';

/// Displays an icon, title, and optional subtitle for empty list states.
///
/// The icon sits inside a soft rounded container (64 x 64 px, radius 16)
/// with a [ColorScheme.surfaceContainerHighest] background. Title uses
/// [TextTheme.titleMedium]; subtitle uses [TextTheme.bodyMedium] at
/// 60 % opacity.
class AppEmptyState extends StatelessWidget {
  /// Creates an empty-state placeholder.
  const AppEmptyState({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.action,
  });

  /// The icon to display inside the rounded container.
  final IconData icon;

  /// The primary message (required).
  final String title;

  /// Secondary description shown beneath the title.
  final String? subtitle;

  /// Optional action widget shown below the description (e.g. a button).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container.
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 32,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // Title.
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            // Subtitle.
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            // Action widget.
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
