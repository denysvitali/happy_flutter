import 'package:flutter/material.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/models/session.dart';
import '../../../core/models/todo.dart';
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
  });

  /// The session to display.
  final Session session;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the card is long-pressed.
  final VoidCallback? onLongPress;

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

  /// Whether multi-select mode is active.
  final bool selectionMode;

  /// Whether this card is currently selected.
  final bool isSelected;

  /// Whether to show the AI provider flavor icon on the avatar.
  final bool showFlavorIcon;

  /// The avatar style to use (null = hash-based selection).
  final AvatarStyle? avatarStyle;

  /// Timestamp of the last message in the session (ms since epoch).
  /// If null, falls back to session.updatedAt.
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

    final cardColor = isSelected
        ? cs.primary.withValues(alpha: 0.08)
        : cs.surface;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: isSelected
            ? BorderSide(
                color: cs.primary.withValues(alpha: 0.3),
              )
            : BorderSide.none,
      ),
      elevation: 0,
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Selection checkbox replaces the
                // status bar in selection mode.
                if (selectionMode)
                  _SelectionCheckbox(
                    isSelected: isSelected,
                    borderRadius: borderRadius,
                  )
                else
                  Container(
                    width: 3,
                    color: sessionStatus.isConnected
                        ? Color(
                            sessionStatus.statusDotColor,
                          )
                        : cs.outlineVariant,
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: compact ? AppSpacing.xsm : AppSpacing.sm,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag:
                              'session-avatar-${session.id}',
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SessionAvatar(
                                id: avatarId,
                                flavor: sessionFlavor,
                                size: compact ? 36 : 44,
                                monochrome:
                                    !sessionStatus
                                        .isConnected,
                                showFlavorIcon:
                                    showFlavorIcon,
                                style: avatarStyle,
                              ),
                              if (hasDraft)
                                const _DraftBadge(),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: compact
                              ? AppSpacing.sm
                              : AppSpacing.md,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      sessionName,
                                      style: theme
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                        fontWeight:
                                            FontWeight.w600,
                                        color: titleColor,
                                      ),
                                      overflow: TextOverflow
                                          .ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: AppSpacing.sm,
                                  ),
                                  AppStatusDot(
                                    color: sessionStatus
                                            .isConnected
                                        ? Color(
                                            sessionStatus
                                                .statusDotColor,
                                          )
                                        : cs.outlineVariant,
                                    pulse: sessionStatus
                                        .isPulsing,
                                    size: 8,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                sessionSubtitle,
                                style: theme
                                    .textTheme.labelMedium
                                    ?.copyWith(
                                  color:
                                      cs.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                ),
                                overflow:
                                    TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: AppSpacing.sm,
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatTimestamp(
                                lastMessageTimestamp ??
                                    session.updatedAt,
                                relative: true,
                              ),
                              style: theme
                                  .textTheme.labelSmall
                                  ?.copyWith(
                                color:
                                    cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (todoProgress != null) ...[
                              const SizedBox(
                                height: AppSpacing.xs,
                              ),
                              _TodoProgressBadge(
                                completed:
                                    todoProgress.completed,
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

/// Circular checkbox shown at the leading edge in selection
/// mode, replacing the status color bar.
class _SelectionCheckbox extends StatelessWidget {
  const _SelectionCheckbox({
    required this.isSelected,
    required this.borderRadius,
  });

  final bool isSelected;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected
            ? cs.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.only(
          topLeft: borderRadius.topLeft,
          bottomLeft: borderRadius.bottomLeft,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? cs.primary : cs.surface,
          border: Border.all(
            color: isSelected
                ? cs.primary
                : cs.outline.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 14,
                color: cs.onPrimary,
              )
            : null,
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
