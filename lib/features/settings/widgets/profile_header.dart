import 'package:flutter/material.dart';

import '../../../core/models/profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/network_avatar_image.dart';

/// Compact account summary used at the top of Settings.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({required this.profile, super.key, this.onTap});

  final Profile? profile;
  final VoidCallback? onTap;

  static String _initialForName(String value) {
    if (value.isEmpty) return '?';
    return value.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = profile?.displayName?.trim();
    final avatarUrl = profile?.avatarUrl;
    final displayName = (name == null || name.isEmpty) ? 'Happy' : name;
    final bio = profile?.bio ?? 'Secure mobile companion for your sessions';

    return Semantics(
      button: onTap != null,
      label: '$displayName. $bio',
      excludeSemantics: true,
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: AppOpacity.medium),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (avatarUrl != null)
                  NetworkAvatarImage(
                    url: avatarUrl,
                    size: AppTouchTarget.comfortable,
                    fallback: _ProfileInitialAvatar(displayName: displayName),
                  )
                else
                  _ProfileInitialAvatar(displayName: displayName),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        bio,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileInitialAvatar extends StatelessWidget {
  const _ProfileInitialAvatar({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return CircleAvatar(
      radius: AppTouchTarget.comfortable / 2,
      backgroundColor: cs.primaryContainer,
      child: Text(
        ProfileHeader._initialForName(displayName),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}
