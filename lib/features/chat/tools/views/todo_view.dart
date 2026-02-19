import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// Todo list item model.
class TodoItem {
  final String content;
  final String status;
  final String? priority;
  final String? id;

  TodoItem({
    required this.content,
    required this.status,
    this.priority,
    this.id,
  });

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isPending => status == 'pending';
}

/// View for displaying TodoWrite tool todo lists.
class TodoView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const TodoView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final rawResult = tool['result'];
    final result = rawResult is Map<String, dynamic> ? rawResult : null;

    // Get todos from input first, then from result
    List<TodoItem> todos = _parseTodos(input['todos']);
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

    if (todos.isEmpty) {
      return const SizedBox.shrink();
    }

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: todos.map((todo) => _buildTodoItem(context, todo)).toList(),
      ),
    );
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

  Widget _buildTodoItem(BuildContext context, TodoItem todo) {
    final theme = Theme.of(context);

    Color color;
    if (todo.isCompleted) {
      color = const Color(0xFF34C759);
    } else if (todo.isInProgress) {
      color = theme.colorScheme.primary;
    } else {
      color = theme.colorScheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: todo.isCompleted,
              onChanged: null,
              materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: color, width: 1.5),
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.all(
                todo.isCompleted ? color : Colors.transparent,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              todo.content,
              style: TextStyle(
                fontSize: 14,
                color: todo.isCompleted
                    ? color.withAlpha(179)
                    : color,
                decoration: todo.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
