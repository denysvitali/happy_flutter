import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';

/// Zen home screen — displays all todo items grouped by status.
class ZenHomeScreen extends ConsumerWidget {
  /// Creates the Zen home screen.
  const ZenHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoStateNotifierProvider);
    final allTodos = todoState.allTodos;
    final totalCount = todoState.totalCount;
    final completedCount = todoState.completedCount;

    final activeTodos = allTodos
        .where(
          (t) =>
              t.status == TodoState.pending ||
              t.status == TodoState.inProgress,
        )
        .toList(growable: false);

    final completedTodos = allTodos
        .where((t) => t.status.isTerminal)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(context.l10n.zenTitle),
            if (totalCount > 0) ...[
              const SizedBox(width: 8),
              _TaskCountBadge(
                completed: completedCount,
                total: totalCount,
              ),
            ],
          ],
        ),
      ),
      body: allTodos.isEmpty
          ? _EmptyState(onAddTask: () => context.push('/zen/new'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                if (activeTodos.isNotEmpty) ...[
                  _SectionHeader(title: context.l10n.zenSectionActive),
                  const SizedBox(height: 4),
                  ...activeTodos.map(
                    (item) => _TodoItemCard(
                      item: item,
                      onTap: () => context.push(
                        '/zen/view',
                        extra: {
                          'todoId': item.id,
                          'sessionId': item.sessionId ?? 'global',
                        },
                      ),
                    ),
                  ),
                ],
                if (completedTodos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(title: context.l10n.zenSectionCompleted),
                  const SizedBox(height: 4),
                  ...completedTodos.map(
                    (item) => _TodoItemCard(
                      item: item,
                      onTap: () => context.push(
                        '/zen/view',
                        extra: {
                          'todoId': item.id,
                          'sessionId': item.sessionId ?? 'global',
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/zen/new'),
        tooltip: context.l10n.zenNewTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskCountBadge extends StatelessWidget {
  const _TaskCountBadge({
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$completed/$total',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _TodoItemCard extends StatelessWidget {
  const _TodoItemCard({required this.item, required this.onTap});

  final TodoItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = item.status.isTerminal;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: _StatusIcon(status: item.status),
        title: Text(
          item.content,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        trailing: _PriorityBadge(priority: item.priority),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final TodoState status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case TodoState.completed:
        return Icon(
          Icons.check_circle,
          color: theme.colorScheme.primary,
        );
      case TodoState.canceled:
        return Icon(
          Icons.cancel_outlined,
          color: theme.colorScheme.error,
        );
      case TodoState.inProgress:
        return Icon(
          Icons.timelapse,
          color: theme.colorScheme.tertiary,
        );
      case TodoState.pending:
        return Icon(
          Icons.radio_button_unchecked,
          color: theme.colorScheme.onSurfaceVariant,
        );
    }
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddTask});

  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.zenEmptyTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.zenEmptySubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.zenNewTask),
            ),
          ],
        ),
      ),
    );
  }
}
