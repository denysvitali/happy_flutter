import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/components/app_tappable.dart';
import '../../core/components/avatar.dart';
import '../../core/components/shimmer_view.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/feed.dart';
import '../../core/models/friend.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/social_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/sync_subscription_mixin.dart';

/// Selector value for friends data used in inbox.
class _InboxFriendsData {
  _InboxFriendsData({
    required this.friendList,
    required this.incomingRequests,
    required this.requested,
  });

  final List<UserProfile> friendList;
  final List<FriendRequest> incomingRequests;
  final List<UserProfile> requested;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _InboxFriendsData &&
          listEquals(friendList, other.friendList) &&
          listEquals(incomingRequests, other.incomingRequests) &&
          listEquals(requested, other.requested);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(friendList),
        Object.hashAll(incomingRequests),
        Object.hashAll(requested),
      );
}

/// Selector value for feed data used in inbox.
class _InboxFeedData {
  _InboxFeedData({required this.items, required this.unreadCount});

  final List<FeedItem> items;
  final int unreadCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _InboxFeedData &&
          listEquals(items, other.items) &&
          unreadCount == other.unreadCount;

  @override
  int get hashCode => Object.hash(Object.hashAll(items), unreadCount);
}

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen>
    with SyncSubscriptionMixin {
  final SocialService _socialService = SocialService();
  final Set<String> _busyIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
    subscribeToDataChanged(ref, () {
      ref.read(friendsNotifierProvider.notifier).loadFromSync();
      ref.read(feedNotifierProvider.notifier).loadFromSync();
    });
  }

  Future<void> _refresh() async {
    // Parallelize independent refresh operations for faster loading
    await Future.wait([
      ref.read(friendsNotifierProvider.notifier).refreshFromSync(),
      ref.read(feedNotifierProvider.notifier).refreshFromSync(),
    ]);
    if (mounted && _isLoading) {
      setState(() => _isLoading = false);
    }
  }

  bool _isItemBusy(String id) => _busyIds.contains(id);

  Future<void> _runFriendAction(
    String itemId,
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _busyIds.add(itemId));
    try {
      await action();
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
        content: Text(context.l10n.friendsActionFailed),
      ));
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(itemId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsData = ref.watch(
      friendsNotifierProvider.select((state) => _InboxFriendsData(
            friendList: state.friendList,
            incomingRequests: state.incomingRequests,
            requested: state.friends
                .where(
                  (f) => f.status == RelationshipStatus.requested,
                )
                .toList(growable: false),
          )),
    );
    final feedData = ref.watch(
      feedNotifierProvider.select((state) => _InboxFeedData(
            items: state.items,
            unreadCount: state.unreadCount,
          )),
    );
    final friends = friendsData.friendList;
    final incoming = friendsData.incomingRequests;
    final requested = friendsData.requested;

    final isEmpty =
        feedData.items.isEmpty &&
        incoming.isEmpty &&
        requested.isEmpty &&
        friends.isEmpty;

    if (_isLoading) {
      return _InboxLoadingShimmer();
    }

    if (isEmpty) {
      return _InboxEmptyView(
        onFindFriends: _showFindFriendsSheet,
        onRefresh: _refresh,
      );
    }

    // Build lightweight descriptors — widgets are created lazily in
    // itemBuilder to avoid allocating hundreds of widget objects for
    // large friend lists / feed items that may never be scrolled to.
    final descriptors = _buildDescriptors(
      feedData.items,
      incoming,
      requested,
      friends,
    );

    return _InboxListView(
      descriptors: descriptors,
      onRefresh: _refresh,
      onFindFriends: _showFindFriendsSheet,
      itemBuilder: _buildItem,
    );
  }

  /// Builds a flat list of lightweight descriptors that describe what
  /// widget to render at each position without allocating any widgets.
  List<_InboxItemDescriptor> _buildDescriptors(
    List<FeedItem> feedItems,
    List<FriendRequest> incoming,
    List<UserProfile> requested,
    List<UserProfile> friends,
  ) {
    final items = <_InboxItemDescriptor>[];

    // Feed section
    if (feedItems.isNotEmpty) {
      items
        ..add(const _InboxItemDescriptor.spacer())
        ..add(const _InboxItemDescriptor.sectionHeader(
          titleKey: 'feed',
        ));
      for (final item in feedItems) {
        items.add(
          _InboxItemDescriptor.feed(feedItem: item),
        );
      }
    }

    // Incoming requests section
    if (incoming.isNotEmpty) {
      items
        ..add(const _InboxItemDescriptor.spacer())
        ..add(const _InboxItemDescriptor.sectionHeader(
          titleKey: 'incoming',
        ));
      for (final request in incoming) {
        items.add(
          _InboxItemDescriptor.incomingRequest(
            incomingRequest: request,
          ),
        );
      }
    }

    // Sent requests section
    if (requested.isNotEmpty) {
      items
        ..add(const _InboxItemDescriptor.spacer())
        ..add(const _InboxItemDescriptor.sectionHeader(
          titleKey: 'requested',
        ));
      for (final friend in requested) {
        items.add(
          _InboxItemDescriptor.sentRequest(
            userProfile: friend,
          ),
        );
      }
    }

    // Friends section
    if (friends.isNotEmpty) {
      items
        ..add(const _InboxItemDescriptor.spacer())
        ..add(const _InboxItemDescriptor.sectionHeader(
          titleKey: 'friends',
        ));
      for (final friend in friends) {
        items.add(
          _InboxItemDescriptor.friend(
            userProfile: friend,
          ),
        );
      }
    }

    return items;
  }

  /// Lazily builds a single widget from a descriptor. Called by
  /// ListView.builder only for visible items.
  Widget _buildItem(
    BuildContext context,
    _InboxItemDescriptor desc,
  ) {
    final l10n = context.l10n;

    switch (desc.type) {
      case _InboxItemType.spacer:
        return const SizedBox(height: AppSpacing.md);

      case _InboxItemType.sectionHeader:
        final title = switch (desc.titleKey) {
          'feed' => l10n.inboxUpdates,
          'incoming' => l10n.inboxPendingRequests,
          'requested' => l10n.inboxSentRequests,
          'friends' => l10n.inboxMyFriends,
          _ => '',
        };
        return _SectionHeader(
          key: ValueKey('${desc.titleKey}_header'),
          title: title,
        );

      case _InboxItemType.feed:
        final item = desc.feedItem!;
        return _FeedCard(
          key: ValueKey('feed_${item.id}'),
          item: item,
          l10n: l10n,
          onTap: () {
            ref
                .read(feedNotifierProvider.notifier)
                .markAsRead(item.id);
            final sid = item.sessionId;
            if (sid != null) {
              context.pushNamed(
                'chat',
                pathParameters: {'sessionId': sid},
              );
            }
          },
        );

      case _InboxItemType.incomingRequest:
        final request = desc.incomingRequest!;
        return _FriendRequestCard(
          key: ValueKey(
            'incoming_${request.fromUserId}',
          ),
          request: request,
          disabled: _isItemBusy(request.fromUserId),
          onAccept: () => _runFriendAction(
            request.fromUserId,
            () => _socialService.addFriend(
              request.fromUserId,
            ),
            l10n.friendsRequestAccepted,
          ),
          onReject: () => _runFriendAction(
            request.fromUserId,
            () => _socialService.removeFriend(
              request.fromUserId,
            ),
            l10n.friendsRequestRejected,
          ),
        );

      case _InboxItemType.sentRequest:
        final friend = desc.userProfile!;
        return _UserRow(
          key: ValueKey('requested_${friend.id}'),
          title: friend.name ?? friend.id,
          subtitle: l10n.inboxRequestPending,
          userId: friend.id,
          avatarUrl: friend.avatarUrl,
          trailing: TextButton(
            onPressed: _isItemBusy(friend.id)
                ? null
                : () => _runFriendAction(
                    friend.id,
                    () => _socialService.removeFriend(
                      friend.id,
                    ),
                    l10n.inboxRequestCanceled,
                  ),
            child: Text(l10n.commonCancel),
          ),
        );

      case _InboxItemType.friend:
        final friend = desc.userProfile!;
        return _UserRow(
          key: ValueKey('friend_${friend.id}'),
          title: friend.name ?? friend.id,
          subtitle: friend.bio ?? '@${friend.username}',
          userId: friend.id,
          avatarUrl: friend.avatarUrl,
          showStatusDot: true,
          trailing: IconButton(
            onPressed: _isItemBusy(friend.id)
                ? null
                : () => _showRemoveFriendDialog(
                    friend,
                  ),
            icon: Icon(
              Icons.person_remove_outlined,
              color: Theme.of(context).colorScheme.error,
              size: AppSpacing.xl,
            ),
            tooltip: l10n.friendsRemoveAction,
          ),
        );
    }
  }

  Future<void> _showRemoveFriendDialog(UserProfile friend) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.friendsRemoveTitle),
        content: Text(l10n.friendsRemoveConfirm(friend.name ?? friend.id)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.friendsRemoveAction),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await _runFriendAction(
        friend.id,
        () => _socialService.removeFriend(friend.id),
        l10n.friendsRemoved,
      );
    }
  }

  Future<void> _showFindFriendsSheet() async {
    if (!mounted) {
      return;
    }
    unawaited(context.push('/friends/search'));
  }
}

// ── Lazy item descriptors ───────────────────────────────────────────────────

/// Lightweight type tag for each position in the unified inbox list.
enum _InboxItemType {
  spacer,
  sectionHeader,
  feed,
  incomingRequest,
  sentRequest,
  friend,
}

/// Describes what widget should be rendered at a given list position
/// without allocating any widget instances. Widgets are built on-demand
/// in [_InboxScreenState._buildItem].
class _InboxItemDescriptor {
  const _InboxItemDescriptor.spacer()
    : type = _InboxItemType.spacer,
      titleKey = null,
      feedItem = null,
      incomingRequest = null,
      userProfile = null;

  const _InboxItemDescriptor.sectionHeader({
    required this.titleKey,
  }) : type = _InboxItemType.sectionHeader,
       feedItem = null,
       incomingRequest = null,
       userProfile = null;

  const _InboxItemDescriptor.feed({required this.feedItem})
    : type = _InboxItemType.feed,
      titleKey = null,
      incomingRequest = null,
      userProfile = null;

  const _InboxItemDescriptor.incomingRequest({
    required this.incomingRequest,
  }) : type = _InboxItemType.incomingRequest,
       titleKey = null,
       feedItem = null,
       userProfile = null;

  const _InboxItemDescriptor.sentRequest({
    required UserProfile this.userProfile,
  }) : type = _InboxItemType.sentRequest,
       titleKey = null,
       feedItem = null,
       incomingRequest = null;

  const _InboxItemDescriptor.friend({
    required UserProfile this.userProfile,
  }) : type = _InboxItemType.friend,
       titleKey = null,
       feedItem = null,
       incomingRequest = null;

  final _InboxItemType type;
  final String? titleKey;
  final FeedItem? feedItem;
  final FriendRequest? incomingRequest;
  final UserProfile? userProfile;
}

// ── Header ─────────────────────────────────────────────────────────────────

class _InboxHeader extends StatelessWidget {
  const _InboxHeader({required this.onFindFriends});

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

class _InboxListView extends StatelessWidget {
  const _InboxListView({
    required this.descriptors,
    required this.onRefresh,
    required this.onFindFriends,
    required this.itemBuilder,
  });

  final List<_InboxItemDescriptor> descriptors;
  final Future<void> Function() onRefresh;
  final VoidCallback onFindFriends;
  final Widget Function(BuildContext, _InboxItemDescriptor) itemBuilder;

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
            return _InboxHeader(onFindFriends: onFindFriends);
          }
          return itemBuilder(context, descriptors[index - 1]);
        },
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _InboxEmptyView extends StatelessWidget {
  const _InboxEmptyView({required this.onFindFriends, required this.onRefresh});

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
          _InboxHeader(onFindFriends: onFindFriends),
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

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required Key key,
    required this.title,
  }) : super(key: key);

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
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: cs.onSurfaceVariant,
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

// ── Feed card ──────────────────────────────────────────────────────────────

/// Individual feed activity row with avatar, title, message and timestamp.
class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required Key key,
    required this.item,
    required this.l10n,
    this.onTap,
  }) : super(key: key);

  final FeedItem item;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUnread = !item.read;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.sm,
      ),
      child: AppTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.body.text != null) ...[
                    const SizedBox(height: AppSpacing.xsm),
                    Text(
                      item.body.text!,
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
        return body.text ?? l10n.inboxFeedUpdate;
      default:
        return l10n.inboxFeedUpdate;
    }
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

// ── Inbox item row (alias used by friend rows) ─────────────────────────────

/// A polished inbox list row: 44 px avatar on the left,
/// name + subtitle in the center, optional trailing
/// widget on the right.
class _InboxItem extends StatelessWidget {
  const _InboxItem({
    required this.title,
    required this.subtitle,
    required this.userId,
    required this.avatarUrl,
    required this.trailing,
    this.showStatusDot = false,
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
                _InboxAvatarWithStatus(
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
class _InboxAvatarWithStatus extends StatelessWidget {
  const _InboxAvatarWithStatus({
    required this.userId,
    required this.size,
    this.avatarUrl,
    this.isOnline = false,
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

// ── Friend request card ────────────────────────────────────────────────────

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard({
    required Key key,
    required this.request,
    required this.disabled,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  final FriendRequest request;
  final bool disabled;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return _InboxItem(
      title: request.fromUserName,
      subtitle: context.l10n.friendsWantsToConnect,
      userId: request.fromUserId,
      avatarUrl: request.fromUserAvatarUrl,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            onPressed: disabled ? null : onReject,
            icon: const Icon(
              Icons.close,
              size: AppSpacing.xl,
            ),
            tooltip: context.l10n.friendsReject,
            style: IconButton.styleFrom(
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: disabled ? null : onAccept,
            icon: const Icon(
              Icons.check,
              size: AppSpacing.xl,
            ),
            tooltip: context.l10n.friendsAccept,
          ),
        ],
      ),
    );
  }
}

// ── Generic user row (sent requests, friends list) ─────────────────────────

class _UserRow extends StatelessWidget {
  const _UserRow({
    required Key key,
    required this.title,
    required this.subtitle,
    required this.userId,
    required this.avatarUrl,
    required this.trailing,
    this.showStatusDot = false,
  }) : super(key: key);

  final String title;
  final String subtitle;
  final String userId;
  final String? avatarUrl;
  final Widget trailing;
  final bool showStatusDot;

  @override
  Widget build(BuildContext context) {
    return _InboxItem(
      title: title,
      subtitle: subtitle,
      userId: userId,
      avatarUrl: avatarUrl,
      trailing: trailing,
      showStatusDot: showStatusDot,
    );
  }
}

// ─── Loading shimmer ──────────────────────────────────────────────

class _InboxLoadingShimmer extends StatelessWidget {
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
