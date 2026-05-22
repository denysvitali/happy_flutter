import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/todo.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/todo_item.dart';
import 'zen_todo_state.dart';

/// Zen home screen — displays the current todo list.
///
/// Each row supports a left-to-right swipe gesture to toggle completion.
/// The gesture triggers [HapticFeedback.lightImpact] and a spring-back
/// animation (the row stays in the list — it is never dismissed).
class ZenHomeScreen extends ConsumerStatefulWidget {
  const ZenHomeScreen({super.key});

  @override
  ConsumerState<ZenHomeScreen> createState() => _ZenHomeScreenState();
}

class _ZenHomeScreenState extends ConsumerState<ZenHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Seed with demo items so the screen is not empty out-of-the-box.
    // In production these are replaced by server-fetched todos via setItems().
    Future<void>.microtask(() {
      final notifier = ref.read(todoStateNotifierProvider.notifier);
      if (ref.read(todoStateNotifierProvider).items.isEmpty) {
        notifier.setItems(_demoItems());
      }
    });
  }

  List<TodoItem> _demoItems() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      TodoItem(
        id: 'demo-1',
        content: 'Review pull requests',
        status: TodoState.pending,
        priority: 'high',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      TodoItem(
        id: 'demo-2',
        content: 'Write unit tests for messaging layer',
        status: TodoState.inProgress,
        priority: 'critical',
        order: 1,
        createdAt: now,
        updatedAt: now,
      ),
      TodoItem(
        id: 'demo-3',
        content: 'Update documentation',
        status: TodoState.pending,
        priority: 'medium',
        order: 2,
        createdAt: now,
        updatedAt: now,
      ),
      TodoItem(
        id: 'demo-4',
        content: 'Deploy to staging',
        status: TodoState.completed,
        priority: 'high',
        order: 3,
        createdAt: now,
        updatedAt: now,
        completedAt: now - 3600000,
      ),
      TodoItem(
        id: 'demo-5',
        content: 'Triage open issues',
        status: TodoState.pending,
        priority: 'low',
        order: 4,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todoStateNotifierProvider);
    final items = state.items;
    final completedCount = items.where((i) => i.status == TodoState.completed).length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zen'),
        actions: [
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: Text(
                  '$completedCount/${items.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: items.isEmpty
          ? _EmptyState(theme: theme)
          : _TodoList(
              items: items,
              onToggleComplete: (id) {
                ref
                    .read(todoStateNotifierProvider.notifier)
                    .toggleComplete(id);
              },
            ),
    );
  }
}

/// The scrollable list of todo items.
class _TodoList extends StatelessWidget {
  const _TodoList({required this.items, required this.onToggleComplete});

  final List<TodoItem> items;
  final void Function(String id) onToggleComplete;

  @override
  Widget build(BuildContext context) {
    // Separate pending/in-progress from completed so completed sink to bottom.
    final active = items.where((i) => i.status != TodoState.completed).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final done = items.where((i) => i.status == TodoState.completed).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        if (active.isNotEmpty) ...[
          _SectionHeader(label: 'Tasks', theme: theme),
          ...active.map(
            (item) => AnimatedSwitcher(
              duration: AppDuration.normal,
              child: ZenTodoItem(
                key: ValueKey(item.id),
                item: item,
                onToggleComplete: () => onToggleComplete(item.id),
              ),
            ),
          ),
        ],
        if (done.isNotEmpty) ...[
          _SectionHeader(label: 'Completed', theme: theme),
          ...done.map(
            (item) => ZenTodoItem(
              key: ValueKey(item.id),
              item: item,
              onToggleComplete: () => onToggleComplete(item.id),
            ),
          ),
        ],
      ],
    );
  }
}

/// A lightweight section header label.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Placeholder shown when the todo list is empty.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No tasks',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'All caught up!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
