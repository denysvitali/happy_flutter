import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/app_status_dot.dart';
import '../../../core/models/session.dart';
import '../../../core/models/todo.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_status.dart';
import '../../../core/utils/session_utils.dart';
import '../session_avatar.dart';

/// Active session card — clean, no glow animation.
class ActiveSessionCard extends StatelessWidget {
  const ActiveSessionCard({
    required this.session,
    required this.showFlavorIcon,
    super.key,
    this.onTap,
    this.avatarStyle,
  });

  /// The session to display.
  final Session session;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

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

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
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
                                showFlavorIcon: showFlavorIcon,
                                style: avatarStyle,
                              ),
                              if (hasDraft) const _DraftBadge(),
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
                                session.updatedAt,
                                relative: true,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (todoProgress != null) ...[
                              const SizedBox(height: 3),
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
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, size: 10, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xxs),
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
