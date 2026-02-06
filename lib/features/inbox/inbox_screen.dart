import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/feed.dart';
import '../../core/models/friend.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/social_service.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final SocialService _socialService = SocialService();
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
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
        .where((friend) => friend.status == RelationshipStatus.pendingOutgoing)
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _InboxHeader(onFindFriends: _showFindFriendsSheet),
          if (feedState.items.isNotEmpty) ...[
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            _Section(
              title: 'Pending Requests',
              child: Column(
                children: incoming
                    .map(
                      (request) => _FriendRequestCard(
                        request: request,
                        disabled: _isBusy,
                        onAccept: () => _runFriendAction(
                          () => _socialService.addFriend(request.fromUserId),
                          'Request accepted',
                        ),
                        onReject: () => _runFriendAction(
                          () => _socialService.removeFriend(request.fromUserId),
                          'Request rejected',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          if (requested.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section(
              title: 'Sent Requests',
              child: Column(
                children: requested
                    .map(
                      (friend) => _UserRow(
                        title: friend.name ?? friend.id,
                        subtitle: 'Request pending',
                        avatarUrl: friend.avatarUrl,
                        trailing: TextButton(
                          onPressed: _isBusy
                              ? null
                              : () => _runFriendAction(
                                  () => _socialService.removeFriend(friend.id),
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
            const SizedBox(height: 16),
            _Section(
              title: 'My Friends',
              child: Column(
                children: friends
                    .map(
                      (friend) => _UserRow(
                        title: friend.name ?? friend.id,
                        subtitle: _onlineText(friend.lastSeenAt),
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

  String _onlineText(int? lastSeenAtMs) {
    if (lastSeenAtMs == null || lastSeenAtMs <= 0) {
      return 'Status unknown';
    }

    final lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenAtMs);
    final delta = DateTime.now().difference(lastSeen);

    if (delta.inMinutes < 1) {
      return 'Active now';
    }
    if (delta.inHours < 1) {
      return '${delta.inMinutes}m ago';
    }
    if (delta.inDays < 1) {
      return '${delta.inHours}h ago';
    }
    return '${delta.inDays}d ago';
  }

  Future<void> _showRemoveFriendDialog(UserProfile friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove ${friend.name ?? friend.id} from your friends?'),
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

    if (confirmed == true) {
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
    context.push('/friends/search');
  }
}

class _InboxHeader extends StatelessWidget {
  const _InboxHeader({required this.onFindFriends});

  final VoidCallback onFindFriends;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Inbox',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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

class _InboxEmptyView extends StatelessWidget {
  const _InboxEmptyView({required this.onFindFriends, required this.onRefresh});

  final VoidCallback onFindFriends;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          _InboxHeader(onFindFriends: onFindFriends),
          const SizedBox(height: 36),
          Icon(
            Icons.inbox_outlined,
            size: 72,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            'Empty Inbox',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with friends to start sharing sessions.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 8), child: child),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        leading: CircleAvatar(
          child: Icon(
            item.type == FeedType.friendRequest
                ? Icons.person_add_alt_1
                : Icons.notifications,
          ),
        ),
        title: Text(item.body.title),
        subtitle: Text(item.body.message ?? 'No details'),
        trailing: Text(_timeAgo(item.createdAt)),
      ),
    );
  }

  static String _timeAgo(int createdAtMs) {
    final created = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) {
      return 'now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h';
    }
    return '${diff.inDays}d';
  }
}

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
    return _UserRow(
      title: request.fromUserName,
      subtitle: 'Wants to connect',
      avatarUrl: request.fromUserAvatarUrl,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: disabled ? null : onReject,
            child: const Text('Reject'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: disabled ? null : onAccept,
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String? avatarUrl;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl == null
                  ? Text(title.isNotEmpty ? title[0].toUpperCase() : '?')
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
