import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/friend.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/social_service.dart';

/// Screen for displaying and managing a user's profile and friend status.
///
/// Looks up the user by [userId] in the friends list. Shows avatar
/// (with initials fallback), name, friend status, and appropriate
/// action buttons.
class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

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

  String _getInitials(UserProfile user) {
    final name = user.name;
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _avatarColor(String userId) {
    final colors = [
      const Color(0xFF5C6BC0),
      const Color(0xFF26A69A),
      const Color(0xFFEF5350),
      const Color(0xFFAB47BC),
      const Color(0xFF42A5F5),
      const Color(0xFF66BB6A),
      const Color(0xFFFF7043),
      const Color(0xFF26C6DA),
    ];
    final hash = userId.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
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
      title: user.status == RelationshipStatus.friends
          ? 'Remove Friend'
          : 'Cancel Request',
      message: user.status == RelationshipStatus.friends
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
              padding: const EdgeInsets.all(16),
              children: [
                // Profile header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        // Avatar
                        _buildAvatar(user, theme),
                        const SizedBox(height: 16),

                        // Name
                        if (user.name != null)
                          Text(
                            user.name!,
                            style:
                                theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                        // Email
                        if (user.email != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              user.email!,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme
                                    .colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Friend status badge
                        _buildStatusBadge(user, theme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons
                _buildActionButtons(user, theme),
              ],
            ),
    );
  }

  Widget _buildAvatar(UserProfile user, ThemeData theme) {
    final avatarUrl = user.avatarUrl;
    final initials = _getInitials(user);
    final bgColor = _avatarColor(user.id);

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 45,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: bgColor,
        child: null,
      );
    }

    return CircleAvatar(
      radius: 45,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(UserProfile user, ThemeData theme) {
    switch (user.status) {
      case RelationshipStatus.friends:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green),
              SizedBox(width: 4),
              Text(
                'Friends',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case RelationshipStatus.pendingOutgoing:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 16,
                color: Colors.orange,
              ),
              SizedBox(width: 4),
              Text(
                'Request Sent',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case RelationshipStatus.pendingIncoming:
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add_outlined,
                size: 16,
                color: Colors.blue,
              ),
              SizedBox(width: 4),
              Text(
                'Wants to Connect',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case RelationshipStatus.blocked:
      case RelationshipStatus.blockedByThem:
        return const SizedBox.shrink();
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
      case RelationshipStatus.friends:
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

      case RelationshipStatus.pendingOutgoing:
        return OutlinedButton.icon(
          onPressed: () => _removeFriend(user),
          icon: const Icon(Icons.close),
          label: const Text('Cancel Request'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        );

      case RelationshipStatus.pendingIncoming:
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
            const SizedBox(height: 8),
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

      case RelationshipStatus.blocked:
      case RelationshipStatus.blockedByThem:
        return const SizedBox.shrink();

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
