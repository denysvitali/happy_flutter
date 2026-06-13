import 'package:flutter/material.dart';

import '../models/todo.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Shows a modal dialog with the full task title, status, and description.
///
/// Returns after the dialog is dismissed.
Future<void> showTaskDetailDialog({
  required BuildContext context,
  required TodoItem item,
}) {
  return showDialog(
    context: context,
    builder: (context) => _TaskDetailDialog(item: item),
  );
}

class _TaskDetailDialog extends StatelessWidget {
  const _TaskDetailDialog({required this.item});

  final TodoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (statusLabel, statusColor) = _statusStyle(cs);

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          0,
        ),
        child: Row(
          children: [
            Icon(_statusIcon, color: statusColor, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                item.content,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: AppMotion.hoverOpacity),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                statusLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (item.description case final description?
                when description.isNotEmpty)
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: AppLineHeight.relaxed,
                    ),
                  ),
                ),
              )
            else
              Text(
                'No description provided.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: theme.textTheme.labelLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  (String, Color) _statusStyle(ColorScheme cs) {
    return switch (item.status) {
      TodoState.completed => ('Completed', AppColors.success),
      TodoState.inProgress => ('In Progress', cs.primary),
      TodoState.canceled => ('Canceled', cs.onSurfaceVariant),
      TodoState.pending => ('Pending', cs.onSurfaceVariant),
    };
  }

  IconData get _statusIcon {
    return switch (item.status) {
      TodoState.completed => Icons.check_circle_rounded,
      TodoState.inProgress => Icons.pending_rounded,
      TodoState.canceled => Icons.cancel_rounded,
      TodoState.pending => Icons.radio_button_unchecked_rounded,
    };
  }
}
