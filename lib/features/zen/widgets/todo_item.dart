import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/todo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// A single zen todo row wrapped in a [Dismissible] for swipe-to-complete.
///
/// Swiping left-to-right fires [HapticFeedback.lightImpact], calls
/// [onToggleComplete], then spring-backs (returns false from
/// [confirmDismiss] so the row stays in the list).
class ZenTodoItem extends StatelessWidget {
  const ZenTodoItem({
    required this.item,
    required this.onToggleComplete,
    super.key,
  });

  final TodoItem item;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = item.status == TodoState.completed;

    return Dismissible(
      key: ValueKey('dismissible_${item.id}'),
      direction: DismissDirection.startToEnd,
      // Return false so the row spring-backs and stays in the list.
      confirmDismiss: (_) async {
        HapticFeedback.lightImpact();
        onToggleComplete();
        return false;
      },
      background: _SwipeBackground(isCompleted: isCompleted),
      child: _TodoRow(item: item, isCompleted: isCompleted, theme: theme),
    );
  }
}

/// Green background shown during the swipe gesture.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    // When already completed, swiping cycles back to pending — show undo icon.
    final icon =
        isCompleted ? Icons.refresh_rounded : Icons.check_circle_rounded;
    final label = isCompleted ? 'Undo' : 'Done';

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: isCompleted
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isCompleted
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isCompleted
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The visible todo row content.
class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.item,
    required this.isCompleted,
    required this.theme,
  });

  final TodoItem item;
  final bool isCompleted;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(theme);
    final statusIcon = _statusIcon(statusColor);
    final textColor = isCompleted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: statusIcon,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: textColor,
                    height: AppLineHeight.normal,
                  ),
                ),
                if (item.priority != null &&
                    item.priority!.isNotEmpty &&
                    item.priority != 'low')
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: _PriorityChip(priority: item.priority!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ThemeData theme) {
    if (isCompleted) return AppColors.success;
    if (item.status == TodoState.inProgress) return theme.colorScheme.primary;
    return theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
  }

  Widget _statusIcon(Color color) {
    if (isCompleted) {
      return Icon(Icons.check_circle_rounded, size: 20, color: color);
    }
    if (item.status == TodoState.inProgress) {
      return Icon(Icons.pending_rounded, size: 20, color: color);
    }
    return Icon(Icons.radio_button_unchecked_rounded, size: 20, color: color);
  }
}

/// A small pill chip showing task priority.
class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (priority) {
      'critical' => ('Critical', AppColors.error),
      'high' => ('High', AppColors.warning),
      'medium' => ('Medium', theme.colorScheme.primary),
      _ => ('Low', theme.colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: AppFontSize.xxs,
        ),
      ),
    );
  }
}
