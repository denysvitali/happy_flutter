import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/models/session.dart';
import '../../../core/models/todo.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import '../session_avatar.dart';
import 'session_badges.dart';

/// Parses an avatar style string to the corresponding
/// [AvatarStyle] enum. Returns null if unknown.
AvatarStyle? parseAvatarStyle(String? style) {
  return switch (style) {
    'gradient' => AvatarStyle.gradient,
    'pixelated' => AvatarStyle.pixelated,
    'brutalist' => AvatarStyle.brutalist,
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

/// Active session card — clean, no glow animation.
class ActiveSessionCard extends StatelessWidget {
  const ActiveSessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.avatarStyle,
    this.lastMessageTimestamp,
  });

  final Session session;
  final VoidCallback? onTap;
  final bool showFlavorIcon;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;

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
    final todoProgress = getTodoProgress(session.todos);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: cs.primary.withValues(alpha: 0.04),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: Color(sessionStatus.statusDotColor),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.md),
                      bottomLeft: Radius.circular(AppRadius.md),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'session-avatar-${session.id}',
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SessionAvatar(
                                id: avatarId,
                                flavor: sessionFlavor,
                                size: 44,
                                showFlavorIcon: true,
                                minimal: true,
                              ),
                              if (hasDraft) const DraftBadge(),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      sessionName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  AppStatusDot(
                                    color: Color(sessionStatus.statusDotColor),
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
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                lastMessageTimestamp ?? session.updatedAt,
                                relative: true,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (todoProgress != null) ...[
                              const SizedBox(height: 3),
                              TodoProgressBadge(
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
      ),
    );
  }
}

/// Compact active session row (~56px height).
class CompactActiveSessionCard extends StatelessWidget {
  const CompactActiveSessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.avatarStyle,
    this.lastMessageTimestamp,
    this.selectionMode = false,
    this.isSelected = false,
  });

  final Session session;
  final VoidCallback? onTap;
  final bool showFlavorIcon;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final bool selectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sessionStatus = getSessionStatus(session);
    final avatarId = getSessionAvatarId(session);
    final sessionName = getSessionName(session);
    final sessionFlavor = session.metadata?.flavor;
    final hasDraft = session.draft != null && session.draft!.isNotEmpty;
    final todoProgress = getTodoProgress(session.todos);

    final cardColor = isSelected
        ? cs.primary.withValues(alpha: 0.10)
        : cs.primary.withValues(alpha: 0.04);
    final borderColor = isSelected
        ? cs.primary.withValues(alpha: 0.3)
        : cs.primary.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: cardColor,
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selectionMode)
                  SelectionCheckbox(
                    isSelected: isSelected,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  )
                else
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Color(sessionStatus.statusDotColor),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.md),
                        bottomLeft: Radius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'session-avatar-${session.id}',
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SessionAvatar(
                                id: avatarId,
                                flavor: sessionFlavor,
                                size: 36,
                                showFlavorIcon: showFlavorIcon,
                                style: avatarStyle,
                              ),
                              if (hasDraft) const DraftBadge(),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  sessionName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              AppStatusDot(
                                color: Color(sessionStatus.statusDotColor),
                                pulse: sessionStatus.isPulsing,
                                size: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                lastMessageTimestamp ?? session.updatedAt,
                                relative: true,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            if (todoProgress != null) ...[
                              const SizedBox(height: 2),
                              TodoProgressBadge(
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
      ),
    );
  }
}

/// Session card for archived/inactive sessions.
class SessionCard extends StatelessWidget {
  const SessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.onLongPress,
    this.isFirst = false,
    this.isLast = false,
    this.isSingle = false,
    this.showDateHeader = false,
    this.compact = false,
    this.selectionMode = false,
    this.isSelected = false,
    this.avatarStyle,
    this.lastMessageTimestamp,
    this.lastMessagePreview,
  });

  final Session session;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isFirst;
  final bool isLast;
  final bool isSingle;
  final bool showDateHeader;
  final bool compact;
  final bool selectionMode;
  final bool isSelected;
  final bool showFlavorIcon;
  final AvatarStyle? avatarStyle;
  final int? lastMessageTimestamp;
  final String? lastMessagePreview;

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
    final todoProgress = getTodoProgress(session.todos);

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
    final cardColor = isSelected
        ? cs.primary.withValues(alpha: 0.08)
        : cs.surface;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: isSelected
              ? BorderSide(color: cs.primary.withValues(alpha: 0.3))
              : BorderSide.none,
        ),
        elevation: 0,
        color: cardColor,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selectionMode)
                  SelectionCheckbox(
                    isSelected: isSelected,
                    borderRadius: borderRadius,
                  )
                else
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
                                showFlavorIcon: true,
                                minimal: true,
                              ),
                              if (hasDraft) const DraftBadge(),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: compact ? AppSpacing.sm : AppSpacing.md,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      sessionName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
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
                              if (lastMessagePreview != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  lastMessagePreview!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                lastMessageTimestamp ?? session.updatedAt,
                                relative: true,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (todoProgress != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              TodoProgressBadge(
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
      ),
    );
  }
}
