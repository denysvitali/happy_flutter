import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/friend.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/social_service.dart';

/// Friends screen with two tabs: accepted friends and incoming requests.
class FriendsScreen extends ConsumerStatefulWidget {
  /// Creates the friends screen.
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final SocialService _socialService = SocialService();
  bool _isBusy = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future<void>.microtask(_refresh);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(friendsNotifierProvider.notifier).refreshFromSync();
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMsg,
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
      ).showSnackBar(SnackBar(content: Text(successMsg)));
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

  Future<void> _accept(FriendRequest request) async {
    await _runAction(
      () => _socialService.addFriend(request.fromUserId),
      context.l10n.friendsRequestAccepted,
    );
  }

  Future<void> _reject(FriendRequest request) async {
    await _runAction(
      () => _socialService.removeFriend(request.fromUserId),
      context.l10n.friendsRequestRejected,
    );
  }

  Future<void> _removeFriend(UserProfile friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.friendsRemoveTitle),
        content: Text(
          ctx.l10n.friendsRemoveConfirm(
            friend.name ?? friend.id,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.friendsRemoveAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _runAction(
      () => _socialService.removeFriend(friend.id),
      context.l10n.friendsRemoved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final friendsState = ref.watch(friendsNotifierProvider);
    final friends = friendsState.friendList;
    final incoming = friendsState.incomingRequests;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.friendsTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.friendsTabFriends),
                  if (friends.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: friends.length),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n.friendsTabRequests),
                  if (incoming.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _CountBadge(count: incoming.length),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FriendsTab(
            friends: friends,
            isBusy: _isBusy,
            onRemove: _removeFriend,
            onRefresh: _refresh,
          ),
          _RequestsTab(
            requests: incoming,
            isBusy: _isBusy,
            onAccept: _accept,
            onReject: _reject,
            onRefresh: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/friends/search'),
        tooltip: l10n.friendsAddFriend,
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Friends tab
// ---------------------------------------------------------------------------

class _FriendsTab extends StatelessWidget {
  const _FriendsTab({
    required this.friends,
    required this.isBusy,
    required this.onRemove,
    required this.onRefresh,
  });

  final List<UserProfile> friends;
  final bool isBusy;
  final void Function(UserProfile) onRemove;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.friendsEmptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.friendsEmptySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return _FriendTile(
            friend: friend,
            isBusy: isBusy,
            onRemove: () => onRemove(friend),
          );
        },
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.isBusy,
    required this.onRemove,
  });

  final UserProfile friend;
  final bool isBusy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = friend.name ?? friend.id;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: friend.avatarUrl != null
              ? ResizeImage(
                  NetworkImage(friend.avatarUrl!),
                  width: 108,
                  height: 108,
                )
              : null,
          child: friend.avatarUrl == null
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
              : null,
        ),
        title: Text(name),
        subtitle: friend.bio != null ? Text(friend.bio!) : null,
        trailing: TextButton(
          onPressed: isBusy ? null : onRemove,
          child: Text(context.l10n.friendsRemoveAction),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Requests tab
// ---------------------------------------------------------------------------

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.requests,
    required this.isBusy,
    required this.onAccept,
    required this.onReject,
    required this.onRefresh,
  });

  final List<FriendRequest> requests;
  final bool isBusy;
  final void Function(FriendRequest) onAccept;
  final void Function(FriendRequest) onReject;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.friendsNoRequests,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final req = requests[index];
          return _RequestTile(
            request: req,
            isBusy: isBusy,
            onAccept: () => onAccept(req),
            onReject: () => onReject(req),
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.isBusy,
    required this.onAccept,
    required this.onReject,
  });

  final FriendRequest request;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: request.fromUserAvatarUrl != null
                  ? ResizeImage(
                      NetworkImage(request.fromUserAvatarUrl!),
                      width: 108,
                      height: 108,
                    )
                  : null,
              child: request.fromUserAvatarUrl == null
                  ? Text(
                      request.fromUserName.isNotEmpty
                          ? request.fromUserName[0].toUpperCase()
                          : '?',
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.fromUserName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    l10n.friendsWantsToConnect,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: isBusy ? null : onReject,
              child: Text(l10n.friendsReject),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: isBusy ? null : onAccept,
              child: Text(l10n.friendsAccept),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
