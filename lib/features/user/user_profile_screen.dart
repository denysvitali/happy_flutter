import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/avatar.dart';
import '../../core/models/friend.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/social_service.dart';
import '../../core/theme/app_tokens.dart';

/// Screen for displaying and managing a user's profile and friend status.
///
/// Looks up the user by [userId] in the friends list. Shows avatar
/// (with initials fallback), name, friend status, and appropriate
/// action buttons.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({required this.userId, super.key});

  final String userId;

  @override
  ConsumerState<UserProfileScreen> createState() =>
      _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _socialService = SocialService();
  bool _isActionInProgress = false;

  UserProfile? _findUser() {
    final friends =
        ref.read(friendsNotifierProvider).friends;
    try {
      return friends.firstWhere((f) => f.id == widget.userId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _addFriend(UserProfile user) async {
    setState(() => _isActionInProgress = true);
    try {
      await _socialService.addFriend(user.id);
      await ref
          .read(friendsNotifierProvider.notifier)
          .refreshFromSync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add friend: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _removeFriend(UserProfile user) async {
    final confirmed = await _showConfirmDialog(
      title: user.status == RelationshipStatus.friend
          ? 'Remove Friend'
          : 'Cancel Request',
      message: user.status == RelationshipStatus.friend
          ? 'Are you sure you want to remove '
              '${user.name ?? 'this user'} as a friend?'
          : 'Cancel friend request to '
              '${user.name ?? 'this user'}?',
    );
    if (!confirmed) return;

    setState(() => _isActionInProgress = true);
    try {
      await _socialService.removeFriend(user.id);
      await ref
          .read(friendsNotifierProvider.notifier)
          .refreshFromSync();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update friendship: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Watch for live updates
    ref.watch(friendsNotifierProvider);
    final user = _findUser();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.name ?? 'User Profile'),
      ),
      body: user == null
          ? Center(
              child: Text(
                'User not found',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Profile header card
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xxxl,
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        // Avatar — 80px for profile context
                        Avatar(
                          id: user.id,
                          size: 80,
                          imageUrl: user.avatarUrl,
                          thumbhash: user.avatar?.thumbhash,
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Name
                        if (user.name != null)
                          Text(
                            user.name!,
                            style:
                                theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                        // Username
                        if (user.username.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.xs,
                            ),
                            child: Text(
                              '@${user.username}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),

                        // Bio
                        if (user.bio != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.sm,
                            ),
                            child: Text(
                              user.bio!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: AppSpacing.md),

                        // Friend status badge
                        _buildStatusBadge(user, theme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Action buttons
                _buildActionButtons(user, theme),
              ],
            ),
    );
  }

  Widget _buildStatusBadge(UserProfile user, ThemeData theme) {
    switch (user.status) {
      case RelationshipStatus.friend:
        return _StatusBadge(
          icon: Icons.check_circle,
          label: 'Friends',
          color: Colors.green,
        );
      case RelationshipStatus.requested:
        return _StatusBadge(
          icon: Icons.hourglass_empty,
          label: 'Request Sent',
          color: Colors.orange,
        );
      case RelationshipStatus.pending:
        return _StatusBadge(
          icon: Icons.person_add_outlined,
          label: 'Wants to Connect',
          color: Colors.blue,
        );
      case RelationshipStatus.rejected:
      case RelationshipStatus.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButtons(UserProfile user, ThemeData theme) {
    if (_isActionInProgress) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    switch (user.status) {
      case RelationshipStatus.friend:
        return OutlinedButton.icon(
          onPressed: () => _removeFriend(user),
          icon: const Icon(
            Icons.person_remove_outlined,
            color: Colors.red,
          ),
          label: const Text(
            'Remove Friend',
            style: TextStyle(color: Colors.red),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            minimumSize: const Size.fromHeight(48),
          ),
        );

      case RelationshipStatus.requested:
        return OutlinedButton.icon(
          onPressed: () => _removeFriend(user),
          icon: const Icon(Icons.close),
          label: const Text('Cancel Request'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        );

      case RelationshipStatus.pending:
        return Column(
          children: [
            FilledButton.icon(
              onPressed: () => _addFriend(user),
              icon: const Icon(Icons.check),
              label: const Text('Accept Request'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _removeFriend(user),
              icon: const Icon(
                Icons.close,
                color: Colors.red,
              ),
              label: const Text(
                'Deny Request',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        );

      case RelationshipStatus.rejected:
      case RelationshipStatus.none:
        return FilledButton.icon(
          onPressed: () => _addFriend(user),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Add Friend'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        );
    }
  }
}

/// A small colored pill badge with an icon and label.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
