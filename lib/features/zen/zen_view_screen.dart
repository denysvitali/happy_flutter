import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';

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
  ConsumerState<ZenViewScreen> createState() => _ZenViewScreenState();
}

class _ZenViewScreenState extends ConsumerState<ZenViewScreen> {
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(todoStateNotifierProvider.notifier)
          .refreshFromSync();
    });
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      ref.read(todoStateNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todoState = ref.watch(todoStateNotifierProvider);
    final list = todoState.lists[widget.sessionId];
    final item =
        list?.items.where((t) => t.id == widget.todoId).firstOrNull;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.zenTaskTitle)),
        body: Center(
          child: Text(context.l10n.zenTaskNotFound),
        ),
      );
    }

    return _ZenViewBody(item: item, sessionId: widget.sessionId);
  }
}

class _ZenViewBody extends ConsumerStatefulWidget {
  const _ZenViewBody({required this.item, required this.sessionId});

  final TodoItem item;
  final String sessionId;

  @override
  ConsumerState<_ZenViewBody> createState() => _ZenViewBodyState();
}

class _ZenViewBodyState extends ConsumerState<_ZenViewBody> {
  bool _isBusy = false;

  Future<void> _markDone() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      ref.read(todoStateNotifierProvider.notifier).updateTodo(
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
              backgroundColor: Theme.of(ctx).colorScheme.error,
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
      ref.read(todoStateNotifierProvider.notifier).removeTodo(
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xxxl,
        ),
        children: [
          // Content
          Text(
            item.content,
            style: theme.textTheme.titleLarge?.copyWith(
              decoration: isDone ? TextDecoration.lineThrough : null,
              decorationColor: cs.onSurface,
              color: isDone ? cs.onSurfaceVariant : cs.onSurface,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Meta card
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                _MetaRow(
                  label: l10n.zenPriorityLabel,
                  child: _PriorityChip(priority: item.priority),
                ),
                _MetaDivider(),
                _MetaRow(
                  label: l10n.zenStatusLabel,
                  child: Text(
                    item.status.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
                _MetaDivider(),
                _MetaRow(
                  label: l10n.zenCreatedLabel,
                  child: Text(
                    _formatDate(item.createdAt),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (item.completedAt != null) ...[
                  _MetaDivider(),
                  _MetaRow(
                    label: l10n.zenCompletedLabel,
                    child: Text(
                      _formatDate(item.completedAt!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          // Actions
          if (!isDone)
            FilledButton.icon(
              onPressed: _isBusy ? null : _markDone,
              icon: const Icon(Icons.check),
              label: Text(l10n.zenMarkDone),
            ),
          const SizedBox(height: AppSpacing.md),
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
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(int milliseconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
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
      thickness: 0.5,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(
        alpha: 0.5,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final String priority;

  static Color _color(String p, ColorScheme cs) {
    switch (p) {
      case 'critical':
        return cs.error;
      case 'high':
        return Colors.orange;
      case 'medium':
        return cs.tertiary;
      default:
        return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(priority, theme.colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        priority,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
