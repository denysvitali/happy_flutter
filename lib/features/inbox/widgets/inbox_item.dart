import 'package:flutter/material.dart';

import '../../../core/components/app_tappable.dart';
import '../../../core/components/avatar.dart';
import '../../../core/theme/app_colors.dart';
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
    this.showStatusDot = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final String userId;
  final String? avatarUrl;
  final Widget trailing;
  final bool showStatusDot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.sm,
      ),
      child: AppTappable(
        borderRadius:
            BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: cs.outlineVariant.withValues(
                alpha: 0.4,
              ),
            ),
          ),
          child: Row(
            children: [
              if (showStatusDot)
                InboxAvatarWithStatus(
                  userId: userId,
                  avatarUrl: avatarUrl,
                  size: AppTouchTarget.min,
                  isOnline: false,
                )
              else
                Avatar(
                  id: userId,
                  size: AppTouchTarget.min,
                  imageUrl: avatarUrl,
                ),
              const SizedBox(width: AppSpacing.md),
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme
                          .textTheme.bodyMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(
                      height: AppSpacing.xsm,
                    ),
                    Text(
                      subtitle,
                      style: theme
                          .textTheme.bodySmall
                          ?.copyWith(
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

/// Small avatar overlay with an online/offline dot.
class InboxAvatarWithStatus extends StatelessWidget {
  const InboxAvatarWithStatus({
    required this.userId,
    required this.size,
    this.isOnline = false,
    this.avatarUrl,
    super.key,
  });

  final String userId;
  final String? avatarUrl;
  final double size;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dotSize = size * 0.26;
    final borderWidth = size * 0.06;

    return SizedBox(
      width: size + dotSize / 2,
      height: size + dotSize / 2,
      child: Stack(
        children: [
          Avatar(
            id: userId,
            size: size,
            imageUrl: avatarUrl,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline
                    ? AppColors.success
                    : cs.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                border: Border.all(
                  color: cs.surface,
                  width: borderWidth,
                ),
              ),
            ),
          ),
        ],
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
    this.showStatusDot = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final String userId;
  final String? avatarUrl;
  final Widget trailing;
  final bool showStatusDot;

  @override
  Widget build(BuildContext context) {
    return InboxItem(
      title: title,
      subtitle: subtitle,
      userId: userId,
      avatarUrl: avatarUrl,
      trailing: trailing,
      showStatusDot: showStatusDot,
    );
  }
}
