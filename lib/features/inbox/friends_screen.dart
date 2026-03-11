import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/components/app_tappable.dart';
import '../../core/components/avatar.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/friend.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/social_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/shimmer/shimmer.dart';

/// Friends screen with two tabs: accepted friends
/// and incoming requests.
class FriendsScreen extends ConsumerStatefulWidget {
  /// Creates the friends screen.
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() =>
      _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final SocialService _socialService = SocialService();
  bool _isBusy = false;
  bool _isLoading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future<void>.microtask(() async {
      await _refresh();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref
        .read(friendsNotifierProvider.notifier)
        .refreshFromSync();
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMsg,
  ) async {
    setState(() => _isBusy = true);
    try {
      await action();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.friendsActionFailed),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
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
      () =>
          _socialService.removeFriend(request.fromUserId),
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
    if (confirmed != true || !mounted) return;
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
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(l10n.friendsTabFriends),
                  if (friends.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _CountBadge(count: friends.length),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(l10n.friendsTabRequests),
                  if (incoming.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _CountBadge(count: incoming.length),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const _FriendsLoadingShimmer()
          : TabBarView(
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

// ─────────────────────────────────────────────────────
// Friends tab
// ─────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxxl,
          ),
          children: [
            AppEmptyState(
              icon: Icons.people_outline,
              title: context.l10n.friendsEmptyTitle,
              subtitle:
                  context.l10n.friendsEmptySubtitle,
              action: FilledButton.icon(
                onPressed: () =>
                    context.push('/friends/search'),
                icon: const Icon(Icons.person_search),
                label: Text(
                  context.l10n.friendsAddFriend,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxxl,
        ),
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return _FriendTile(
            key: ValueKey(friend.id),
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
    super.key,
  });

  final UserProfile friend;
  final bool isBusy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = friend.name ?? friend.id;

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
              // Avatar with status indicator
              _AvatarWithStatus(
                userId: friend.id,
                avatarUrl: friend.avatarUrl,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              // Name + bio/username
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium
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
                      friend.bio ??
                          '@${friend.username}',
                      style: theme.textTheme.bodySmall
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
              IconButton(
                onPressed: isBusy ? null : onRemove,
                icon: Icon(
                  Icons.person_remove_outlined,
                  color: cs.error,
                  size: AppSpacing.xl,
                ),
                tooltip:
                    context.l10n.friendsRemoveAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Requests tab
// ─────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxxl,
          ),
          children: [
            AppEmptyState(
              icon: Icons.mark_email_read_outlined,
              title: context.l10n.friendsNoRequests,
              subtitle:
                  'Friend requests will appear here',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxxl,
        ),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final req = requests[index];
          return _RequestTile(
            key: ValueKey(req.id),
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
    super.key,
  });

  final FriendRequest request;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.sm,
      ),
      child: AppTappable(
        borderRadius:
            BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
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
              // Avatar
              Avatar(
                id: request.fromUserId,
                size: 48,
                imageUrl: request.fromUserAvatarUrl,
              ),
              const SizedBox(width: AppSpacing.md),
              // Name + status text
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.fromUserName,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(
                      height: AppSpacing.xsm,
                    ),
                    Row(
                      children: [
                        AppStatusDot(
                          color: AppColors.warning,
                          size: AppSpacing.xsm,
                        ),
                        const SizedBox(
                          width: AppSpacing.xs,
                        ),
                        Text(
                          l10n.friendsWantsToConnect,
                          style: theme
                              .textTheme.bodySmall
                              ?.copyWith(
                            color:
                                cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.outlined(
                    onPressed:
                        isBusy ? null : onReject,
                    icon: const Icon(
                      Icons.close,
                      size: AppSpacing.xl,
                    ),
                    tooltip: l10n.friendsReject,
                    style: IconButton.styleFrom(
                      side: BorderSide(
                        color: cs.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: AppSpacing.sm,
                  ),
                  IconButton.filled(
                    onPressed:
                        isBusy ? null : onAccept,
                    icon: const Icon(
                      Icons.check,
                      size: AppSpacing.xl,
                    ),
                    tooltip: l10n.friendsAccept,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Avatar with online/offline status dot
// ─────────────────────────────────────────────────────

class _AvatarWithStatus extends StatelessWidget {
  const _AvatarWithStatus({
    required this.userId,
    required this.size,
    this.avatarUrl,
  });

  final String userId;
  final String? avatarUrl;
  final double size;

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
                color: cs.onSurfaceVariant.withValues(
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

// ─────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xsm,
        vertical: AppSpacing.xsm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius:
            BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _FriendsLoadingShimmer extends StatelessWidget {
  const _FriendsLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.surfaceContainerHighest;

    return Shimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxxl,
        ),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.sm,
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
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(
                    width: AppSpacing.md,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 100 +
                              (index * 20.0) % 60,
                          decoration: BoxDecoration(
                            color: color,
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
                          width: 150 +
                              (index * 15.0) % 50,
                          decoration: BoxDecoration(
                            color: color,
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
        },
      ),
    );
  }
}
