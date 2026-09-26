import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/todo.dart';

void main() {
  group('TodoItem', () {
    test('serializes and deserializes description', () {
      final item = TodoItem(
        id: 't1',
        content: 'Title',
        status: TodoState.pending,
        priority: 'medium',
        order: 0,
        description: 'A longer explanation of the task.',
        createdAt: 1000,
        updatedAt: 2000,
      );

      final json = item.toJson();
      expect(json['description'], 'A longer explanation of the task.');

      final restored = TodoItem.fromJson(json);
      expect(restored.description, 'A longer explanation of the task.');
    });

    test('description defaults to null when omitted from json', () {
      final item = TodoItem.fromJson({
        'id': 't1',
        'content': 'Title',
        'status': 'pending',
        'priority': 'low',
        'order': 0,
        'createdAt': 1000,
        'updatedAt': 2000,
      });

      expect(item.description, isNull);
    });

    test('copyWith preserves description by default', () {
      final item = TodoItem(
        id: 't1',
        content: 'Title',
        status: TodoState.pending,
        priority: 'medium',
        order: 0,
        description: 'Desc',
        createdAt: 1000,
        updatedAt: 2000,
      );

      final updated = item.copyWith(status: TodoState.completed);
      expect(updated.description, 'Desc');
    });

    test('copyWith can update description', () {
      final item = TodoItem(
        id: 't1',
        content: 'Title',
        status: TodoState.pending,
        priority: 'medium',
        order: 0,
        description: 'Old',
        createdAt: 1000,
        updatedAt: 2000,
      );

      final updated = item.copyWith(description: 'New');
      expect(updated.description, 'New');
    });

    test('copyWith clearDescription removes description', () {
      final item = TodoItem(
        id: 't1',
        content: 'Title',
        status: TodoState.pending,
        priority: 'medium',
        order: 0,
        description: 'Old',
        createdAt: 1000,
        updatedAt: 2000,
      );

      final updated = item.copyWith(clearDescription: true);
      expect(updated.description, isNull);
    });

    test('listFromJson reads Happy MCP metadata.todos', () {
      final items = TodoItem.listFromJson([
        {
          'id': '1',
          'content': 'Ship MCP',
          'status': 'in_progress',
          'priority': 'high',
          'order': 0,
          'createdAt': 1000,
          'updatedAt': 2000,
        },
        {'id': '', 'content': 'skip'},
      ]);
      expect(items, hasLength(1));
      expect(items!.first.id, '1');
      expect(items.first.status, TodoState.inProgress);
      expect(items.first.priority, 'high');
    });

    test('listFromJsonForSession drops foreign session rows', () {
      final items = TodoItem.listFromJsonForSession([
        {
          'id': '1',
          'content': 'mine',
          'status': 'pending',
          'priority': 'medium',
          'order': 0,
          'createdAt': 1,
          'updatedAt': 1,
          'sessionId': 'sess-a',
        },
        {
          'id': '2',
          'content': 'theirs',
          'status': 'pending',
          'priority': 'medium',
          'order': 0,
          'createdAt': 1,
          'updatedAt': 1,
          'sessionId': 'sess-b',
        },
        {
          'id': '3',
          'content': 'legacy',
          'status': 'pending',
          'priority': 'medium',
          'order': 0,
          'createdAt': 1,
          'updatedAt': 1,
        },
      ], 'sess-a');
      expect(items, hasLength(1));
      expect(items!.first.content, 'mine');
    });

    test('listFromJsonForSession keeps a fully unstamped legacy blob', () {
      final items = TodoItem.listFromJsonForSession([
        {
          'id': '1',
          'content': 'legacy',
          'status': 'pending',
          'priority': 'medium',
          'order': 0,
          'createdAt': 1,
          'updatedAt': 1,
        },
      ], 'sess-a');
      expect(items, hasLength(1));
      expect(items!.first.content, 'legacy');
    });

    test('parent and agent survive metadata and copyWith roundtrips', () {
      final item = TodoItem.fromJson({
        'id': '2',
        'content': 'Implement child',
        'status': 'pending',
        'parentId': '1',
        'agentId': 'agent-a',
      });
      expect(item.parentId, '1');
      expect(item.agentId, 'agent-a');
      expect(item.toJson()['parentId'], '1');
      expect(item.toJson()['agentId'], 'agent-a');
      expect(item.copyWith(status: TodoState.completed).agentId, 'agent-a');
      expect(item.copyWith(clearAgentId: true).agentId, isNull);
    });

    test('hierarchy order and effective agent follow parent chain', () {
      TodoItem item(String id, int order, {String? parent, String? agent}) =>
          TodoItem(
            id: id,
            content: id,
            status: TodoState.pending,
            priority: 'medium',
            order: order,
            parentId: parent,
            agentId: agent,
            createdAt: 1,
            updatedAt: 1,
          );
      final root = item('root', 0, agent: 'agent-a');
      final other = item('other', 1);
      final child = item('child', 2, parent: 'root');
      final grandchild = item('grandchild', 3, parent: 'child');
      final items = [grandchild, other, child, root];
      expect(TodoItem.hierarchyOrder(items).map((i) => i.id), [
        'root',
        'child',
        'grandchild',
        'other',
      ]);
      expect(TodoItem.depthIn(grandchild, items), 2);
      expect(TodoItem.effectiveAgentId(grandchild, items), 'agent-a');
    });

    test('completed items expire on add while live child keeps parent', () {
      TodoItem item(String id, TodoState status, {String? parent}) => TodoItem(
        id: id,
        content: id,
        status: status,
        priority: 'medium',
        order: 0,
        parentId: parent,
        createdAt: 1,
        updatedAt: 1,
      );
      final parent = item('parent', TodoState.completed);
      final child = item('child', TodoState.pending, parent: 'parent');
      final done = item('done', TodoState.completed);
      final next = item('next', TodoState.pending);
      final visible = TodoItem.expireCompletedOnAdd(
        [parent, child, done],
        [parent, child, done, next],
      );
      expect(visible.map((i) => i.id), ['parent', 'child', 'next']);
      expect(TodoItem.expireCompletedOnAdd([done], [done]), hasLength(1));
    });
  });
}
