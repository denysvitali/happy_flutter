import 'package:riverpod/riverpod.dart';

import '../../core/models/todo.dart';

/// Lightweight in-memory state for the zen todo list.
class TodoListState {
  const TodoListState({this.items = const []});

  final List<TodoItem> items;

  TodoListState copyWith({List<TodoItem>? items}) {
    return TodoListState(items: items ?? this.items);
  }
}

/// Notifier that manages the zen todo list in memory.
///
/// Todos are not persisted; they are populated from the sync layer
/// and held in-memory for the duration of the session.
class TodoStateNotifier extends Notifier<TodoListState> {
  @override
  TodoListState build() => const TodoListState();

  /// Replace the full list of todos (e.g., on server fetch).
  void setItems(List<TodoItem> items) {
    state = state.copyWith(items: List<TodoItem>.from(items));
  }

  /// Toggle a todo between pending and completed by [id].
  ///
  /// If the item is already completed, it reverts to pending.
  void toggleComplete(String id) {
    final updated = state.items.map((item) {
      if (item.id != id) return item;
      final next = item.status == TodoState.completed
          ? TodoState.pending
          : TodoState.completed;
      return item.copyWith(status: next);
    }).toList();
    state = state.copyWith(items: updated);
  }

  /// Mark a todo as [TodoState.completed] by [id].
  void markComplete(String id) {
    final updated = state.items.map((item) {
      if (item.id != id) return item;
      return item.copyWith(status: TodoState.completed);
    }).toList();
    state = state.copyWith(items: updated);
  }

  /// Add a new todo item to the list.
  void addItem(TodoItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  /// Remove a todo by [id].
  void removeItem(String id) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
    );
  }

  void clear() {
    state = const TodoListState();
  }

  // No-ops for sync compatibility — zen todos use in-memory state.
  void loadFromSync() {}
  Future<void> refreshFromSync() async {}
}

final todoStateNotifierProvider =
    NotifierProvider<TodoStateNotifier, TodoListState>(() {
      return TodoStateNotifier();
    });
