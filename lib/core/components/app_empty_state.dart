import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// Displays an icon, title, and optional subtitle for empty list states.
///
/// The icon sits inside a soft rounded container
/// ([AppSpacing.xxxl] × [AppSpacing.xxxl], radius [AppRadius.xl])
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container.
            Container(
              width: AppSpacing.xxxl * 2,
              height: AppSpacing.xxxl * 2,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(
                icon,
                size: AppSpacing.xxxl,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Title.
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            // Subtitle.
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
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
              const SizedBox(height: AppSpacing.xxl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
