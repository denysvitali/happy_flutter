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
  });
}
