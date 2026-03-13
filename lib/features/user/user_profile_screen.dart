import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/avatar.dart';
import '../../core/i18n/app_localizations.dart';
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
            content: Text(context.l10n.friendsFailedToAdd),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _removeFriend(UserProfile user) async {
    final l10n = context.l10n;
    final name = user.name ?? l10n.userFallbackName;
    final isFriend = user.status == RelationshipStatus.friend;
    final confirmed = await _showConfirmDialog(
      title: isFriend ? l10n.friendsRemoveTitle : l10n.friendsCancelRequest,
      message: isFriend
          ? l10n.friendsRemoveConfirm(name)
          : l10n.friendsCancelRequestConfirm(name),
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
            content: Text(context.l10n.friendsFailedToUpdate),
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
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.commonConfirm),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(
      friendsNotifierProvider.select((state) {
        for (final friend in state.friends) {
          if (friend.id == widget.userId) {
            return friend;
          }
        }
        return null;
      }),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(user?.name ?? context.l10n.userProfileTitle),
      ),
      body: user == null
          ? Center(
              child: Text(
                context.l10n.userNotFound,
                style: theme.textTheme.bodyLarge?.copyWith(
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
                  color: theme.colorScheme.surfaceContainer,
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
    final l10n = context.l10n;
    switch (user.status) {
      case RelationshipStatus.friend:
        return _StatusBadge(
          icon: Icons.check_circle,
          label: l10n.friendsStatusFriends,
          color: theme.colorScheme.primary,
        );
      case RelationshipStatus.requested:
        return _StatusBadge(
          icon: Icons.hourglass_empty,
          label: l10n.friendsStatusRequestSent,
          color: theme.colorScheme.tertiary,
        );
      case RelationshipStatus.pending:
        return _StatusBadge(
          icon: Icons.person_add_outlined,
          label: l10n.friendsStatusWantsToConnect,
          color: theme.colorScheme.tertiary,
        );
      case RelationshipStatus.rejected:
      case RelationshipStatus.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButtons(UserProfile user, ThemeData theme) {
    final l10n = context.l10n;
    if (_isActionInProgress) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    switch (user.status) {
      case RelationshipStatus.friend:
        return OutlinedButton.icon(
          onPressed: () => _removeFriend(user),
          icon: Icon(
            Icons.person_remove_outlined,
            color: theme.colorScheme.error,
          ),
          label: Text(
            l10n.friendsRemoveAction,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: theme.colorScheme.error),
            minimumSize: const Size.fromHeight(
              AppTouchTarget.comfortable,
            ),
          ),
        );

      case RelationshipStatus.requested:
        return OutlinedButton.icon(
          onPressed: () => _removeFriend(user),
          icon: const Icon(Icons.close),
          label: Text(l10n.friendsCancelRequest),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(
              AppTouchTarget.comfortable,
            ),
          ),
        );

      case RelationshipStatus.pending:
        return Column(
          children: [
            FilledButton.icon(
              onPressed: () => _addFriend(user),
              icon: const Icon(Icons.check),
              label: Text(l10n.friendsAcceptRequest),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(
                  AppTouchTarget.comfortable,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _removeFriend(user),
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.error,
              ),
              label: Text(
                l10n.friendsDenyRequest,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: theme.colorScheme.error,
                ),
                minimumSize: const Size.fromHeight(
                  AppTouchTarget.comfortable,
                ),
              ),
            ),
          ],
        );

      case RelationshipStatus.rejected:
      case RelationshipStatus.none:
        return FilledButton.icon(
          onPressed: () => _addFriend(user),
          icon: const Icon(Icons.person_add_outlined),
          label: Text(l10n.friendsAddFriendAction),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(
              AppTouchTarget.comfortable,
            ),
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
        vertical: AppSpacing.xxs2,
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
              fontSize: AppFontSize.md,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
