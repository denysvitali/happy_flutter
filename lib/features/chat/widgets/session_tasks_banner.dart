import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/task_detail_dialog.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/todo.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_color_scheme.dart';
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
    final live = ref.watch(
      todoStateNotifierProvider.select((s) => s.bySession[widget.sessionId]),
    );
    final persisted = ref.watch(
      sessionByIdProvider(widget.sessionId).select((s) => s?.todos),
    );
    final items = live ?? persisted ?? const <TodoItem>[];

    if (items.isEmpty) return const SizedBox.shrink();

    final completed = items
        .where((i) => i.status == TodoState.completed)
        .length;
    final running = items.where((i) => i.status == TodoState.inProgress).length;
    final total = items.length;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Aurora glass dock: a floating capsule above the composer instead of a
    // full-width slab, so the composer stays the hero and progress reads as
    // material. The expanded list keeps the capsule's rounded silhouette.
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: cs.surfaceContainerLow.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(
            color: appCs.glassBorder,
            width: AppBorder.hairline,
          ),
        ),
        elevation: AppElevation.low,
        shadowColor: Colors.black.withValues(alpha: 0.24),
        clipBehavior: Clip.antiAlias,
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
                context.pushNamed(
                  'tasks',
                  queryParameters: {'session': widget.sessionId},
                );
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
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final allDone = completed == total;
    final progressLabel = '$completed of $total complete';
    final detailLabel = running > 0
        ? '$progressLabel · $running running'
        : progressLabel;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            expanded: expanded,
            label: '${context.l10n.tasksTitle}, $detailLabel',
            onTap: onTap,
            child: ExcludeSemantics(
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppTouchTarget.comfortable,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xsm,
                      AppSpacing.xs,
                      AppSpacing.xsm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          // All-done gets a filled success tile; active gets
                          // the signature gradient — one glance tells you
                          // whether the session's plan is finished.
                          decoration: BoxDecoration(
                            gradient: allDone
                                ? null
                                : LinearGradient(
                                    colors: appCs.accentGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: allDone
                                ? AppColors.success.withValues(
                                    alpha: AppOpacity.subtle,
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(AppRadius.smd),
                          ),
                          child: Icon(
                            allDone
                                ? Icons.check_rounded
                                : Icons.checklist_rounded,
                            size: AppIconSize.lg,
                            color: allDone
                                ? AppColors.success
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.smd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.tasksTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                detailLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              _SegmentedProgress(
                                key: const ValueKey('session-tasks-progress'),
                                completed: completed,
                                total: total,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.7,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: AnimatedRotation(
                            duration: AppDuration.fast,
                            turns: expanded ? 0.5 : 0.0,
                            child: Icon(
                              Icons.expand_more_rounded,
                              size: AppIconSize.lg,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            foregroundColor: cs.primary,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            minimumSize: const Size(0, AppTouchTarget.min),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('View all'),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}

/// Segmented progress meter: one pill segment per task, completed segments
/// carry the accent gradient, the rest stay as faint outlines.
///
/// Exposes the same `value` contract the previous linear bar had (via
/// [value]) so existing tests keep their handle; segments cap at 12 with an
/// ellipsis fade for very long task lists.
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({
    required this.completed,
    required this.total,
    super.key,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appCs = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final visibleTotal = math.min(total, _maxSegments);

    return SizedBox(
      height: _segmentHeight + 2,
      child: Row(
        children: [
          for (var i = 0; i < visibleTotal; i++)
            Padding(
              padding: const EdgeInsets.only(right: _segmentGap),
              child: _Segment(
                filled: i < completed,
                gradient: appCs.accentLinearGradient,
                track: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
  }

  static const int _maxSegments = 12;
  static const double _segmentHeight = 4;
  static const double _segmentGap = 2;
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.filled,
    required this.gradient,
    required this.track,
  });

  final bool filled;
  final LinearGradient gradient;
  final Color track;

  @override
  Widget build(BuildContext context) {
    if (!filled) {
      return Container(
        width: _segWidth,
        height: _height,
        decoration: BoxDecoration(
          color: track.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const SizedBox(width: _segWidth, height: _height),
    );
  }

  static const double _segWidth = 14;
  static const double _height = 4;
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
              ...active.map(
                (i) => _Row(item: i, onToggle: () => onToggle(i.id)),
              ),
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
              ...done.map((i) => _Row(item: i, onToggle: () => onToggle(i.id))),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onToggle});

  final TodoItem item;
  final VoidCallback onToggle;

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
      onTap: () => showTaskDetailDialog(context: context, item: item),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor,
                      decoration: decoration,
                      decorationColor: textColor,
                      height: AppLineHeight.normal,
                    ),
                  ),
                  if (item.description case final description?
                      when description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxxs),
                      child: Text(
                        _abbreviated(description),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                          height: AppLineHeight.normal,
                          fontSize: AppFontSize.xs,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusPill(label: statusLabel, color: statusColor),
            const SizedBox(width: AppSpacing.xs),
            _ToggleButton(isCompleted: isCompleted, onTap: onToggle),
          ],
        ),
      ),
    );
  }

  String _abbreviated(String description) {
    const maxChars = 60;
    if (description.length <= maxChars) return description;
    return '${description.substring(0, maxChars).trimRight()}…';
  }
}

/// Tappable checkbox that toggles task completion without opening detail.
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.isCompleted, required this.onTap});

  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCompleted
        ? AppColors.success
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    final label = isCompleted
        ? context.l10n.tasksMarkIncomplete
        : context.l10n.tasksMarkComplete;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                isCompleted
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
