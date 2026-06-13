import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/todo.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/wire_parsers.dart';
import '../tool_section_view.dart';

/// View-local task list item (the on-the-wire shape from TodoWrite).
///
/// Kept separate from the domain [TodoItem] in `core/models/todo.dart`
/// because the tool input only carries a subset of fields. Conversion
/// to the domain model happens in [_pushToGlobalState].
class TodoViewItem {
  TodoViewItem({
    required this.content,
    required this.status,
    this.priority,
    this.id,
    this.description,
  });
  final String content;
  final String status;
  final String? priority;
  final String? id;
  final String? description;

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isPending => status == 'pending';
}

/// View for displaying TodoWrite tool todo lists.
///
/// Each time the tool data changes the view also pushes the parsed
/// items into [todoStateNotifierProvider] so they remain visible to
/// the user outside of the chat (e.g. on the Zen home screen).
class TodoView extends ConsumerStatefulWidget {
  const TodoView({
    required this.tool,
    super.key,
    this.metadata,
    this.sessionId,
  });
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  /// Owning chat session — used to scope the global todo state.
  ///
  /// When `null`, items are stored under a synthetic global key so the
  /// Zen home can still display them.
  final String? sessionId;

  @override
  ConsumerState<TodoView> createState() => _TodoViewState();
}

class _TodoViewState extends ConsumerState<TodoView> {
  List<TodoViewItem> _todos = const [];

  /// Stable identifier for this tool call. Used to derive deterministic
  /// item ids when the wire format doesn't carry one — guarantees a
  /// second render of the same TodoWrite produces the same item ids.
  String get _toolId {
    final id = widget.tool['toolUseId'] as String? ??
        widget.tool['id'] as String?;
    if (id != null && id.isNotEmpty) return id;
    return widget.tool['name']?.toString() ?? 'todo';
  }

  @override
  void initState() {
    super.initState();
    _todos = _resolveTodos();
    _pushToGlobalState(_todos);
  }

  @override
  void didUpdateWidget(TodoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _resolveTodos();
    var changed = next.length != _todos.length;
    if (!changed) {
      for (var i = 0; i < next.length; i++) {
        if (_todos[i].status != next[i].status ||
            _todos[i].content != next[i].content ||
            _todos[i].description != next[i].description) {
          changed = true;
          break;
        }
      }
    }
    if (!changed) return;
    setState(() => _todos = next);
    _pushToGlobalState(next);
  }

  void _pushToGlobalState(List<TodoViewItem> items) {
    if (items.isEmpty) {
      // Empty TodoWrite is still a meaningful state — clear the
      // session's list so the Zen home doesn't show stale tasks.
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(todoStateNotifierProvider.notifier).setItemsForSession(
            widget.sessionId,
            const [],
          );
      return;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final domain = <TodoItem>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      // Canonical id: prefer the wire id, then content-hash, then a
      // tool-stable synthetic key. Falls back to position so the same
      // tool call always yields the same id.
      final id = (it.id?.isNotEmpty ?? false)
          ? it.id!
          : '$_toolId#${it.content.hashCode}';
      domain.add(
        TodoItem(
          id: id,
          content: it.content,
          status: TodoState.fromString(it.status),
          priority: it.priority ?? 'medium',
          order: i,
          description: it.description,
          createdAt: now,
          updatedAt: now,
          sessionId: widget.sessionId,
        ),
      );
    }
    container
        .read(todoStateNotifierProvider.notifier)
        .setItemsForSession(widget.sessionId, domain);
  }

  List<TodoViewItem> _resolveTodos() {
    final input = WireParsers.asMap(widget.tool['input']) ?? {};
    final rawResult = widget.tool['result'];
    final result = rawResult is Map<String, dynamic> ? rawResult : null;

    var todos = _parseTodos(input['todos']);
    if (todos.isEmpty) {
      todos = _parseTodos(input['items']);
    }
    if (todos.isEmpty && result != null) {
      final newTodos = result['newTodos'] as List?;
      if (newTodos != null) {
        todos = newTodos
            .map(
              (t) => TodoViewItem(
                content: t['content'] as String? ?? '',
                status: t['status'] as String? ?? 'pending',
                priority: t['priority'] as String?,
                id: t['id'] as String?,
                description: t['description'] as String?,
              ),
            )
            .toList();
      }
    }
    if (todos.isEmpty && result != null) {
      todos = _parseTodos(result['items']);
    }
    if (todos.isEmpty && result != null) {
      todos = _parseTodos(result['todos']);
    }
    final nestedOutput = result != null
        ? WireParsers.asMap(result['output'])
        : null;
    if (todos.isEmpty && nestedOutput != null) {
      todos = _parseTodos(nestedOutput['items']);
    }
    if (todos.isEmpty && nestedOutput != null) {
      todos = _parseTodos(nestedOutput['todos']);
    }
    return todos;
  }

  List<TodoViewItem> _parseTodos(dynamic todos) {
    if (todos == null) return const [];
    if (todos is! List) return const [];
    return todos
        .map((t) {
          if (t is! Map<String, dynamic>) return null;
          final text = t['content'] as String? ?? t['text'] as String? ?? '';
          final completed = t['completed'] == true;
          final status =
              t['status'] as String? ?? (completed ? 'completed' : 'pending');
          return TodoViewItem(
            content: text,
            status: status,
            priority: t['priority'] as String?,
            id: t['id'] as String?,
            description: t['description'] as String?,
          );
        })
        .whereType<TodoViewItem>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_todos.isEmpty) return const SizedBox.shrink();

    final completed = _todos.where((t) => t.isCompleted).length;
    final total = _todos.length;

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Count summary header
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _CountSummary(completed: completed, total: total),
          ),
          // Task items
          ..._todos.map(
            (todo) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              ),
              child: _TodoRow(
                key: ValueKey(
                  '${todo.id ?? todo.content}'
                  '_${todo.status}',
                ),
                todo: todo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small summary label showing "X/Y done".
class _CountSummary extends StatelessWidget {
  const _CountSummary({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allDone = completed == total;
    final color = allDone
        ? AppColors.success
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(
          allDone ? Icons.check_circle_rounded : Icons.checklist_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$completed/$total done',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// A single todo row with status icon and text.
class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.todo, super.key});

  final TodoViewItem todo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color statusColor;
    if (todo.isCompleted) {
      statusColor = AppColors.success;
    } else if (todo.isInProgress) {
      statusColor = theme.colorScheme.primary;
    } else {
      statusColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    }

    final Widget statusIcon;
    if (todo.isCompleted) {
      statusIcon = Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: statusColor,
      );
    } else if (todo.isInProgress) {
      statusIcon = _PulsingIcon(color: statusColor);
    } else {
      statusIcon = Icon(
        Icons.check_box_outline_blank_rounded,
        size: 18,
        color: statusColor,
      );
    }

    final decoration = todo.isCompleted ? TextDecoration.lineThrough : null;
    final textColor = todo.isCompleted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: statusIcon),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              todo.content,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                decoration: decoration,
                decorationColor: textColor,
                height: AppLineHeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated pulsing radio icon for in-progress items.
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.color});
  final Color color;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Icon(
        Icons.radio_button_checked_rounded,
        size: 18,
        color: widget.color,
      ),
    );
  }
}
