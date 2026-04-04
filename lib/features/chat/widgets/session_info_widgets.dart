import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Status chip showing online/offline indicator.
class StatusChip extends StatelessWidget {
  /// Creates a [StatusChip].
  const StatusChip({required this.isActive, super.key});

  /// Whether the session is active (online).
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final activeColor = cs.primary;
    final inactiveColor = cs.onSurfaceVariant;
    final chipColor = isActive ? activeColor : inactiveColor;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: AppOpacity.soft),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            decoration: BoxDecoration(
              color: chipColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xsm),
          Text(
            isActive
                ? AppLocalizations.of(context).sessionInfoActive
                : AppLocalizations.of(context).sessionInfoInactive,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w500,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row displaying an icon, label, and value.
class InfoRow extends StatelessWidget {
  /// Creates an [InfoRow].
  const InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
    this.onTap,
    this.iconColor,
  });

  /// The leading icon.
  final IconData icon;

  /// The label text.
  final String label;

  /// The value text.
  final String value;

  /// Optional tap callback (shows copy icon when set).
  final VoidCallback? onTap;

  /// Optional override for the icon color.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.copy,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// A tappable action row used in Quick Actions and Copy Metadata.
class ActionRow extends StatelessWidget {
  /// Creates an [ActionRow].
  const ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
    this.onTap,
    this.isLoading = false,
  });

  /// The leading icon.
  final IconData icon;

  /// The label text.
  final String label;

  /// The color for icon, text, and trailing element.
  final Color color;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Whether to show a loading spinner.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                size: AppSpacing.xl,
                color: color.withValues(
                  alpha: AppOpacity.high,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
