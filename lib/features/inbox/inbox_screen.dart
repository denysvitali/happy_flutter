import 'dart:async';

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
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final SocialService _socialService = SocialService();
  final Set<String> _busyIds = {};
  bool _isLoading = true;
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      ref.read(friendsNotifierProvider.notifier).loadFromSync();
      ref.read(feedNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(friendsNotifierProvider.notifier).refreshFromSync();
    await ref.read(feedNotifierProvider.notifier).refreshFromSync();
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
    final friendsState = ref.watch(friendsNotifierProvider);
    final feedState = ref.watch(feedNotifierProvider);
    final friends = friendsState.friendList;
    final incoming = friendsState.incomingRequests;
    final requested = friendsState.friends
        .where((friend) => friend.status == RelationshipStatus.requested)
        .toList(growable: false);

    final isEmpty =
        feedState.items.isEmpty &&
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

    // Build a unified list of all items for lazy loading with ListView.builder
    final items = _buildUnifiedList(
      feedState.items,
      incoming,
      requested,
      friends,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        itemCount: items.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _InboxHeader(onFindFriends: _showFindFriendsSheet);
          }
          return items[index - 1];
        },
      ),
    );
  }

  /// Builds a unified list of widgets representing all inbox sections
  /// and items.
  ///
  /// This enables lazy loading via ListView.builder instead of building all
  /// items at once with Column+map, which was O(N) and slow for large
  /// inboxes.
  List<Widget> _buildUnifiedList(
    List<FeedItem> feedItems,
    List<FriendRequest> incoming,
    List<UserProfile> requested,
    List<UserProfile> friends,
  ) {
    final items = <Widget>[];

    // Feed section
    if (feedItems.isNotEmpty) {
      items
        ..add(const SizedBox(height: AppSpacing.md))
        ..add(
          _SectionHeader(
            key: const ValueKey('feed_header'),
            title: context.l10n.inboxUpdates,
          ),
        )
        ..addAll(
          feedItems.map(
            (item) => _FeedCard(
              key: ValueKey('feed_${item.id}'),
              item: item,
              l10n: context.l10n,
              onTap: () {
                ref.read(feedNotifierProvider.notifier).markAsRead(item.id);
                final sid = item.sessionId;
                if (sid != null) {
                  context.pushNamed('chat', pathParameters: {'sessionId': sid});
                }
              },
            ),
          ),
        );
    }

    // Incoming requests section
    if (incoming.isNotEmpty) {
      items
        ..add(const SizedBox(height: AppSpacing.md))
        ..add(
          _SectionHeader(
            key: const ValueKey('incoming_header'),
            title: context.l10n.inboxPendingRequests,
          ),
        )
        ..addAll(
          incoming.map(
            (request) => _FriendRequestCard(
              key: ValueKey('incoming_${request.fromUserId}'),
              request: request,
              disabled: _isItemBusy(request.fromUserId),
              onAccept: () => _runFriendAction(
                request.fromUserId,
                () => _socialService.addFriend(request.fromUserId),
                context.l10n.friendsRequestAccepted,
              ),
              onReject: () => _runFriendAction(
                request.fromUserId,
                () => _socialService.removeFriend(request.fromUserId),
                context.l10n.friendsRequestRejected,
              ),
            ),
          ),
        );
    }

    // Sent requests section
    if (requested.isNotEmpty) {
      items
        ..add(const SizedBox(height: AppSpacing.md))
        ..add(
          _SectionHeader(
            key: const ValueKey('requested_header'),
            title: context.l10n.inboxSentRequests,
          ),
        )
        ..addAll(
          requested.map(
            (friend) => _UserRow(
              key: ValueKey('requested_${friend.id}'),
              title: friend.name ?? friend.id,
              subtitle: context.l10n.inboxRequestPending,
              userId: friend.id,
              avatarUrl: friend.avatarUrl,
              trailing: TextButton(
                onPressed: _isItemBusy(friend.id)
                    ? null
                    : () => _runFriendAction(
                        friend.id,
                        () => _socialService.removeFriend(friend.id),
                        context.l10n.inboxRequestCanceled,
                      ),
                child: Text(context.l10n.commonCancel),
              ),
            ),
          ),
        );
    }

    // Friends section
    if (friends.isNotEmpty) {
      items
        ..add(const SizedBox(height: AppSpacing.md))
        ..add(
          _SectionHeader(
            key: const ValueKey('friends_header'),
            title: context.l10n.inboxMyFriends,
          ),
        )
        ..addAll(
          friends.map(
            (friend) => _UserRow(
              key: ValueKey('friend_${friend.id}'),
              title: friend.name ?? friend.id,
              subtitle:
                  friend.bio ?? '@${friend.username}',
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
                  color: Theme.of(context)
                      .colorScheme
                      .error,
                  size: AppSpacing.xl,
                ),
                tooltip: context
                    .l10n.friendsRemoveAction,
              ),
            ),
          ),
        );
    }

    return items;
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
            'Inbox',
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
          AppSpacing.xxl,
          AppSpacing.xxl,
          AppSpacing.xxl,
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

    return AppTappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon avatar
            Container(
              width: 40,
              height: 40,
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
                    fontSize: 12,
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
    this.isOnline = false,
  });

  final String title;
  final String subtitle;
  final String userId;
  final String? avatarUrl;
  final Widget trailing;
  final bool showStatusDot;
  final bool isOnline;

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
              // Avatar with optional status dot
              if (showStatusDot)
                _InboxAvatarWithStatus(
                  userId: userId,
                  avatarUrl: avatarUrl,
                  size: 44,
                  isOnline: isOnline,
                )
              else
                Avatar(
                  id: userId,
                  size: 44,
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
            left: AppSpacing.lg,
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
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
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
        );

    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
        ),
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
