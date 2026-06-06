import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/todo.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// A sticky banner at the bottom of the chat session that shows the
/// current agent task list for the active session.
///
/// Hidden when there are no tasks; tap to expand / collapse. Tapping
/// "View all" jumps to the global Tasks home (Zen).
class SessionTasksBanner extends ConsumerStatefulWidget {
  const SessionTasksBanner({required this.sessionId, super.key});

  /// The chat session whose tasks should be shown. Other sessions'
  /// tasks are ignored.
  final String sessionId;

  @override
  ConsumerState<SessionTasksBanner> createState() => _SessionTasksBannerState();
}

class _SessionTasksBannerState extends ConsumerState<SessionTasksBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Scope the watch to this session — re-render only when our
    // session's bucket changes (other sessions' updates don't
    // invalidate this widget).
    final items = ref.watch(
      todoStateNotifierProvider.select(
        (s) => s.bySession[widget.sessionId] ?? const [],
      ),
    );

    if (items.isEmpty) return const SizedBox.shrink();

    final completed = items
        .where((i) => i.status == TodoState.completed)
        .length;
    final running = items.where((i) => i.status == TodoState.inProgress).length;
    final total = items.length;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surface.withValues(alpha: 0.98),
      shape: Border(
        top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            completed: completed,
            running: running,
            total: total,
            expanded: _expanded,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = !_expanded);
            },
            onViewAll: () {
              HapticFeedback.lightImpact();
              context.pushNamed('tasks');
            },
          ),
          AnimatedSize(
            duration: AppDuration.normal,
            curve: AppCurve.standard,
            child: _expanded
                ? _TaskList(items: items, onToggle: _toggleComplete)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _toggleComplete(String id) {
    HapticFeedback.lightImpact();
    ref.read(todoStateNotifierProvider.notifier).toggleComplete(id);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.completed,
    required this.running,
    required this.total,
    required this.expanded,
    required this.onTap,
    required this.onViewAll,
  });

  final int completed;
  final int running;
  final int total;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allDone = completed == total;
    final color = allDone ? AppColors.success : cs.primary;
    final pending = total - completed;
    final progress = total == 0 ? 0.0 : completed / total;
    final activeLabel = running > 0 ? '$running running' : '$pending active';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    allDone
                        ? Icons.check_circle_rounded
                        : Icons.checklist_rounded,
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$completed/$total done',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: cs.surfaceContainerHighest
                              .withValues(alpha: 0.9),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusPill(label: activeLabel, color: color),
                const SizedBox(width: AppSpacing.xs),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View all',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                AnimatedRotation(
                  duration: AppDuration.fast,
                  turns: expanded ? 0.5 : 0.0,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
          width: AppBorder.hairline,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.items, required this.onToggle});

  final List<TodoItem> items;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Active tasks (pending / in_progress) float to the top.
    final active = items.where((i) => i.status != TodoState.completed).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final done = items.where((i) => i.status == TodoState.completed).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (active.isNotEmpty) ...[
              ...active.map((i) => _Row(item: i, onTap: () => onToggle(i.id))),
            ],
            if (done.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.only(
                  top: active.isEmpty ? 0 : AppSpacing.xs,
                  bottom: AppSpacing.xxs,
                ),
                child: Text(
                  'Completed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              ...done.map((i) => _Row(item: i, onTap: () => onToggle(i.id))),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onTap});

  final TodoItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isCompleted = item.status == TodoState.completed;
    final isInProgress = item.status == TodoState.inProgress;

    final Color statusColor;
    final Color rowColor;
    final String statusLabel;
    final Widget statusIcon;
    if (isCompleted) {
      statusColor = AppColors.success;
      rowColor = cs.surfaceContainerHighest.withValues(alpha: 0.42);
      statusLabel = 'Done';
      statusIcon = Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: statusColor,
      );
    } else if (isInProgress) {
      statusColor = cs.primary;
      rowColor = cs.primaryContainer.withValues(alpha: 0.20);
      statusLabel = 'Running';
      statusIcon = Icon(
        Icons.radio_button_checked_rounded,
        size: 18,
        color: statusColor,
      );
    } else {
      statusColor = cs.onSurfaceVariant.withValues(alpha: 0.5);
      rowColor = cs.surfaceContainerHighest.withValues(alpha: 0.28);
      statusLabel = 'Pending';
      statusIcon = Icon(
        Icons.radio_button_unchecked_rounded,
        size: 18,
        color: statusColor,
      );
    }

    final textColor = isCompleted ? cs.onSurfaceVariant : cs.onSurface;
    final decoration = isCompleted ? TextDecoration.lineThrough : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: rowColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: statusColor.withValues(alpha: isInProgress ? 0.22 : 0.12),
            width: AppBorder.hairline,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            statusIcon,
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                item.content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor,
                  decoration: decoration,
                  decorationColor: textColor,
                  height: AppLineHeight.normal,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusPill(label: statusLabel, color: statusColor),
          ],
        ),
      ),
    );
  }
}
