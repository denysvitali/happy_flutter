import 'package:flutter/material.dart';

import '../../../core/components/app_tappable.dart';
import '../../../core/components/avatar.dart';
import '../../../core/theme/app_tokens.dart';

/// A polished inbox list row: 44 px avatar on the left,
/// name + subtitle in the center, optional trailing
/// widget on the right.
class InboxItem extends StatelessWidget {
  const InboxItem({
    required this.title,
    required this.subtitle,
    required this.userId,
    required this.avatarUrl,
    required this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final String userId;
  final String? avatarUrl;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppTappable(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          constraints: const BoxConstraints(minHeight: 68),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.55),
              width: AppBorder.hairline,
            ),
          ),
          child: Row(
            children: [
              Avatar(id: userId, size: AppTouchTarget.min, imageUrl: avatarUrl),
              const SizedBox(width: AppSpacing.md),
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xsm),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic user row (sent requests, friends list) that
/// wraps [InboxItem].
class UserRow extends StatelessWidget {
  const UserRow({
    required this.title,
    required this.subtitle,
    required this.userId,
    required this.avatarUrl,
    required this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final String userId;
  final String? avatarUrl;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return InboxItem(
      title: title,
      subtitle: subtitle,
      userId: userId,
      avatarUrl: avatarUrl,
      trailing: trailing,
    );
  }
}
