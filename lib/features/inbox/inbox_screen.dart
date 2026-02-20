import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/components/app_tappable.dart';
import '../../core/components/avatar.dart';
import '../../core/models/feed.dart';
import '../../core/models/friend.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/social_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final SocialService _socialService = SocialService();
  bool _isBusy = false;
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
  }

  Future<void> _runFriendAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _isBusy = true);
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
      ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
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
        .where(
          (friend) => friend.status == RelationshipStatus.requested,
        )
        .toList(growable: false);

    final isEmpty =
        feedState.items.isEmpty &&
        incoming.isEmpty &&
        requested.isEmpty &&
        friends.isEmpty;

    if (isEmpty) {
      return _InboxEmptyView(
        onFindFriends: _showFindFriendsSheet,
        onRefresh: _refresh,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          _InboxHeader(onFindFriends: _showFindFriendsSheet),
          if (feedState.items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _Section(
              title: 'Updates',
              child: Column(
                children: feedState.items
                    .map((item) => _FeedCard(item: item))
                    .toList(growable: false),
              ),
            ),
          ],
          if (incoming.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _Section(
              title: 'Pending Requests',
              child: Column(
                children: incoming
                    .map(
                      (request) => _FriendRequestCard(
                        request: request,
                        disabled: _isBusy,
                        onAccept: () => _runFriendAction(
                          () => _socialService.addFriend(
                            request.fromUserId,
                          ),
                          'Request accepted',
                        ),
                        onReject: () => _runFriendAction(
                          () => _socialService.removeFriend(
                            request.fromUserId,
                          ),
                          'Request rejected',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          if (requested.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _Section(
              title: 'Sent Requests',
              child: Column(
                children: requested
                    .map(
                      (friend) => _UserRow(
                        title: friend.name ?? friend.id,
                        subtitle: 'Request pending',
                        userId: friend.id,
                        avatarUrl: friend.avatarUrl,
                        trailing: TextButton(
                          onPressed: _isBusy
                              ? null
                              : () => _runFriendAction(
                                    () => _socialService.removeFriend(
                                      friend.id,
                                    ),
                                    'Request canceled',
                                  ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          if (friends.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _Section(
              title: 'My Friends',
              child: Column(
                children: friends
                    .map(
                      (friend) => _UserRow(
                        title: friend.name ?? friend.id,
                        subtitle: 'Friend',
                        userId: friend.id,
                        avatarUrl: friend.avatarUrl,
                        trailing: TextButton(
                          onPressed: _isBusy
                              ? null
                              : () => _showRemoveFriendDialog(friend),
                          child: const Text('Remove'),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRemoveFriendDialog(UserProfile friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
          'Remove ${friend.name ?? friend.id} from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await _runFriendAction(
        () => _socialService.removeFriend(friend.id),
        'Friend removed',
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
          label: const Text('Find Friends'),
        ),
      ],
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _InboxEmptyView extends StatelessWidget {
  const _InboxEmptyView({
    required this.onFindFriends,
    required this.onRefresh,
  });

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
            title: 'No notifications yet',
            subtitle: 'Connect with friends to start sharing sessions.',
            action: FilledButton.icon(
              onPressed: onFindFriends,
              icon: const Icon(Icons.person_search),
              label: const Text('Find Friends'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section container ──────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Feed card ──────────────────────────────────────────────────────────────

/// Individual feed activity row with avatar, title, message and timestamp.
class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUnread = !item.read;

    return AppTappable(
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
                      fontWeight: isUnread
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.body.text != null) ...[
                    const SizedBox(height: AppSpacing.xs / 2),
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
                    fontWeight: isUnread
                        ? FontWeight.w600
                        : FontWeight.w400,
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

  static String _bodyTitle(FeedBody body) {
    switch (body.kind) {
      case 'friend_request':
        return 'Friend request';
      case 'friend_accepted':
        return 'Friend accepted';
      case 'text':
        return body.text ?? 'Update';
      default:
        return 'Update';
    }
  }

  static String _timeAgo(int createdAtMs) {
    final created = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    final now = DateTime.now();
    final diff = now.difference(created);
    if (diff.inMinutes < 1) {
      return 'now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    // Yesterday check
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final createdDate = DateTime(created.year, created.month, created.day);
    if (createdDate == yesterday) {
      return 'Yesterday';
    }
    // Older — show short date
    return '${created.month}/${created.day}';
  }
}

// ── Inbox item row (alias used by friend rows) ─────────────────────────────

/// A polished inbox list row: 40 px avatar on the left, name + subtitle
/// in the center, optional trailing widget on the right.
class _InboxItem extends StatelessWidget {
  const _InboxItem({
    required this.title,
    required this.subtitle,
    required this.userId,
    required this.avatarUrl,
    required this.trailing,
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

    return AppTappable(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            // 40 px avatar
            Avatar(
              id: userId,
              size: 40,
              imageUrl: avatarUrl,
            ),
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
                  const SizedBox(height: AppSpacing.xs / 2),
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
    );
  }
}

// ── Friend request card ────────────────────────────────────────────────────

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard({
    required this.request,
    required this.disabled,
    required this.onAccept,
    required this.onReject,
  });

  final FriendRequest request;
  final bool disabled;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return _InboxItem(
      title: request.fromUserName,
      subtitle: 'Wants to connect',
      userId: request.fromUserId,
      avatarUrl: request.fromUserAvatarUrl,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: disabled ? null : onReject,
            child: const Text('Reject'),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: disabled ? null : onAccept,
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

// ── Generic user row (sent requests, friends list) ─────────────────────────

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.title,
    required this.subtitle,
    required this.userId,
    required this.avatarUrl,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String userId;
  final String? avatarUrl;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return _InboxItem(
      title: title,
      subtitle: subtitle,
      userId: userId,
      avatarUrl: avatarUrl,
      trailing: trailing,
    );
  }
}
