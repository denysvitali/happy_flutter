import 'package:flutter/material.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/components/app_tappable.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/feed.dart';
import '../../../core/theme/app_tokens.dart';

/// Individual feed activity row with avatar, title, message and timestamp.
class FeedCard extends StatelessWidget {
  const FeedCard({
    required this.item,
    required this.l10n,
    this.onTap,
    super.key,
  });

  final FeedItem item;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUnread = !item.read;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isUnread
                ? cs.primary.withValues(alpha: 0.06)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isUnread
                  ? cs.primary.withValues(alpha: 0.18)
                  : cs.outlineVariant.withValues(alpha: 0.55),
              width: AppBorder.hairline,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppTouchTarget.min,
                height: AppTouchTarget.min,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  item.body.kind == 'friend_request'
                      ? Icons.person_add_alt_1
                      : Icons.notifications,
                  size: AppSpacing.xl,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Title + preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bodyTitle(item.body),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isUnread
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_bodyPreview(item.body) != null) ...[
                      const SizedBox(height: AppSpacing.xsm),
                      Text(
                        _bodyPreview(item.body)!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Timestamp + unread indicator column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _timeAgo(item.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: AppFontSize.sm,
                      color: isUnread ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (isUnread) ...[
                    const SizedBox(height: AppSpacing.xs),
                    AppStatusDot(
                      color: cs.primary,
                      size: AppSpacing.sm,
                      pulse: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _bodyTitle(FeedBody body) {
    switch (body.kind) {
      case 'friend_request':
        return l10n.inboxFeedFriendRequest;
      case 'friend_accepted':
        return l10n.inboxFeedFriendAccepted;
      case 'text':
        return l10n.inboxFeedUpdate;
      default:
        return l10n.inboxFeedUpdate;
    }
  }

  String? _bodyPreview(FeedBody body) {
    final text = body.text;
    if (text == null || text.trim().isEmpty) {
      return null;
    }
    return text;
  }

  String _timeAgo(int createdAtMs) {
    final created = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    final now = DateTime.now();
    final diff = now.difference(created);
    if (diff.inMinutes < 1) {
      return l10n.inboxTimeNow;
    }
    if (diff.inMinutes < 60) {
      return l10n.inboxTimeMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return l10n.inboxTimeHoursAgo(diff.inHours);
    }
    // Yesterday check
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final createdDate = DateTime(created.year, created.month, created.day);
    if (createdDate == yesterday) {
      return l10n.inboxTimeYesterday;
    }
    // Older — show short date
    return '${created.month}/${created.day}';
  }
}
