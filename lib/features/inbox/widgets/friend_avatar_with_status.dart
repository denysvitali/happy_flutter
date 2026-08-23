import 'package:flutter/material.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/components/avatar.dart';
import '../../../core/theme/app_colors.dart';
import '../models/friend.dart';

/// Overlays an [AppStatusDot] at the bottom-right corner of
/// a friend's [Avatar], conveying their current presence.
///
/// Color mapping:
/// - [FriendPresence.online]  → [AppColors.success] (green)
/// - [FriendPresence.away]    → [AppColors.warning] (orange)
/// - [FriendPresence.offline] → muted grey
///
/// Presence is an at-rest state, so every dot is static; the pulse
/// loop is reserved for transitional connection states.
///
/// The dot is framed with a small white/surface ring so it remains
/// legible on any avatar background.
class FriendAvatarWithStatus extends StatelessWidget {
  const FriendAvatarWithStatus({
    required this.friend,
    super.key,
    this.size = 44,
  });

  /// The friend whose avatar and presence are displayed.
  final Friend friend;

  /// Diameter of the avatar in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dotSize = size * 0.28; // ~12 px for a 44 px avatar
    final ringWidth = 2.0;

    final (dotColor, pulse) = switch (friend.presence) {
      // Online never pulses — see the class docs for the policy.
      FriendPresence.online => (AppColors.success, false),
      FriendPresence.away => (AppColors.warning, false),
      FriendPresence.offline => (cs.onSurfaceVariant.withValues(alpha: 0.35),
          false),
    };

    final semanticLabel = switch (friend.presence) {
      FriendPresence.online => 'Online',
      FriendPresence.away => 'Away',
      FriendPresence.offline => 'Offline',
    };

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Avatar(
            id: friend.id,
            size: size,
            imageUrl: friend.avatarUrl,
          ),
          Positioned(
            right: -ringWidth,
            bottom: -ringWidth,
            child: Container(
              width: dotSize + ringWidth * 2,
              height: dotSize + ringWidth * 2,
              // Surface ring keeps the dot legible on any avatar color.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface,
              ),
              alignment: Alignment.center,
              child: AppStatusDot(
                color: dotColor,
                size: dotSize,
                pulse: pulse,
                semanticLabel: semanticLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
