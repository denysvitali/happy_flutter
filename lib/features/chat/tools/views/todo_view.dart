import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../tool_section_view.dart';

/// Task list item model.
class TodoItem {

  TodoItem({
    required this.content,
    required this.status,
    this.priority,
    this.id,
  });
  final String content;
  final String status;
  final String? priority;
  final String? id;

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isPending => status == 'pending';
}

/// View for displaying TodoWrite tool todo lists.
class TodoView extends StatefulWidget {

  const TodoView({required this.tool, super.key, this.metadata});
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  @override
  State<TodoView> createState() => _TodoViewState();
}

class _TodoViewState extends State<TodoView> {
  List<TodoItem> _todos = [];

  @override
  void initState() {
    super.initState();
    _todos = _resolveTodos();
  }

  @override
  void didUpdateWidget(TodoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _resolveTodos();
    var changed = next.length != _todos.length;
    if (!changed) {
      for (var i = 0; i < next.length; i++) {
        if (_todos[i].status != next[i].status ||
            _todos[i].content != next[i].content) {
          changed = true;
          break;
        }
      }
    }
    if (changed) setState(() => _todos = next);
  }

  List<TodoItem> _resolveTodos() {
    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final rawResult = widget.tool['result'];
    final result =
        rawResult is Map<String, dynamic> ? rawResult : null;

    var todos = _parseTodos(input['todos']);
    if (todos.isEmpty && result != null) {
      final newTodos = result['newTodos'] as List?;
      if (newTodos != null) {
        todos = newTodos
            .map(
              (t) => TodoItem(
                content: t['content'] as String? ?? '',
                status: t['status'] as String? ?? 'pending',
                priority: t['priority'] as String?,
                id: t['id'] as String?,
              ),
            )
            .toList();
      }
    }
    return todos;
  }

  List<TodoItem> _parseTodos(dynamic todos) {
    if (todos == null) return [];
    if (todos is! List) return [];
    return todos
        .map((t) {
          if (t is! Map<String, dynamic>) return null;
          return TodoItem(
            content: t['content'] as String? ?? '',
            status: t['status'] as String? ?? 'pending',
            priority: t['priority'] as String?,
            id: t['id'] as String?,
          );
        })
        .whereType<TodoItem>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_todos.isEmpty) return const SizedBox.shrink();

    final completed =
        _todos.where((t) => t.isCompleted).length;
    final total = _todos.length;

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Count summary header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CountSummary(
              completed: completed,
              total: total,
            ),
          ),
          // Task items
          ..._todos.map(
            (todo) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      child: child,
                    ),
                  ),
              child: _TodoRow(
                key: ValueKey('${todo.id ?? todo.content}'
                    '_${todo.status}'),
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
  const _CountSummary({
    required this.completed,
    required this.total,
  });

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
          allDone
              ? Icons.check_circle_rounded
              : Icons.checklist_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
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

  final TodoItem todo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color statusColor;
    if (todo.isCompleted) {
      statusColor = AppColors.success;
    } else if (todo.isInProgress) {
      statusColor = theme.colorScheme.primary;
    } else {
      statusColor = theme.colorScheme.onSurfaceVariant
          .withValues(alpha: 0.6);
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

    final decoration =
        todo.isCompleted ? TextDecoration.lineThrough : null;
    final textColor = todo.isCompleted
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: statusIcon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              todo.content,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                decoration: decoration,
                decorationColor: textColor,
                height: 1.4,
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
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
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
