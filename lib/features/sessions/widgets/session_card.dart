import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import '../session_avatar.dart';

/// Session card widget with enhanced status display and avatars.
///
/// Matches React Native's CompactSessionRow implementation.
class SessionCard extends StatelessWidget {
  const SessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
    this.isSingle = false,
    this.showDateHeader = false,
    this.compact = false,
    this.avatarStyle,
  });

  /// The session to display.
  final Session session;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Whether this is the first card in a group.
  final bool isFirst;

  /// Whether this is the last card in a group.
  final bool isLast;

  /// Whether this is the only card in a group.
  final bool isSingle;

  /// Whether to show a date header above the card.
  final bool showDateHeader;

  /// Whether to use compact layout (smaller avatar, reduced padding).
  final bool compact;

  /// Whether to show the AI provider flavor icon on the avatar.
  final bool showFlavorIcon;

  /// The avatar style to use (null = hash-based selection).
  final AvatarStyle? avatarStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus = getSessionStatus(session);
    final avatarId = getSessionAvatarId(session);
    final sessionName = getSessionName(session);
    final sessionSubtitle = getSessionSubtitle(session);
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = _getTodoProgress(session.todos);

    // Determine card border-radius based on position within group.
    BorderRadius borderRadius;
    if (isSingle) {
      borderRadius = BorderRadius.circular(AppRadius.md);
    } else if (isFirst) {
      borderRadius = const BorderRadius.vertical(
        top: Radius.circular(AppRadius.md),
      );
    } else if (isLast) {
      borderRadius = const BorderRadius.vertical(
        bottom: Radius.circular(AppRadius.md),
      );
    } else {
      borderRadius = BorderRadius.zero;
    }

    final titleColor = sessionStatus.isConnected
        ? cs.onSurface
        : cs.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide.none,
      ),
      elevation: 0,
      color: cs.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: sessionStatus.isConnected
                    ? Color(sessionStatus.statusDotColor)
                    : cs.outlineVariant,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: compact ? 6 : AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with Hero animation, monochrome when
                      // disconnected, and optional draft badge.
                      Hero(
                        tag: 'session-avatar-${session.id}',
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SessionAvatar(
                              id: avatarId,
                              flavor: sessionFlavor,
                              size: compact ? 36 : 44,
                              monochrome: !sessionStatus.isConnected,
                              showFlavorIcon: showFlavorIcon,
                              style: avatarStyle,
                            ),
                            if (hasDraft) const _DraftBadge(),
                          ],
                        ),
                      ),
                      SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sessionName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: titleColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                AppStatusDot(
                                  color: sessionStatus.isConnected
                                      ? Color(sessionStatus.statusDotColor)
                                      : cs.outlineVariant,
                                  pulse: sessionStatus.isPulsing,
                                  size: 8,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sessionSubtitle,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Right side: timestamp, status dot, optional todo.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatTimestamp(session.updatedAt, relative: true),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (todoProgress != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            _TodoProgressBadge(
                              completed: todoProgress.completed,
                              total: todoProgress.total,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draft icon overlay badge shown on avatar bottom-right corner.
class _DraftBadge extends StatelessWidget {
  const _DraftBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      bottom: 0,
      right: 0,
      child: Container(
        width: AppSpacing.lg,
        height: AppSpacing.lg,
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.drive_file_rename_outline,
          size: 10,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Task progress badge shown near the timestamp/status area.
class _TodoProgressBadge extends StatelessWidget {
  const _TodoProgressBadge({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, size: 10, color: cs.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Computes todo progress, returning (completed, total) or null if
/// todos are empty or all completed.
({int completed, int total})? _getTodoProgress(List<TodoItem>? todos) {
  if (todos == null || todos.isEmpty) return null;
  final total = todos.length;
  final completed = todos.where((t) => t.status == TodoState.completed).length;
  if (completed >= total) return null;
  return (completed: completed, total: total);
}
