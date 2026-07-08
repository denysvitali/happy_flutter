import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/todo_item.dart';

/// Zen home screen — displays the current todo list.
///
/// Tasks are pushed into [todoStateNotifierProvider] by the chat
/// layer whenever the agent issues a TodoWrite / todo_list tool call,
/// so this view always reflects the most recent agent task state.
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
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    // Tasks are pushed by the chat layer (TodoView) into the global
    // notifier. We also subscribe to `sync.onDataChanged` so the Zen
    // home picks up coalesced updates even if no TodoView is mounted.
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      // Touch the provider to force a rebuild — the notifier already
      // holds the canonical list, this is just a wakeup.
      ref.read(todoStateNotifierProvider);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todoStateNotifierProvider);
    final items = state.items;
    final completedCount =
        items.where((i) => i.status == TodoState.completed).length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
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
          ? const _EmptyState()
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.checklist_rounded,
      title: 'No tasks yet',
      subtitle:
          'Agent task lists from chat will appear here. '
          'Open a session and ask the agent to plan a task '
          'to see TodoWrite items surface on this screen.',
    );
  }
}
