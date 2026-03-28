import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/sync_subscription_mixin.dart';
import 'zen_priority.dart';

/// Screen that shows the details of a single Zen todo item.
class ZenViewScreen extends ConsumerStatefulWidget {
  /// Creates the Zen view screen.
  ///
  /// [todoId] identifies the task. [sessionId] identifies the list it
  /// belongs to.
  const ZenViewScreen({
    required this.todoId,
    required this.sessionId,
    super.key,
  });

  /// The id of the task to display.
  final String todoId;

  /// The session (list) the task belongs to.
  final String sessionId;

  @override
  ConsumerState<ZenViewScreen> createState() =>
      _ZenViewScreenState();
}

class _ZenViewScreenState
    extends ConsumerState<ZenViewScreen>
    with SyncSubscriptionMixin {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(todoStateNotifierProvider.notifier)
          .refreshFromSync();
    });
    subscribeToDataChanged(ref, () {
      ref
          .read(todoStateNotifierProvider.notifier)
          .loadFromSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final todoState = ref.watch(todoStateNotifierProvider);
    final list = todoState.lists[widget.sessionId];
    final item = list?.items
        .where((t) => t.id == widget.todoId)
        .firstOrNull;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.zenTaskTitle),
        ),
        body: AppEmptyState(
          icon: Icons.search_off,
          title: context.l10n.zenTaskNotFound,
        ),
      );
    }

    return _ZenViewBody(
      item: item,
      sessionId: widget.sessionId,
    );
  }
}

class _ZenViewBody extends ConsumerStatefulWidget {
  const _ZenViewBody({
    required this.item,
    required this.sessionId,
  });

  final TodoItem item;
  final String sessionId;

  @override
  ConsumerState<_ZenViewBody> createState() =>
      _ZenViewBodyState();
}

class _ZenViewBodyState
    extends ConsumerState<_ZenViewBody> {
  bool _isBusy = false;

  Future<void> _markDone() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      ref
          .read(todoStateNotifierProvider.notifier)
          .updateTodo(
            widget.sessionId,
            widget.item.id,
            (t) => t.copyWith(
              status: TodoState.completed,
              completedAt: now,
              updatedAt: now,
            ),
          );
      if (!mounted) {
        return;
      }
      context.pop();
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _delete() async {
    if (_isBusy) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.zenDeleteTitle),
        content: Text(ctx.l10n.zenDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      ref
          .read(todoStateNotifierProvider.notifier)
          .removeTodo(
            widget.sessionId,
            widget.item.id,
          );
      if (!mounted) {
        return;
      }
      context.pop();
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final item = widget.item;
    final isDone = item.status.isTerminal;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.zenTaskTitle)),
      body: ListView(
        padding: AppScreenPadding.standard.copyWith(
          bottom: AppSpacing.xxxl,
        ),
        children: [
          Text(
            item.content,
            style: theme.textTheme.titleLarge?.copyWith(
              decoration: isDone
                  ? TextDecoration.lineThrough
                  : null,
              decorationColor: cs.onSurface,
              color: isDone
                  ? cs.onSurfaceVariant
                  : cs.onSurface,
              height: AppLineHeight.normal,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppSectionHeader(
            title: l10n.zenTaskTitle,
            padding: const EdgeInsets.only(
              bottom: AppSpacing.sm,
            ),
          ),
          _MetaCard(
            priority: item.priority,
            statusLabel: item.status.displayName,
            createdAt: item.createdAt,
            completedAt: item.completedAt,
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (!isDone) ...[
            FilledButton.icon(
              onPressed: _isBusy ? null : _markDone,
              icon: const Icon(Icons.check),
              label: Text(l10n.zenMarkDone),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(
                  AppTouchTarget.comfortable,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          OutlinedButton.icon(
            onPressed: _isBusy ? null : _delete,
            icon: Icon(
              Icons.delete_outline,
              color: cs.error,
            ),
            label: Text(
              l10n.commonDelete,
              style: TextStyle(color: cs.error),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error),
              minimumSize: const Size.fromHeight(
                AppTouchTarget.comfortable,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(int milliseconds) {
    final dt =
        DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${dt.year}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MetaDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: AppBorder.hairline,
      color: Theme.of(context)
          .colorScheme
          .outlineVariant
          .withValues(alpha: AppOpacity.half),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: AppFontSize.sm,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = ZenPriority.colorFor(priority, cs);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: AppOpacity.subtle,
        ),
        borderRadius:
            BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        priority,
        style:
            Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
          fontSize: AppFontSize.xs,
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.priority,
    required this.statusLabel,
    required this.createdAt,
    required this.completedAt,
  });

  final String priority;
  final String statusLabel;
  final int createdAt;
  final int? completedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _MetaRow(
            label: l10n.zenPriorityLabel,
            child: _PriorityChip(priority: priority),
          ),
          _MetaDivider(),
          _MetaRow(
            label: l10n.zenStatusLabel,
            child: Text(
              statusLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
              ),
            ),
          ),
          _MetaDivider(),
          _MetaRow(
            label: l10n.zenCreatedLabel,
            child: Text(
              _ZenViewBodyState._formatDate(createdAt),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
              ),
            ),
          ),
          if (completedAt != null) ...[
            _MetaDivider(),
            _MetaRow(
              label: l10n.zenCompletedLabel,
              child: Text(
                _ZenViewBodyState._formatDate(
                  completedAt!,
                ),
                style:
                    theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
