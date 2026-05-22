import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../models/friend.dart';
import 'friend_avatar_with_status.dart';

/// A list card that shows a friend's avatar (with an online-status dot),
/// display name, and a human-readable presence label.
///
/// Presence data is not yet available from the server; all friends
/// default to [FriendPresence.offline] until a live-presence
/// subscription is implemented.
class FriendCard extends StatefulWidget {
  const FriendCard({
    required this.friend,
    super.key,
    this.onTap,
  });

  /// The friend to display.
  final Friend friend;

  /// Optional tap callback.  When null the card is still rendered but
  /// has no interaction affordance.
  final VoidCallback? onTap;

  @override
  State<FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends State<FriendCard> {
  bool _pressed = false;

  String get _presenceLabel => switch (widget.friend.presence) {
    FriendPresence.online => 'Online',
    FriendPresence.away => 'Away',
    FriendPresence.offline => 'Offline',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: cs.surfaceContainerLow,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.65),
            width: AppBorder.hairline,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: widget.onTap != null
                ? () {
                    HapticFeedback.lightImpact();
                    widget.onTap!();
                  }
                : null,
            onTapDown: widget.onTap != null
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapUp: widget.onTap != null
                ? (_) => setState(() => _pressed = false)
                : null,
            onTapCancel: widget.onTap != null
                ? () => setState(() => _pressed = false)
                : null,
            splashColor: cs.primary.withValues(alpha: 0.08),
            highlightColor: cs.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  FriendAvatarWithStatus(
                    friend: widget.friend,
                    size: 44,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.friend.displayName.isNotEmpty
                              ? widget.friend.displayName
                              : widget.friend.id,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          _presenceLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: AppFontSize.xs,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: AppFontSize.lg,
                      color: cs.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
