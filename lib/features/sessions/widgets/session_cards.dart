import 'package:flutter/material.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/models/session.dart';
import '../../../core/models/todo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import '../session_avatar.dart';
import 'session_badges.dart';

export 'active_session_card.dart';
export 'archived_session_card.dart';
export 'compact_active_session_card.dart';

/// Parses an avatar style string to the corresponding
/// [AvatarStyle] enum. Returns null if unknown.
AvatarStyle? parseAvatarStyle(String? style) {
  return switch (style) {
    'gradient' => AvatarStyle.gradient,
    'pixelated' => AvatarStyle.pixelated,
    'brutalist' => AvatarStyle.brutalist,
    'geometric' => AvatarStyle.geometric,
    'rings' => AvatarStyle.rings,
    'constellation' => AvatarStyle.constellation,
    'wave' => AvatarStyle.wave,
    'neon' => AvatarStyle.neon,
    'bloom' => AvatarStyle.bloom,
    'prism' => AvatarStyle.prism,
    _ => null,
  };
}

/// Computes todo progress, returning (completed, total) or
/// null if todos are empty or all completed.
({int completed, int total})? getTodoProgress(List<TodoItem>? todos) {
  if (todos == null || todos.isEmpty) return null;
  final total = todos.length;
  final completed = todos.where((t) => t.status == TodoState.completed).length;
  if (completed >= total) return null;
  return (completed: completed, total: total);
}

// ────────────────────────────────────────────────────────────
// Shared helpers
// ────────────────────────────────────────────────────────────

/// Derived display values computed from a [Session].
class SessionDerived {
  SessionDerived({
    required this.status,
    required this.avatarId,
    required this.name,
    required this.subtitle,
  });

  factory SessionDerived.from(Session session) {
    return SessionDerived(
      status: getSessionStatus(session),
      avatarId: getSessionAvatarId(session),
      name: getSessionName(session),
      subtitle: getSessionSubtitle(session),
    );
  }

  final SessionStatus status;
  final String avatarId;
  final String name;
  final String subtitle;
}

/// Builds the status text widget shown beneath the session
/// name when the session is connected and has a meaningful
/// status (thinking, permission required, etc.).
Widget? buildStatusText(SessionStatus status, TextTheme textTheme) {
  if (!status.shouldShowStatus || !status.isConnected) {
    return null;
  }
  return Text(
    status.statusText,
    style: textTheme.labelSmall?.copyWith(
      color: Color(status.statusColor),
      fontWeight: FontWeight.w500,
      fontSize: AppFontSize.xs,
    ),
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
  );
}

/// Builds a Telegram-style message preview with a "You: " prefix
/// for user messages in a subtle accent color.
Widget buildPreviewText({
  required BuildContext context,
  required String preview,
  required String? role,
  required TextStyle? style,
  required int maxLines,
}) {
  final cs = Theme.of(context).colorScheme;
  final isUser = role == 'user';
  final baseStyle = style?.copyWith(
    color: cs.onSurfaceVariant.withValues(alpha: AppOpacity.high),
  );

  if (!isUser) {
    return Text(
      preview,
      style: baseStyle,
      overflow: TextOverflow.ellipsis,
      maxLines: maxLines,
    );
  }

  return RichText(
    overflow: TextOverflow.ellipsis,
    maxLines: maxLines,
    text: TextSpan(
      children: [
        TextSpan(
          text: 'You: ',
          style: baseStyle?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        TextSpan(text: preview, style: baseStyle),
      ],
    ),
  );
}

/// Name row: session name with trailing status dot.
Widget buildNameRow({
  required String name,
  required SessionStatus sessionStatus,
  required TextStyle? style,
  Color? dotColor,
  double dotSize = 7,
}) {
  return Row(
    children: [
      Flexible(
        child: Text(
          name,
          style: style,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      const SizedBox(width: AppSpacing.xsm),
      AppStatusDot(
        color: dotColor ?? Color(sessionStatus.statusDotColor),
        pulse: sessionStatus.isPulsing,
        size: dotSize,
      ),
    ],
  );
}

/// Right column: timestamp + optional unread + todo badges.
Widget buildTimestampBadges({
  required int timestamp,
  required ThemeData theme,
  required ColorScheme cs,
  int unreadCount = 0,
  ({int completed, int total})? todoProgress,
  String? archiveCountdownLabel,
  double badgeGap = AppSpacing.xxs,
}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        formatTimestamp(timestamp, relative: true),
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: AppFontSize.xs,
        ),
      ),
      if (unreadCount > 0) ...[
        SizedBox(height: badgeGap),
        UnreadBadge(count: unreadCount),
      ],
      if (todoProgress != null) ...[
        SizedBox(height: badgeGap),
        TodoProgressBadge(
          completed: todoProgress.completed,
          total: todoProgress.total,
        ),
      ],
      if (archiveCountdownLabel != null) ...[
        SizedBox(height: badgeGap),
        _ArchiveCountdownBadge(label: archiveCountdownLabel),
      ],
    ],
  );
}

class _ArchiveCountdownBadge extends StatelessWidget {
  const _ArchiveCountdownBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: AppOpacity.soft),
          width: AppBorder.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_bottom_outlined,
            size: 10,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.xxs,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared avatar with Hero, optional draft badge.
Widget buildSessionAvatar({
  required String sessionId,
  required String avatarId,
  required String? sessionFlavor,
  required double size,
  required bool showFlavorIcon,
  required bool hasDraft,
  AvatarStyle? avatarStyle,
  bool monochrome = false,
}) {
  return Hero(
    tag: 'session-avatar-$sessionId',
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        SessionAvatar(
          id: avatarId,
          flavor: sessionFlavor,
          size: size,
          showFlavorIcon: showFlavorIcon,
          monochrome: monochrome,
          square: true,
          style: avatarStyle,
        ),
        if (hasDraft) const DraftBadge(),
      ],
    ),
  );
}
