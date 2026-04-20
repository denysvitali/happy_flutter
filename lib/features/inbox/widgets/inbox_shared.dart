import 'package:flutter/material.dart';

import '../../../core/components/app_empty_state.dart';
import '../../../core/components/shimmer_view.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/feed.dart';
import '../../../core/models/friend.dart';
import '../../../core/theme/app_tokens.dart';

// ── Section header ─────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: cs.onSurfaceVariant,
            ).apply(
              fontFeatures: [const FontFeature.enable('smcp')],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Divider(
              height: 1,
              color: cs.outlineVariant.withValues(
                alpha: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inbox header ─────────────────────────────────────────────────────────

class InboxHeader extends StatelessWidget {
  const InboxHeader({required this.onFindFriends, super.key});

  final VoidCallback onFindFriends;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.inboxTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onFindFriends,
          icon: const Icon(Icons.person_add_alt_1),
          label: Text(context.l10n.friendsAddFriend),
        ),
      ],
    );
  }
}

// ── Inbox list view ─────────────────────────────────────────────────────

class InboxListView extends StatelessWidget {
  const InboxListView({
    required this.descriptors,
    required this.onRefresh,
    required this.onFindFriends,
    required this.itemBuilder,
    super.key,
  });

  final List<InboxItemDescriptor> descriptors;
  final Future<void> Function() onRefresh;
  final VoidCallback onFindFriends;
  final Widget Function(BuildContext, InboxItemDescriptor) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        itemCount: descriptors.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return InboxHeader(onFindFriends: onFindFriends);
          }
          return itemBuilder(context, descriptors[index - 1]);
        },
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────

class InboxEmptyView extends StatelessWidget {
  const InboxEmptyView({
    required this.onFindFriends,
    required this.onRefresh,
    super.key,
  });

  final VoidCallback onFindFriends;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          InboxHeader(onFindFriends: onFindFriends),
          const SizedBox(height: AppSpacing.xxl),
          AppEmptyState(
            icon: Icons.inbox_outlined,
            title: context.l10n.inboxNoNotificationsTitle,
            subtitle: context.l10n.inboxConnectFriendsSubtitle,
            action: FilledButton.icon(
              onPressed: onFindFriends,
              icon: const Icon(Icons.person_search),
              label: Text(context.l10n.friendsAddFriend),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading shimmer ────────────────────────────────────────────────────

class InboxLoadingShimmer extends StatelessWidget {
  const InboxLoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest.withValues(
      alpha: 0.5,
    );

    Widget header() => Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
            left: AppSpacing.xs,
          ),
          child: Container(
            height: 12,
            width: 100,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(
                AppRadius.xs,
              ),
            ),
          ),
        );

    Widget row() => Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppRadius.md,
              ),
              border: Border.all(
                color: cs.outlineVariant.withValues(
                  alpha: 0.3,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: AppTouchTarget.min,
                  height: AppTouchTarget.min,
                  decoration: BoxDecoration(
                    color: base,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.xs,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: AppSpacing.xs,
                      ),
                      Container(
                        height: 12,
                        width: 140,
                        decoration: BoxDecoration(
                          color: base,
                          borderRadius:
                              BorderRadius.circular(
                            AppRadius.xs,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Shimmer(
      child: ListView(
        padding: AppScreenPadding.standard,
        children: [
          header(),
          row(),
          row(),
          row(),
          header(),
          row(),
          row(),
        ],
      ),
    );
  }
}

// ── Lazy item descriptors ───────────────────────────────────────────────

/// Lightweight type tag for each position in the unified inbox list.
enum InboxItemType {
  spacer,
  sectionHeader,
  feed,
  incomingRequest,
  sentRequest,
  friend,
}

/// Describes what widget should be rendered at a given list position
/// without allocating any widget instances. Widgets are built on-demand
/// by the inbox screen's item builder.
class InboxItemDescriptor {
  const InboxItemDescriptor.spacer()
    : type = InboxItemType.spacer,
      titleKey = null,
      feedItem = null,
      incomingRequest = null,
      userProfile = null;

  const InboxItemDescriptor.sectionHeader({
    required this.titleKey,
  }) : type = InboxItemType.sectionHeader,
       feedItem = null,
       incomingRequest = null,
       userProfile = null;

  const InboxItemDescriptor.feed({required this.feedItem})
    : type = InboxItemType.feed,
      titleKey = null,
      incomingRequest = null,
      userProfile = null;

  const InboxItemDescriptor.incomingRequest({
    required this.incomingRequest,
  }) : type = InboxItemType.incomingRequest,
       titleKey = null,
       feedItem = null,
       userProfile = null;

  const InboxItemDescriptor.sentRequest({
    required UserProfile this.userProfile,
  }) : type = InboxItemType.sentRequest,
       titleKey = null,
       feedItem = null,
       incomingRequest = null;

  const InboxItemDescriptor.friend({
    required UserProfile this.userProfile,
  }) : type = InboxItemType.friend,
       titleKey = null,
       feedItem = null,
       incomingRequest = null;

  final InboxItemType type;
  final String? titleKey;
  final FeedItem? feedItem;
  final FriendRequest? incomingRequest;
  final UserProfile? userProfile;
}
