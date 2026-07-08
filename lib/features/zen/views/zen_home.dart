import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_empty_state.dart';
import '../../../core/models/session.dart';
import '../../../core/models/todo.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import '../../../core/utils/sync_subscription_mixin.dart';

// ─── Priority definitions ────────────────────────────────────────────────────

enum _Priority {
  critical,
  high,
  medium,
  low;

  static _Priority fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'critical':
        return critical;
      case 'high':
        return high;
      case 'medium':
        return medium;
      default:
        return low;
    }
  }

  String get label {
    switch (this) {
      case critical:
        return 'Critical';
      case high:
        return 'High';
      case medium:
        return 'Medium';
      case low:
        return 'Low';
    }
  }

  Color get borderColor {
    // Resolved from the canonical [AppColors.priority*] tokens so the
    // Zen section header, the todo-row priority chip, and any future
    // priority-aware surface all read from one source of truth.
    switch (this) {
      case critical:
        return AppColors.priorityCritical;
      case high:
        return AppColors.priorityHigh;
      case medium:
        return AppColors.priorityMedium;
      case low:
        return AppColors.priorityLow;
    }
  }

  IconData get icon {
    switch (this) {
      case critical:
        return Icons.error_rounded;
      case high:
        return Icons.keyboard_double_arrow_up_rounded;
      case medium:
        return Icons.remove_rounded;
      case low:
        return Icons.keyboard_double_arrow_down_rounded;
    }
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _SessionTodo {
  const _SessionTodo({
    required this.item,
    required this.sessionTitle,
    required this.sessionId,
  });

  final TodoItem item;
  final String sessionTitle;
  final String sessionId;
}

// ─── Zen Home Screen ─────────────────────────────────────────────────────────

/// Zen home screen — aggregates todos from all sessions,
/// grouped by priority (critical / high / medium / low) in
/// collapsible sections with colored left-border headers.
class ZenHomeScreen extends ConsumerStatefulWidget {
  const ZenHomeScreen({super.key});

  @override
  ConsumerState<ZenHomeScreen> createState() => _ZenHomeScreenState();
}

class _ZenHomeScreenState extends ConsumerState<ZenHomeScreen>
    with SyncSubscriptionMixin {
  /// Which priority sections are currently collapsed.
  final Set<_Priority> _collapsed = {};

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(sessionsNotifierProvider.notifier).refreshFromSync();
    });
    subscribeToDomains(
      {SyncDomain.sessions},
      () => ref.read(sessionsNotifierProvider.notifier).loadFromSync(),
    );
  }

  // ─── Data helpers ─────────────────────────────────────────────────────────

  List<_SessionTodo> _collectTodos(List<Session> sessions) {
    final result = <_SessionTodo>[];
    for (final session in sessions) {
      final todos = session.todos;
      if (todos == null || todos.isEmpty) continue;
      for (final item in todos) {
        if (item.status.isTerminal) continue;
        result.add(
          _SessionTodo(
            item: item,
            sessionTitle: getSessionName(session),
            sessionId: session.id,
          ),
        );
      }
    }
    return result;
  }

  Map<_Priority, List<_SessionTodo>> _groupByPriority(
    List<_SessionTodo> todos,
  ) {
    final map = <_Priority, List<_SessionTodo>>{};
    for (final st in todos) {
      final p = _Priority.fromString(st.item.priority);
      map.putIfAbsent(p, () => []).add(st);
    }
    // Sort each group by original order field
    for (final group in map.values) {
      group.sort((a, b) => a.item.order.compareTo(b.item.order));
    }
    return map;
  }

  void _toggleSection(_Priority priority) {
    setState(() {
      if (_collapsed.contains(priority)) {
        _collapsed.remove(priority);
      } else {
        _collapsed.add(priority);
      }
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch the identity-stable derived list — only emits when the sessions
    // map identity actually changes (gated by mapValuesIdentical in
    // SessionsNotifier.loadFromSync).
    final sessions = ref.watch(sessionsListProvider);
    final todos = _collectTodos(sessions);
    final grouped = _groupByPriority(todos);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zen'),
        centerTitle: false,
      ),
      body: todos.isEmpty
          ? _EmptyState()
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: _Priority.values
                  .where((p) => grouped.containsKey(p))
                  .expand(
                    (p) => [
                      _PrioritySectionHeader(
                        priority: p,
                        count: grouped[p]!.length,
                        collapsed: _collapsed.contains(p),
                        onToggle: () => _toggleSection(p),
                      ),
                      AnimatedCrossFade(
                        firstChild: _PrioritySectionBody(
                          priority: p,
                          todos: grouped[p]!,
                        ),
                        secondChild: const SizedBox.shrink(),
                        crossFadeState: _collapsed.contains(p)
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                        sizeCurve: Curves.easeInOut,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  )
                  .toList(),
            ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _PrioritySectionHeader extends StatelessWidget {
  const _PrioritySectionHeader({
    required this.priority,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });

  final _Priority priority;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = priority.borderColor;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: borderColor, width: 3),
          ),
          color: borderColor.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(AppRadius.sm),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              priority.icon,
              size: 16,
              color: borderColor,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                priority.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: borderColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: borderColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: borderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section body ─────────────────────────────────────────────────────────────

class _PrioritySectionBody extends StatelessWidget {
  const _PrioritySectionBody({
    required this.priority,
    required this.todos,
  });

  final _Priority priority;
  final List<_SessionTodo> todos;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 3, bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: priority.borderColor.withValues(alpha: 0.30),
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: todos
            .map((st) => _TodoRow(priority: priority, sessionTodo: st))
            .toList(),
      ),
    );
  }
}

// ─── Todo row ─────────────────────────────────────────────────────────────────

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.priority, required this.sessionTodo});

  final _Priority priority;
  final _SessionTodo sessionTodo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = sessionTodo.item;
    final isInProgress = item.status == TodoState.inProgress;

    final Color statusColor;
    final IconData statusIcon;
    if (isInProgress) {
      statusColor = theme.colorScheme.primary;
      statusIcon = Icons.radio_button_checked_rounded;
    } else {
      statusColor =
          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
      statusIcon = Icons.check_box_outline_blank_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(statusIcon, size: 16, color: statusColor),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  sessionTodo.sessionTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.65),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.checklist_rounded,
      title: 'No active tasks',
      subtitle:
          'Tasks from your sessions will appear here, grouped by priority.',
    );
  }
}
