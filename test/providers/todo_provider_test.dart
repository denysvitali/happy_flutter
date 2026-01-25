import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('TodoStateProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with default state', () {
      final state = container.read(todoStateNotifierProvider);
      expect(state.lists, isEmpty);
    });

    test('should set a todo list for a session', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Test todo',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);

      final state = container.read(todoStateNotifierProvider);
      expect(state.lists, hasLength(1));
      expect(state.lists['session-1']?.items, hasLength(1));
    });

    test('should add a todo to a session list', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);

      final todo = TodoItem(
        id: 'todo-1',
        content: 'New todo',
        status: TodoState.pending,
        priority: 'high',
        order: 0,
        createdAt: 1234567891,
        updatedAt: 1234567891,
      );

      notifier.addTodo('session-1', todo);

      final state = container.read(todoStateNotifierProvider);
      expect(state.lists['session-1']?.items, hasLength(1));
      expect(state.lists['session-1']?.items.first.content, 'New todo');
    });

    test('should update a todo in a session list', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Original content',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);

      notifier.updateTodo('session-1', 'todo-1', (existing) {
        return existing.copyWith(
          content: 'Updated content',
          status: TodoState.completed,
        );
      });

      final state = container.read(todoStateNotifierProvider);
      final updatedTodo = state.lists['session-1']?.items.first;
      expect(updatedTodo?.content, 'Updated content');
      expect(updatedTodo?.status, TodoState.completed);
    });

    test('should remove a todo from a session list', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Todo 1',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
          TodoItem(
            id: 'todo-2',
            content: 'Todo 2',
            status: TodoState.pending,
            priority: 'medium',
            order: 1,
            createdAt: 1234567891,
            updatedAt: 1234567891,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);
      expect(
        container.read(todoStateNotifierProvider).lists['session-1']?.items,
        hasLength(2),
      );

      notifier.removeTodo('session-1', 'todo-1');

      final state = container.read(todoStateNotifierProvider);
      expect(state.lists['session-1']?.items, hasLength(1));
      expect(state.lists['session-1']?.items.first.id, 'todo-2');
    });

    test('should reorder todos', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Todo 1',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
          TodoItem(
            id: 'todo-2',
            content: 'Todo 2',
            status: TodoState.pending,
            priority: 'medium',
            order: 1,
            createdAt: 1234567891,
            updatedAt: 1234567891,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);

      notifier.reorderTodos('session-1', 'todo-1', 5);

      final state = container.read(todoStateNotifierProvider);
      final updatedTodo = state.lists['session-1']?.items
        .firstWhere((todo) => todo.id == 'todo-1');
      expect(updatedTodo?.order, 5);
    });

    test('should reorder todos with new parent', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Parent todo',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
          TodoItem(
            id: 'todo-2',
            content: 'Child todo',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            parentId: 'todo-1',
            createdAt: 1234567891,
            updatedAt: 1234567891,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);

      notifier.reorderTodos('session-1', 'todo-2', 1, newParentId: null);

      final state = container.read(todoStateNotifierProvider);
      final updatedTodo = state.lists['session-1']?.items
        .firstWhere((todo) => todo.id == 'todo-2');
      expect(updatedTodo?.parentId, isNull);
      expect(updatedTodo?.order, 1);
    });

    test('should clear todos for a specific session', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list1 = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Session 1 todo',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
        ],
        updatedAt: 1234567890,
      );

      final list2 = TodoList(
        sessionId: 'session-2',
        items: [
          TodoItem(
            id: 'todo-2',
            content: 'Session 2 todo',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            createdAt: 1234567891,
            updatedAt: 1234567891,
          ),
        ],
        updatedAt: 1234567891,
      );

      notifier.setTodoList(list1);
      notifier.setTodoList(list2);

      expect(container.read(todoStateNotifierProvider).lists, hasLength(2));

      notifier.clearSessionTodos('session-1');

      final state = container.read(todoStateNotifierProvider);
      expect(state.lists, hasLength(1));
      expect(state.lists.containsKey('session-1'), isFalse);
      expect(state.lists.containsKey('session-2'), isTrue);
    });

    test('should clear all todos', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list1 = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Session 1 todo',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
        ],
        updatedAt: 1234567890,
      );

      final list2 = TodoList(
        sessionId: 'session-2',
        items: [
          TodoItem(
            id: 'todo-2',
            content: 'Session 2 todo',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            createdAt: 1234567891,
            updatedAt: 1234567891,
          ),
        ],
        updatedAt: 1234567891,
      );

      notifier.setTodoList(list1);
      notifier.setTodoList(list2);

      expect(container.read(todoStateNotifierProvider).lists, hasLength(2));

      notifier.clear();

      final state = container.read(todoStateNotifierProvider);
      expect(state.lists, isEmpty);
    });

    test('should handle all todo states', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Pending',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
          TodoItem(
            id: 'todo-2',
            content: 'In Progress',
            status: TodoState.inProgress,
            priority: 'high',
            order: 1,
            createdAt: 1234567891,
            updatedAt: 1234567891,
          ),
          TodoItem(
            id: 'todo-3',
            content: 'Completed',
            status: TodoState.completed,
            priority: 'low',
            order: 2,
            createdAt: 1234567892,
            updatedAt: 1234567892,
          ),
          TodoItem(
            id: 'todo-4',
            content: 'Canceled',
            status: TodoState.canceled,
            priority: 'low',
            order: 3,
            createdAt: 1234567893,
            updatedAt: 1234567893,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);

      final state = container.read(todoStateNotifierProvider);
      expect(state.totalCount, 4);
      expect(state.completedCount, 1);
    });

    test('should handle todo priorities', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Low priority',
            status: TodoState.pending,
            priority: 'low',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
          TodoItem(
            id: 'todo-2',
            content: 'Medium priority',
            status: TodoState.pending,
            priority: 'medium',
            order: 1,
            createdAt: 1234567891,
            updatedAt: 1234567891,
          ),
          TodoItem(
            id: 'todo-3',
            content: 'High priority',
            status: TodoState.pending,
            priority: 'high',
            order: 2,
            createdAt: 1234567892,
            updatedAt: 1234567892,
          ),
          TodoItem(
            id: 'todo-4',
            content: 'Critical priority',
            status: TodoState.pending,
            priority: 'critical',
            order: 3,
            createdAt: 1234567893,
            updatedAt: 1234567893,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);

      final state = container.read(todoStateNotifierProvider);
      expect(state.totalCount, 4);
    });

    test('should handle nested todos with parent-child relationships', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'parent-1',
            content: 'Parent todo',
            status: TodoState.inProgress,
            priority: 'high',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
          TodoItem(
            id: 'child-1',
            content: 'Child todo 1',
            status: TodoState.pending,
            priority: 'medium',
            order: 0,
            parentId: 'parent-1',
            createdAt: 1234567891,
            updatedAt: 1234567891,
          ),
          TodoItem(
            id: 'child-2',
            content: 'Child todo 2',
            status: TodoState.completed,
            priority: 'medium',
            order: 1,
            parentId: 'parent-1',
            createdAt: 1234567892,
            updatedAt: 1234567892,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);

      final state = container.read(todoStateNotifierProvider);
      final todoList = state.lists['session-1'];
      expect(todoList?.rootItems, hasLength(1));
      expect(todoList?.getSubtasks('parent-1'), hasLength(2));
    });

    test('should handle global todo list', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final globalList = TodoList(
        sessionId: null, // Global list
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Global todo',
            status: TodoState.pending,
            priority: 'high',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(globalList);

      final state = container.read(todoStateNotifierProvider);
      expect(state.getGlobalList()?.items.first.id, 'todo-1');
    });

    test('should handle todo dependencies', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Prerequisite',
            status: TodoState.completed,
            priority: 'high',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
          TodoItem(
            id: 'todo-2',
            content: 'Dependent',
            status: TodoState.pending,
            priority: 'medium',
            order: 1,
            dependencies: ['todo-1'],
            createdAt: 1234567891,
            updatedAt: 1234567891,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);

      final state = container.read(todoStateNotifierProvider);
      final dependentTodo = state.lists['session-1']?.items
        .firstWhere((todo) => todo.id == 'todo-2');
      expect(dependentTodo?.dependencies, contains('todo-1'));
    });

    test('should handle todos with due dates', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Todo with due date',
            status: TodoState.pending,
            priority: 'high',
            order: 0,
            dueAt: 1234567890,
            createdAt: 1234560000,
            updatedAt: 1234567890,
          ),
        ],
        updatedAt: 1234567890,
      );

      notifier.setTodoList(list);

      final state = container.read(todoStateNotifierProvider);
      final todo = state.lists['session-1']?.items.first;
      expect(todo?.dueAt, 1234567890);
    });

    test('should count all todos across all sessions', () {
      final notifier = container.read(todoStateNotifierProvider.notifier);

      final list1 = TodoList(
        sessionId: 'session-1',
        items: [
          TodoItem(
            id: 'todo-1',
            content: 'Session 1 todo 1',
            status: TodoState.completed,
            priority: 'medium',
            order: 0,
            createdAt: 1234567890,
            updatedAt: 1234567890,
          ),
          TodoItem(
            id: 'todo-2',
            content: 'Session 1 todo 2',
            status: TodoState.pending,
            priority: 'medium',
            order: 1,
            createdAt: 1234567891,
            updatedAt: 1234567891,
          ),
        ],
        updatedAt: 1234567890,
      );

      final list2 = TodoList(
        sessionId: 'session-2',
        items: [
          TodoItem(
            id: 'todo-3',
            content: 'Session 2 todo',
            status: TodoState.completed,
            priority: 'high',
            order: 0,
            createdAt: 1234567892,
            updatedAt: 1234567892,
          ),
        ],
        updatedAt: 1234567892,
      );

      notifier.setTodoList(list1);
      notifier.setTodoList(list2);

      final state = container.read(todoStateNotifierProvider);
      expect(state.totalCount, 3);
      expect(state.completedCount, 2);
    });
  });
}
