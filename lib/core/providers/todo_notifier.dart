import 'package:riverpod/riverpod.dart';

import '../models/todo.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';
import '_shared.dart';

class TodoStateNotifier extends Notifier<TodoListState> {
  int _lastDataChangeCounter = -1;

  @override
  TodoListState build() => TodoListState();

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.dataChangeCounter;
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.todoLists;
    // Fast path: check length first, then use identical() for each value
    final currentLists = state.lists;
    if (currentLists.length == next.length) {
      bool changed = false;
      next.forEach((key, value) {
        if (!identical(currentLists[key], value)) {
          changed = true;
        }
      });
      if (!changed) return;
    }
    state = TodoListState(lists: Map<String?, TodoList>.from(next));
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    try {
      await sync.todosSync.invalidateAndAwait();
    } catch (e) {
      logger.warning('Failed to refresh todos: $e');
    }
    loadFromSync();
  }

  void setTodoList(TodoList list) {
    state = state.copyWith(lists: {...state.lists, list.sessionId: list});
  }

  void addTodo(String sessionId, TodoItem item) {
    final list = state.lists[sessionId];
    if (list != null) {
      final updatedItems = [...list.items, item];
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      state = state.copyWith(lists: {...state.lists, sessionId: updatedList});
    }
  }

  void updateTodo(
    String sessionId,
    String todoId,
    TodoItem Function(TodoItem) update,
  ) {
    final list = state.lists[sessionId];
    if (list != null) {
      final updatedItems = list.items.map((item) {
        if (item.id == todoId) {
          return update(item);
        }
        return item;
      }).toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      state = state.copyWith(lists: {...state.lists, sessionId: updatedList});
    }
  }

  void removeTodo(String sessionId, String todoId) {
    final list = state.lists[sessionId];
    if (list != null) {
      final updatedItems = list.items
          .where((item) => item.id != todoId)
          .toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      state = state.copyWith(lists: {...state.lists, sessionId: updatedList});
    }
  }

  void reorderTodos(
    String sessionId,
    String todoId,
    int newOrder, {
    Object? newParentId = unset,
  }) {
    final list = state.lists[sessionId];
    if (list != null) {
      final parentChanged = !identical(newParentId, unset);
      final resolvedParentId = parentChanged ? newParentId as String? : null;
      final updatedItems = list.items.map((item) {
        if (item.id == todoId) {
          return item.copyWith(
            order: newOrder,
            clearParentId: parentChanged && resolvedParentId == null,
            parentId: parentChanged && resolvedParentId != null
                ? resolvedParentId
                : null,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
        }
        return item;
      }).toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      state = state.copyWith(lists: {...state.lists, sessionId: updatedList});
    }
  }

  void clearSessionTodos(String sessionId) {
    state = state.copyWith(
      lists: Map<String?, TodoList>.from(state.lists)..remove(sessionId),
    );
  }

  void clear() {
    state = TodoListState();
  }
}

class TodoListState {
  TodoListState({this.lists = const {}});
  final Map<String?, TodoList> lists;

  List<TodoItem>? _allTodosCache;

  TodoListState copyWith({Map<String?, TodoList>? lists}) {
    return TodoListState(lists: lists ?? this.lists)
      .._allTodosCache = null;
  }

  TodoList? getGlobalList() => lists[null];

  List<TodoItem> get allTodos {
    return _allTodosCache ??=
        lists.values.expand((list) => list.items).toList();
  }

  int get totalCount => allTodos.length;
  int get completedCount =>
      allTodos.where((t) => t.status == TodoState.completed).length;
}

final todoStateNotifierProvider =
    NotifierProvider<TodoStateNotifier, TodoListState>(() {
      return TodoStateNotifier();
    });
