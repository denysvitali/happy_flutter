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
  ConsumerState<SessionTasksBanner> createState() =>
      _SessionTasksBannerState();
}

class _SessionTasksBannerState extends ConsumerState<SessionTasksBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Scope the watch to this session — re-render only when our
    // session's bucket changes (other sessions' updates don't
    // invalidate this widget).
    final items = ref.watch(
      todoStateNotifierProvider
          .select((s) => s.bySession[widget.sessionId] ?? const []),
    );

    if (items.isEmpty) return const SizedBox.shrink();

    final completed =
        items.where((i) => i.status == TodoState.completed).length;
    final total = items.length;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surfaceContainerHigh.withValues(alpha: 0.97),
      shape: Border(
        top: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            completed: completed,
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
    required this.total,
    required this.expanded,
    required this.onTap,
    required this.onViewAll,
  });

  final int completed;
  final int total;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allDone = completed == total;
    final color =
        allDone ? AppColors.success : cs.primary;
    final pending = total - completed;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              allDone
                  ? Icons.check_circle_rounded
                  : Icons.checklist_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                allDone
                    ? 'All $total tasks done'
                    : 'Tasks · $completed/$total done · $pending pending',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
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
    final active = items
        .where((i) => i.status != TodoState.completed)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final done = items
        .where((i) => i.status == TodoState.completed)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: SingleChildScrollView(
        child: Padding(
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
                ...active.map(
                  (i) => _Row(item: i, onTap: () => onToggle(i.id)),
                ),
              ],
              if (done.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xs,
                    bottom: AppSpacing.xxs,
                  ),
                  child: Text(
                    'Completed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                ...done.map(
                  (i) => _Row(item: i, onTap: () => onToggle(i.id)),
                ),
              ],
            ],
          ),
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
    final Widget statusIcon;
    if (isCompleted) {
      statusColor = AppColors.success;
      statusIcon = Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: statusColor,
      );
    } else if (isInProgress) {
      statusColor = cs.primary;
      statusIcon = Icon(
        Icons.radio_button_checked_rounded,
        size: 18,
        color: statusColor,
      );
    } else {
      statusColor = cs.onSurfaceVariant.withValues(alpha: 0.5);
      statusIcon = Icon(
        Icons.radio_button_unchecked_rounded,
        size: 18,
        color: statusColor,
      );
    }

    final textColor =
        isCompleted ? cs.onSurfaceVariant : cs.onSurface;
    final decoration =
        isCompleted ? TextDecoration.lineThrough : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: statusIcon,
            ),
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
          ],
        ),
      ),
    );
  }
}
