import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/friend.dart';
import '../../../core/theme/app_tokens.dart';
import 'inbox_item.dart';

/// Card for incoming friend requests with accept/reject actions.
class FriendRequestCard extends StatelessWidget {
  const FriendRequestCard({
    required this.request,
    required this.disabled,
    required this.onAccept,
    required this.onReject,
    super.key,
  });

  final FriendRequest request;
  final bool disabled;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return InboxItem(
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
