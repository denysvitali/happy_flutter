import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/todo.dart';

void main() {
  group('TodoState', () {
    group('fromString', () {
      test('parses pending', () {
        expect(TodoState.fromString('pending'), TodoState.pending);
      });

      test('parses inProgress', () {
        expect(TodoState.fromString('inProgress'), TodoState.inProgress);
      });

      test('parses completed', () {
        expect(TodoState.fromString('completed'), TodoState.completed);
      });

      test('parses canceled', () {
        expect(TodoState.fromString('canceled'), TodoState.canceled);
      });

      test('falls back to pending for unknown', () {
        expect(TodoState.fromString('unknown'), TodoState.pending);
        expect(TodoState.fromString(''), TodoState.pending);
      });
    });

    group('value', () {
      test('returns correct string', () {
        expect(TodoState.pending.value, 'pending');
        expect(TodoState.inProgress.value, 'inProgress');
        expect(TodoState.completed.value, 'completed');
        expect(TodoState.canceled.value, 'canceled');
      });
    });

    group('displayName', () {
      test('returns human-readable name', () {
        expect(TodoState.pending.displayName, 'Pending');
        expect(TodoState.inProgress.displayName, 'In Progress');
        expect(TodoState.completed.displayName, 'Completed');
        expect(TodoState.canceled.displayName, 'Canceled');
      });
    });

    group('isTerminal', () {
      test('completed is terminal', () {
        expect(TodoState.completed.isTerminal, isTrue);
      });

      test('canceled is terminal', () {
        expect(TodoState.canceled.isTerminal, isTrue);
      });

      test('pending is not terminal', () {
        expect(TodoState.pending.isTerminal, isFalse);
      });

      test('inProgress is not terminal', () {
        expect(TodoState.inProgress.isTerminal, isFalse);
      });
    });
  });

  group('TodoItem', () {
    group('fromJson', () {
      test('parses all required fields', () {
        final json = {
          'id': 'todo-1',
          'content': 'Fix the bug',
          'status': 'pending',
          'priority': 'high',
          'order': 1,
          'createdAt': 1700000000,
          'updatedAt': 1700000100,
        };

        final item = TodoItem.fromJson(json);

        expect(item.id, 'todo-1');
        expect(item.content, 'Fix the bug');
        expect(item.status, TodoState.pending);
        expect(item.priority, 'high');
        expect(item.order, 1);
        expect(item.createdAt, 1700000000);
        expect(item.updatedAt, 1700000100);
      });

      test('parses optional fields', () {
        final json = {
          'id': 'todo-2',
          'content': 'Subtask',
          'status': 'inProgress',
          'priority': 'medium',
          'order': 0,
          'parentId': 'todo-1',
          'dependencies': ['dep-1', 'dep-2'],
          'dueAt': 1700100000,
          'createdAt': 1700000000,
          'updatedAt': 1700000200,
          'sessionId': 'sess-1',
          'completedAt': 1700050000,
        };

        final item = TodoItem.fromJson(json);

        expect(item.parentId, 'todo-1');
        expect(item.dependencies, ['dep-1', 'dep-2']);
        expect(item.dueAt, 1700100000);
        expect(item.sessionId, 'sess-1');
        expect(item.completedAt, 1700050000);
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'todo-3',
          'content': 'Simple task',
          'status': 'completed',
          'priority': 'low',
          'order': 0,
          'createdAt': 1700000000,
          'updatedAt': 1700000300,
        };

        final item = TodoItem.fromJson(json);

        expect(item.parentId, isNull);
        expect(item.dependencies, isEmpty);
        expect(item.dueAt, isNull);
        expect(item.sessionId, isNull);
        expect(item.completedAt, isNull);
      });

      test('parses all status variants', () {
        for (final entry in [
          ('pending', TodoState.pending),
          ('inProgress', TodoState.inProgress),
          ('completed', TodoState.completed),
          ('canceled', TodoState.canceled),
        ]) {
          final json = {
            'id': 't',
            'content': '',
            'status': entry.$1,
            'priority': 'low',
            'order': 0,
            'createdAt': 0,
            'updatedAt': 0,
          };
          expect(TodoItem.fromJson(json).status, entry.$2);
        }
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final item = TodoItem(
          id: 'todo-1',
          content: 'Test',
          status: TodoState.inProgress,
          priority: 'high',
          order: 5,
          parentId: 'parent-1',
          dependencies: ['dep-a'],
          dueAt: 1700100000,
          createdAt: 1700000000,
          updatedAt: 1700000100,
          sessionId: 'sess-1',
          completedAt: null,
        );

        final json = item.toJson();

        expect(json['id'], 'todo-1');
        expect(json['content'], 'Test');
        expect(json['status'], 'inProgress');
        expect(json['priority'], 'high');
        expect(json['order'], 5);
        expect(json['parentId'], 'parent-1');
        expect(json['dependencies'], ['dep-a']);
        expect(json['dueAt'], 1700100000);
        expect(json['createdAt'], 1700000000);
        expect(json['updatedAt'], 1700000100);
        expect(json['sessionId'], 'sess-1');
        expect(json['completedAt'], isNull);
      });

      test('round-trip preserves data', () {
        final original = TodoItem(
          id: 'todo-rt',
          content: 'Round trip',
          status: TodoState.canceled,
          priority: 'critical',
          order: 3,
          createdAt: 1700000000,
          updatedAt: 1700000500,
        );

        final restored = TodoItem.fromJson(original.toJson());

        expect(restored.id, original.id);
        expect(restored.content, original.content);
        expect(restored.status, original.status);
        expect(restored.priority, original.priority);
        expect(restored.order, original.order);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
      });
    });

    group('copyWith', () {
      late TodoItem base;

      setUp(() {
        base = TodoItem(
          id: 'todo-1',
          content: 'Original',
          status: TodoState.pending,
          priority: 'low',
          order: 0,
          createdAt: 1700000000,
          updatedAt: 1700000100,
        );
      });

      test('copies with updated content', () {
        final updated = base.copyWith(content: 'Updated');
        expect(updated.content, 'Updated');
        expect(updated.id, 'todo-1');
        expect(updated.status, TodoState.pending);
      });

      test('copies with updated status', () {
        final updated = base.copyWith(status: TodoState.completed);
        expect(updated.status, TodoState.completed);
        expect(updated.content, 'Original');
      });

      test('copies with updated parentId', () {
        final updated = base.copyWith(parentId: 'parent-1');
        expect(updated.parentId, 'parent-1');
      });

      test('clearParentId sets parentId to null', () {
        final withParent =
            base.copyWith(parentId: 'parent-1');
        final cleared = withParent.copyWith(clearParentId: true);
        expect(cleared.parentId, isNull);
      });

      test('copies dependencies by value', () {
        final deps = ['dep-1'];
        final updated = base.copyWith(dependencies: deps);
        deps.add('dep-2');
        expect(updated.dependencies, ['dep-1']);
      });

      test('preserves all fields when no changes', () {
        final copy = base.copyWith();
        expect(copy.id, base.id);
        expect(copy.content, base.content);
        expect(copy.status, base.status);
        expect(copy.priority, base.priority);
        expect(copy.order, base.order);
        expect(copy.createdAt, base.createdAt);
        expect(copy.updatedAt, base.updatedAt);
      });
    });
  });

  group('TodoList', () {
    group('fromJson', () {
      test('parses with sessionId and items', () {
        final json = {
          'sessionId': 'sess-1',
          'items': [
            {
              'id': 't1',
              'content': 'Task 1',
              'status': 'pending',
              'priority': 'high',
              'order': 0,
              'createdAt': 0,
              'updatedAt': 0,
            },
          ],
          'updatedAt': 1700000000,
        };

        final list = TodoList.fromJson(json);

        expect(list.sessionId, 'sess-1');
        expect(list.items.length, 1);
        expect(list.items.first.content, 'Task 1');
        expect(list.updatedAt, 1700000000);
      });

      test('handles missing items as empty', () {
        final json = {
          'updatedAt': 1700000000,
        };

        final list = TodoList.fromJson(json);
        expect(list.items, isEmpty);
        expect(list.sessionId, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final list = TodoList(
          sessionId: 'sess-1',
          items: [
            TodoItem(
              id: 't1',
              content: 'Task',
              status: TodoState.pending,
              priority: 'low',
              order: 0,
              createdAt: 0,
              updatedAt: 0,
            ),
          ],
          updatedAt: 1700000000,
        );

        final json = list.toJson();
        expect(json['sessionId'], 'sess-1');
        expect(json['updatedAt'], 1700000000);
        expect(json['items'], isA<List>());
        expect((json['items'] as List).length, 1);
      });
    });

    group('sortedItems', () {
      test('returns items sorted by order', () {
        final list = TodoList(
          items: [
            _makeItem('a', 2),
            _makeItem('b', 0),
            _makeItem('c', 1),
          ],
          updatedAt: 0,
        );

        final sorted = list.sortedItems;
        expect(sorted.map((e) => e.id), ['b', 'c', 'a']);
      });
    });

    group('status filters', () {
      late TodoList list;

      setUp(() {
        list = TodoList(
          items: [
            _makeItem('pending-1', 0, TodoState.pending),
            _makeItem('progress-1', 1, TodoState.inProgress),
            _makeItem('completed-1', 2, TodoState.completed),
            _makeItem('pending-2', 3, TodoState.pending),
          ],
          updatedAt: 0,
        );
      });

      test('pendingItems returns only pending', () {
        final items = list.pendingItems;
        expect(items.length, 2);
        expect(items.every((e) => e.status == TodoState.pending), isTrue);
      });

      test('inProgressItems returns only in-progress', () {
        final items = list.inProgressItems;
        expect(items.length, 1);
        expect(items.first.id, 'progress-1');
      });

      test('completedItems returns only completed', () {
        final items = list.completedItems;
        expect(items.length, 1);
        expect(items.first.id, 'completed-1');
      });
    });

    group('rootItems and subtasks', () {
      late TodoList list;

      setUp(() {
        list = TodoList(
          items: [
            TodoItem(
              id: 'root-1',
              content: '',
              status: TodoState.pending,
              priority: 'low',
              order: 0,
              createdAt: 0,
              updatedAt: 0,
            ),
            TodoItem(
              id: 'child-1',
              content: '',
              status: TodoState.pending,
              priority: 'low',
              order: 1,
              parentId: 'root-1',
              createdAt: 0,
              updatedAt: 0,
            ),
            TodoItem(
              id: 'root-2',
              content: '',
              status: TodoState.pending,
              priority: 'low',
              order: 2,
              createdAt: 0,
              updatedAt: 0,
            ),
          ],
          updatedAt: 0,
        );
      });

      test('rootItems returns items without parentId', () {
        final roots = list.rootItems;
        expect(roots.length, 2);
        expect(roots.map((e) => e.id), containsAll(['root-1', 'root-2']));
      });

      test('getSubtasks returns children of given parent', () {
        final children = list.getSubtasks('root-1');
        expect(children.length, 1);
        expect(children.first.id, 'child-1');
      });

      test('getSubtasks returns empty for unknown parent', () {
        expect(list.getSubtasks('unknown'), isEmpty);
      });
    });

    group('copyWith', () {
      test('copies with updated items', () {
        final original = TodoList(items: [], updatedAt: 0);
        final newItem = _makeItem('new', 0);
        final updated =
            original.copyWith(items: [newItem]);

        expect(updated.items.length, 1);
        expect(updated.items.first.id, 'new');
      });

      test('copies with updated sessionId', () {
        final original = TodoList(items: [], updatedAt: 0);
        final updated =
            original.copyWith(sessionId: 'new-sess');
        expect(updated.sessionId, 'new-sess');
      });
    });
  });

  group('TodoReorder', () {
    test('toJson serializes fields', () {
      final reorder = TodoReorder(
        todoId: 'todo-1',
        newOrder: 5,
        newParentId: 'parent-1',
      );

      final json = reorder.toJson();
      expect(json['todoId'], 'todo-1');
      expect(json['newOrder'], 5);
      expect(json['newParentId'], 'parent-1');
    });

    test('toJson handles null newParentId', () {
      final reorder = TodoReorder(
        todoId: 'todo-2',
        newOrder: 0,
      );

      final json = reorder.toJson();
      expect(json['newParentId'], isNull);
    });
  });
}

TodoItem _makeItem(String id, int order,
    [TodoState status = TodoState.pending]) {
  return TodoItem(
    id: id,
    content: '',
    status: status,
    priority: 'low',
    order: order,
    createdAt: 0,
    updatedAt: 0,
  );
}
