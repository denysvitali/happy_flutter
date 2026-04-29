import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/feed.dart';
import '../../core/models/friend.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/social_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/sync_subscription_mixin.dart';
import 'widgets/feed_card.dart';
import 'widgets/friend_request_card.dart';
import 'widgets/inbox_item.dart';
import 'widgets/inbox_shared.dart';

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
    subscribeToDomains({SyncDomain.friends, SyncDomain.feed}, () {
      ref.read(friendsNotifierProvider.notifier).loadFromSync();
      ref.read(feedNotifierProvider.notifier).loadFromSync();
    });
  }

  Future<void> _refresh() async {
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
    } catch (error, st) {
      logger.warning(
        '[InboxScreen] _runFriendAction failed: itemId=$itemId $error',
        error,
        st,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.friendsActionFailed)));
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(itemId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsData = ref.watch(
      friendsNotifierProvider.select(
        (state) => _InboxFriendsData(
          friendList: state.friendList,
          incomingRequests: state.incomingRequests,
          requested: state.friends
              .where((f) => f.status == RelationshipStatus.requested)
              .toList(growable: false),
        ),
      ),
    );
    final feedData = ref.watch(
      feedNotifierProvider.select(
        (state) =>
            _InboxFeedData(items: state.items, unreadCount: state.unreadCount),
      ),
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
      return const InboxLoadingShimmer();
    }

    if (isEmpty) {
      return InboxEmptyView(
        onFindFriends: _showFindFriendsSheet,
        onRefresh: _refresh,
      );
    }

    final descriptors = _buildDescriptors(
      feedData.items,
      incoming,
      requested,
      friends,
    );

    return InboxListView(
      descriptors: descriptors,
      onRefresh: _refresh,
      onFindFriends: _showFindFriendsSheet,
      itemBuilder: _buildItem,
    );
  }

  List<InboxItemDescriptor> _buildDescriptors(
    List<FeedItem> feedItems,
    List<FriendRequest> incoming,
    List<UserProfile> requested,
    List<UserProfile> friends,
  ) {
    final items = <InboxItemDescriptor>[];

    if (feedItems.isNotEmpty) {
      items
        ..add(const InboxItemDescriptor.spacer())
        ..add(const InboxItemDescriptor.sectionHeader(titleKey: 'feed'));
      for (final item in feedItems) {
        items.add(InboxItemDescriptor.feed(feedItem: item));
      }
    }

    if (incoming.isNotEmpty) {
      items
        ..add(const InboxItemDescriptor.spacer())
        ..add(const InboxItemDescriptor.sectionHeader(titleKey: 'incoming'));
      for (final request in incoming) {
        items.add(
          InboxItemDescriptor.incomingRequest(incomingRequest: request),
        );
      }
    }

    if (requested.isNotEmpty) {
      items
        ..add(const InboxItemDescriptor.spacer())
        ..add(const InboxItemDescriptor.sectionHeader(titleKey: 'requested'));
      for (final friend in requested) {
        items.add(InboxItemDescriptor.sentRequest(userProfile: friend));
      }
    }

    if (friends.isNotEmpty) {
      items
        ..add(const InboxItemDescriptor.spacer())
        ..add(const InboxItemDescriptor.sectionHeader(titleKey: 'friends'));
      for (final friend in friends) {
        items.add(InboxItemDescriptor.friend(userProfile: friend));
      }
    }

    return items;
  }

  Widget _buildItem(BuildContext context, InboxItemDescriptor desc) {
    final l10n = context.l10n;

    switch (desc.type) {
      case InboxItemType.spacer:
        return const SizedBox(height: AppSpacing.md);

      case InboxItemType.sectionHeader:
        final title = switch (desc.titleKey) {
          'feed' => l10n.inboxUpdates,
          'incoming' => l10n.inboxPendingRequests,
          'requested' => l10n.inboxSentRequests,
          'friends' => l10n.inboxMyFriends,
          _ => '',
        };
        return SectionHeader(
          key: ValueKey('${desc.titleKey}_header'),
          title: title,
        );

      case InboxItemType.feed:
        final item = desc.feedItem!;
        return FeedCard(
          key: ValueKey('feed_${item.id}'),
          item: item,
          l10n: l10n,
          onTap: () {
            ref.read(feedNotifierProvider.notifier).markAsRead(item.id);
            final sid = item.sessionId;
            if (sid != null) {
              context.pushNamed('chat', pathParameters: {'sessionId': sid});
            }
          },
        );

      case InboxItemType.incomingRequest:
        final request = desc.incomingRequest!;
        return FriendRequestCard(
          key: ValueKey('incoming_${request.fromUserId}'),
          request: request,
          disabled: _isItemBusy(request.fromUserId),
          onAccept: () => _runFriendAction(
            request.fromUserId,
            () => _socialService.addFriend(request.fromUserId),
            l10n.friendsRequestAccepted,
          ),
          onReject: () => _runFriendAction(
            request.fromUserId,
            () => _socialService.removeFriend(request.fromUserId),
            l10n.friendsRequestRejected,
          ),
        );

      case InboxItemType.sentRequest:
        final friend = desc.userProfile!;
        return UserRow(
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
                    () => _socialService.removeFriend(friend.id),
                    l10n.inboxRequestCanceled,
                  ),
            child: Text(l10n.commonCancel),
          ),
        );

      case InboxItemType.friend:
        final friend = desc.userProfile!;
        return UserRow(
          key: ValueKey('friend_${friend.id}'),
          title: friend.name ?? friend.id,
          subtitle: friend.bio ?? '@${friend.username}',
          userId: friend.id,
          avatarUrl: friend.avatarUrl,
          trailing: IconButton(
            onPressed: _isItemBusy(friend.id)
                ? null
                : () => _showRemoveFriendDialog(friend),
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
