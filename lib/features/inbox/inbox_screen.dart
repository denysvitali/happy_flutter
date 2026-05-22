import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/friends_notifier.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/sync_subscription_mixin.dart';
import 'widgets/friend_request_card.dart';

/// Inbox screen — shows inbound friend requests with inline
/// accept / decline actions.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen>
    with SyncSubscriptionMixin {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(friendsNotifierProvider.notifier).refreshFromSync();
    });
    // Re-fetch whenever the server signals a friend-requests update.
    subscribeToDomains(
      {SyncDomain.friendRequests},
      () => ref.read(friendsNotifierProvider.notifier).refreshFromSync(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsNotifierProvider);

    if (state.isLoading && state.pendingRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.pendingRequests.isEmpty) {
      return const _EmptyInbox();
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(friendsNotifierProvider.notifier).refreshFromSync(),
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.xxxl,
        ),
        itemCount: state.pendingRequests.length,
        itemBuilder: (context, index) {
          final request = state.pendingRequests[index];
          final isPending = state.pendingActionIds.contains(request.id);
          return FriendRequestCard(
            key: ValueKey(request.id),
            request: request,
            isPending: isPending,
            onAccept: () => ref
                .read(friendsNotifierProvider.notifier)
                .acceptRequest(request.id),
            onDecline: () => ref
                .read(friendsNotifierProvider.notifier)
                .declineRequest(request.id),
          );
        },
      ),
    );
  }
}

// ─── _EmptyInbox ──────────────────────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No pending requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Friend requests will appear here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
