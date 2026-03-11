import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';

/// Zen home screen — displays all todo items grouped by status.
class ZenHomeScreen extends ConsumerStatefulWidget {
  /// Creates the Zen home screen.
  const ZenHomeScreen({super.key});

  @override
  ConsumerState<ZenHomeScreen> createState() => _ZenHomeScreenState();
}

class _ZenHomeScreenState extends ConsumerState<ZenHomeScreen> {
  StreamSubscription<void>? _syncSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(todoStateNotifierProvider.notifier)
          .refreshFromSync();
      if (mounted) setState(() => _isLoading = false);
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
              const SizedBox(width: AppSpacing.sm),
              _TaskCountBadge(
                completed: completedCount,
                total: totalCount,
              ),
            ],
          ],
        ),
      ),
      body: _isLoading
          ? const _ZenLoadingShimmer()
          : allTodos.isEmpty
          ? AppEmptyState(
              icon: Icons.check_circle_outline,
              title: context.l10n.zenEmptyTitle,
              subtitle: context.l10n.zenEmptySubtitle,
              action: FilledButton.icon(
                onPressed: () => context.push('/zen/new'),
                icon: const Icon(Icons.add),
                label: Text(context.l10n.zenNewTask),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                80,
              ),
              children: [
                if (activeTodos.isNotEmpty) ...[
                  _SectionHeader(
                    title: context.l10n.zenSectionActive,
                  ),
                  const SizedBox(height: AppSpacing.xs),
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
                  const SizedBox(height: AppSpacing.lg),
                  _SectionHeader(
                    title: context.l10n.zenSectionCompleted,
                  ),
                  const SizedBox(height: AppSpacing.xs),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.3,
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
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: AppElevation.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Opacity(
        opacity: isDone ? 0.6 : 1.0,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          leading: _StatusIcon(status: item.status),
          title: Text(
            item.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              decoration: isDone ? TextDecoration.lineThrough : null,
              decorationColor: theme.colorScheme.onSurface,
              color: isDone
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
          trailing: _PriorityDot(priority: item.priority),
          minVerticalPadding: AppTouchTarget.min / 2,
        ),
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

/// A compact colored dot indicating priority level.
class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

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
    final color = _color(priority, Theme.of(context).colorScheme);
    return AppStatusDot(color: color, size: 10);
  }
}

class _ZenLoadingShimmer extends StatelessWidget {
  const _ZenLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.surfaceContainerHighest;

    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          80,
        ),
        children: [
          // Section header placeholder.
          Container(
            height: 14,
            width: 80,
            margin: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (int i = 0; i < 4; i++)
            Card(
              margin: const EdgeInsets.only(
                bottom: AppSpacing.md,
              ),
              elevation: AppElevation.none,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppRadius.md),
                side: BorderSide(
                  color: cs.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Container(
                        height: 14,
                        width: 140 + (i * 25.0) % 80,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius:
                              BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
