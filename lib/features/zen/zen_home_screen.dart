import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/components.dart';
import '../../core/components/tablet/master_detail_scaffold.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/todo.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/sync_subscription_mixin.dart';
import 'zen_new_screen.dart';
import 'zen_priority.dart';
import 'zen_view_screen.dart';

/// Inline detail mode for the wide (tablet+) zen layout.
enum _ZenInlineMode { none, view, create }

/// Selector value for todo data used in zen home.
class _ZenTodoData {
  _ZenTodoData({
    required this.allTodos,
    required this.totalCount,
    required this.completedCount,
  });

  final List<TodoItem> allTodos;
  final int totalCount;
  final int completedCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ZenTodoData &&
          listEquals(allTodos, other.allTodos) &&
          totalCount == other.totalCount &&
          completedCount == other.completedCount;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(allTodos), totalCount, completedCount);
}

/// Zen home screen — displays all todo items grouped by status.
class ZenHomeScreen extends ConsumerStatefulWidget {
  /// Creates the Zen home screen.
  const ZenHomeScreen({super.key});

  @override
  ConsumerState<ZenHomeScreen> createState() => _ZenHomeScreenState();
}

class _ZenHomeScreenState extends ConsumerState<ZenHomeScreen>
    with SyncSubscriptionMixin {
  bool _isLoading = true;
  String? _selectedTodoId;
  String? _selectedSessionId;
  _ZenInlineMode _inlineMode = _ZenInlineMode.none;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      ref.read(todoStateNotifierProvider.notifier).loadFromSync();
      await ref.read(todoStateNotifierProvider.notifier).refreshFromSync();
      if (mounted) setState(() => _isLoading = false);
    });
    subscribeToDomains([SyncDomain.todos], () {
      ref.read(todoStateNotifierProvider.notifier).loadFromSync();
    });
  }

  void _clearInline() {
    setState(() {
      _selectedTodoId = null;
      _selectedSessionId = null;
      _inlineMode = _ZenInlineMode.none;
    });
  }

  void _openTodoWide(TodoItem item) {
    setState(() {
      _selectedTodoId = item.id;
      _selectedSessionId = item.sessionId ?? 'global';
      _inlineMode = _ZenInlineMode.view;
    });
  }

  void _openCreateWide() {
    setState(() {
      _selectedTodoId = null;
      _selectedSessionId = null;
      _inlineMode = _ZenInlineMode.create;
    });
  }

  void _openTodoNarrow(TodoItem item) {
    context.push(
      '/zen/view',
      extra: {
        'todoId': item.id,
        'sessionId': item.sessionId ?? 'global',
      },
    );
  }

  void _openCreateNarrow() {
    context.push('/zen/new');
  }

  @override
  Widget build(BuildContext context) {
    final todoData = ref.watch(
      todoStateNotifierProvider.select(
        (state) => _ZenTodoData(
          allTodos: state.allTodos,
          totalCount: state.totalCount,
          completedCount: state.completedCount,
        ),
      ),
    );
    final allTodos = todoData.allTodos;
    final totalCount = todoData.totalCount;
    final completedCount = todoData.completedCount;

    final activeTodos = allTodos
        .where(
          (t) =>
              t.status == TodoState.pending || t.status == TodoState.inProgress,
        )
        .toList(growable: false);

    final completedTodos = allTodos
        .where((t) => t.status.isTerminal)
        .toList(growable: false);

    final isWide = MasterDetailScaffold.isWide(context);

    // If selection no longer exists (e.g. deleted), reset inline state.
    if (isWide &&
        _inlineMode == _ZenInlineMode.view &&
        _selectedTodoId != null) {
      final stillExists = allTodos.any(
        (t) => t.id == _selectedTodoId,
      );
      if (!stillExists) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _clearInline();
        });
      }
    }

    final masterBody = _isLoading
        ? const _ZenLoadingShimmer()
        : allTodos.isEmpty
        ? AppEmptyState(
            icon: Icons.spa,
            title: context.l10n.zenEmptyTitle,
            subtitle: context.l10n.zenEmptySubtitle,
            action: FilledButton.icon(
              onPressed: () =>
                  isWide ? _openCreateWide() : _openCreateNarrow(),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.zenNewTask),
            ),
          )
        : _TodoSectionsList(
            activeTodos: activeTodos,
            completedTodos: completedTodos,
            selectedId: isWide ? _selectedTodoId : null,
            onOpen: (item) =>
                isWide ? _openTodoWide(item) : _openTodoNarrow(item),
          );

    final scaffoldBody = isWide
        ? MasterDetailScaffold(
            master: masterBody,
            hasSelection: _inlineMode != _ZenInlineMode.none,
            emptyDetail: const TabletDetailEmpty(
              icon: Icons.task_alt_outlined,
              // TODO(i18n): localize 'Select a todo'.
              message: 'Select a todo',
            ),
            detail: switch (_inlineMode) {
              _ZenInlineMode.view => ZenViewScreen(
                key: ValueKey<String>(
                  'zen-view-${_selectedTodoId ?? ''}',
                ),
                todoId: _selectedTodoId ?? '',
                sessionId: _selectedSessionId ?? 'global',
                embedded: true,
                onClose: _clearInline,
              ),
              _ZenInlineMode.create => ZenNewScreen(
                key: const ValueKey<String>('zen-new-embedded'),
                embedded: true,
                onClose: _clearInline,
              ),
              _ZenInlineMode.none => const TabletDetailEmpty(
                icon: Icons.task_alt_outlined,
                // TODO(i18n): localize 'Select a todo'.
                message: 'Select a todo',
              ),
            },
          )
        : masterBody;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(context.l10n.zenTitle),
            if (totalCount > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              _TaskCountBadge(completed: completedCount, total: totalCount),
            ],
          ],
        ),
      ),
      body: scaffoldBody,
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            isWide ? _openCreateWide() : _openCreateNarrow(),
        tooltip: context.l10n.zenNewTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TaskCountBadge extends StatelessWidget {
  const _TaskCountBadge({required this.completed, required this.total});

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

class _TodoItemCard extends StatelessWidget {
  const _TodoItemCard({
    required this.item,
    required this.onTap,
    required this.isSelected,
  });

  final TodoItem item;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = item.status.isTerminal;

    // Apply opacity via color alpha instead of wrapping the entire
    // card in an Opacity widget (which forces a separate layer).
    final alpha = isDone ? AppOpacity.medium + 0.3 : 1.0;
    final card = AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: isDone ? null : onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Opacity(
        opacity: alpha,
        child: Row(
          children: [
            _StatusIcon(status: item.status),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                item.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration:
                      isDone ? TextDecoration.lineThrough : null,
                  decorationColor: theme.colorScheme.onSurface,
                  color: isDone
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _PriorityBadge(priority: item.priority),
          ],
        ),
      ),
    );
    if (!isSelected) return card;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer
            .withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: card,
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final TodoState status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case TodoState.completed:
        return Icon(Icons.check_circle, color: cs.primary, size: AppSpacing.xl);
      case TodoState.canceled:
        return Icon(
          Icons.cancel_outlined,
          color: cs.error,
          size: AppSpacing.xl,
        );
      case TodoState.inProgress:
        return Icon(Icons.timelapse, color: cs.tertiary, size: AppSpacing.xl);
      case TodoState.pending:
        return Icon(
          Icons.radio_button_unchecked,
          color: cs.onSurfaceVariant,
          size: AppSpacing.xl,
        );
    }
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

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
        color: color.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        priority,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: AppFontSize.xxs,
        ),
      ),
    );
  }
}

class _TodoSectionsList extends StatelessWidget {
  const _TodoSectionsList({
    required this.activeTodos,
    required this.completedTodos,
    required this.onOpen,
    required this.selectedId,
  });

  final List<TodoItem> activeTodos;
  final List<TodoItem> completedTodos;
  final void Function(TodoItem item) onOpen;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppScreenPadding.standard.copyWith(bottom: 80),
      children: [
        if (activeTodos.isNotEmpty) ...[
          AppSectionHeader(
            title: context.l10n.zenSectionActive,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          for (final item in activeTodos)
            _TodoItemCard(
              item: item,
              onTap: () => onOpen(item),
              isSelected: selectedId == item.id,
            ),
        ],
        if (completedTodos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(
            title: context.l10n.zenSectionCompleted,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          for (final item in completedTodos)
            _TodoItemCard(
              item: item,
              onTap: () => onOpen(item),
              isSelected: selectedId == item.id,
            ),
        ],
      ],
    );
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
        padding: AppScreenPadding.standard.copyWith(bottom: 80),
        children: [
          Container(
            height: 14,
            width: 80,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          for (int i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: AppSpacing.xl,
                      height: AppSpacing.xl,
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
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 40,
                      height: 18,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
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
