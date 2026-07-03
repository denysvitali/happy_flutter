import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/loop.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Card displaying a single [Loop].
///
/// Shows the schedule (cron → human-readable), prompt preview, status chip,
/// last-fired relative time, fire count, and pause/delete actions.
class LoopCard extends StatelessWidget {
  const LoopCard({
    required this.loop,
    required this.onPauseToggle,
    required this.onDelete,
    super.key,
  });

  final Loop loop;

  /// Called when the user toggles the pause state of this loop.
  final Future<void> Function(bool paused) onPauseToggle;

  /// Called when the user confirms deletion.
  final Future<void> Function() onDelete;

  bool get _isExpired => loop.isExpired();

  String _humanSchedule(String cron, AppLocalizations l10n) {
    final parts = cron.split(' ');
    if (parts.length != 5) return cron;
    final minute = parts[0];
    final hour = parts[1];
    if (minute.startsWith('*/') && hour == '*') {
      final n = minute.substring(2);
      return l10n.loopsScheduleEveryMinutes(n);
    }
    if (minute == '0' && hour.startsWith('*/')) {
      final n = hour.substring(2);
      return l10n.loopsScheduleEveryHours(n);
    }
    if (minute == '0' && hour == '9') {
      return l10n.loopsScheduleDaily9am;
    }
    return cron;
  }

  String _relativeTime(int? ms, AppLocalizations l10n) {
    if (ms == null) return l10n.loopsNeverFired;
    final diffMs = DateTime.now().millisecondsSinceEpoch - ms;
    if (diffMs < 0) return l10n.loopsJustNow;
    final seconds = diffMs ~/ 1000;
    if (seconds < 60) return l10n.loopsSecondsAgo(seconds);
    final minutes = seconds ~/ 60;
    if (minutes < 60) return l10n.loopsMinutesAgo(minutes);
    final hours = minutes ~/ 60;
    if (hours < 24) return l10n.loopsHoursAgo(hours);
    final days = hours ~/ 24;
    return l10n.loopsDaysAgo(days);
  }

  String _expiresLabel(AppLocalizations l10n) {
    final diffMs = loop.expiresAt - DateTime.now().millisecondsSinceEpoch;
    if (diffMs <= 0) return l10n.loopsExpired;
    final days = diffMs ~/ (24 * 60 * 60 * 1000);
    if (days < 1) {
      final hours = diffMs ~/ (60 * 60 * 1000);
      return l10n.loopsExpiresInHours(hours);
    }
    return l10n.loopsExpiresInDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: cs.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _humanSchedule(loop.expression, l10n),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(loop: loop, isExpired: _isExpired),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              loop.prompt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  l10n.loopsFireCount(loop.fireCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    l10n.loopsLastFired(_relativeTime(loop.lastFiredAt, l10n)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _expiresLabel(l10n),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _isExpired ? cs.error : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _isExpired
                      ? null
                      : () => onPauseToggle(!loop.paused),
                  icon: Icon(
                    loop.paused ? Icons.play_arrow : Icons.pause,
                    size: 18,
                  ),
                  label: Text(
                    loop.paused
                        ? l10n.loopsResumeButton
                        : l10n.loopsPauseButton,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.loopsDeleteButton),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.loopsDeleteConfirmTitle),
        content: Text(l10n.loopsDeleteConfirmMessage(loop.id)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.loopsDeleteButton),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await onDelete();
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.loop, required this.isExpired});

  final Loop loop;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final Color bg;
    final Color fg;
    final String label;
    final IconData icon;
    if (isExpired) {
      bg = AppColors.error.withValues(alpha: 0.1);
      fg = AppColors.error;
      label = l10n.loopsStatusExpired;
      icon = Icons.history;
    } else if (loop.paused) {
      bg = theme.colorScheme.secondaryContainer;
      fg = theme.colorScheme.onSecondaryContainer;
      label = l10n.loopsStatusPaused;
      icon = Icons.pause;
    } else {
      bg = AppColors.success.withValues(alpha: 0.1);
      fg = AppColors.success;
      label = l10n.loopsStatusActive;
      icon = Icons.check_circle;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
