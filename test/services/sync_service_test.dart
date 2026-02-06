import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

void main() {
  group('Sync.handleUpdate', () {
    late Sync instance;
    late int sessionsInvalidations;
    late int settingsInvalidations;
    late int profileInvalidations;
    late int todosInvalidations;

    setUp(() {
      instance = Sync();
      sessionsInvalidations = 0;
      settingsInvalidations = 0;
      profileInvalidations = 0;
      todosInvalidations = 0;

      instance.sessionsSync = InvalidateSync(() async {
        sessionsInvalidations++;
      });
      instance.settingsSync = InvalidateSync(() async {
        settingsInvalidations++;
      });
      instance.profileSync = InvalidateSync(() async {
        profileInvalidations++;
      });
      instance.purchasesSync = InvalidateSync(() async {});
      instance.machinesSync = InvalidateSync(() async {});
      instance.pushTokenSync = InvalidateSync(() async {});
      instance.nativeUpdateSync = InvalidateSync(() async {});
      instance.artifactsSync = InvalidateSync(() async {});
      instance.friendsSync = InvalidateSync(() async {});
      instance.friendRequestsSync = InvalidateSync(() async {});
      instance.feedSync = InvalidateSync(() async {});
      instance.todosSync = InvalidateSync(() async {
        todosInvalidations++;
      });
      instance.messagesSync.clear();
      instance.sessionReceivedMessages.clear();
    });

    test('update-account invalidates profile and settings sync', () async {
      instance.handleUpdate({'t': 'update-account'});

      await instance.profileSync.awaitQueue();
      await instance.settingsSync.awaitQueue();

      expect(profileInvalidations, 1);
      expect(settingsInvalidations, 1);
    });

    test('kv-batch-update invalidates todo sync when todo payload is present',
        () async {
      instance.handleUpdate({
        't': 'kv-batch-update',
        'operations': [
          {'key': 'todo:list:session_1', 'value': []},
        ],
      });

      await instance.todosSync.awaitQueue();

      expect(todosInvalidations, 1);
    });

    test('kv-batch-update invalidates todo sync when todo key is in changes',
        () async {
      instance.handleUpdate({
        't': 'kv-batch-update',
        'changes': [
          {'key': 'todo.abc', 'value': 'encrypted'},
        ],
      });

      await instance.todosSync.awaitQueue();

      expect(todosInvalidations, 1);
    });

    test('delete-session clears in-memory message state for that session',
        () async {
      instance.messagesSync['session_1'] = InvalidateSync(() async {});
      instance.sessionReceivedMessages['session_1'] = {'message_1'};

      instance.handleUpdate({'t': 'delete-session', 'sid': 'session_1'});

      await instance.sessionsSync.awaitQueue();

      expect(instance.messagesSync.containsKey('session_1'), false);
      expect(instance.sessionReceivedMessages.containsKey('session_1'), false);
      expect(sessionsInvalidations, 1);
    });
  });

  group('Sync.parseTodoListsFromDecryptedKv', () {
    test('parses RN todo format and maps to global and session lists', () {
      final instance = Sync();

      final parsed = instance.parseTodoListsFromDecryptedKv({
        'todo.index': {
          'undoneOrder': ['todo_1'],
          'completedOrder': ['todo_2'],
        },
        'todo.todo_1': {
          'id': 'todo_1',
          'title': 'First',
          'done': false,
          'createdAt': 1,
          'updatedAt': 2,
        },
        'todo.todo_2': {
          'id': 'todo_2',
          'content': 'Second',
          'status': 'completed',
          'priority': 'high',
          'createdAt': 1,
          'updatedAt': 2,
          'sessionId': 'session_1',
        },
        'todo.todo_3': {
          'title': 'Third',
          'done': true,
          'createdAt': 1,
          'updatedAt': 2,
          'linkedSessions': {
            'session_2': {'title': 'Linked', 'linkedAt': 1},
          },
        },
      });

      expect(parsed.containsKey(null), true);
      expect(parsed.containsKey('session_1'), true);
      expect(parsed.containsKey('session_2'), true);

      final globalItems = parsed[null]!.items;
      expect(globalItems.length, 3);
      expect(globalItems.map((item) => item.id).toList(), [
        'todo_1',
        'todo_2',
        'todo_3',
      ]);
      expect(globalItems.first.content, 'First');
      expect(globalItems[1].status.name, 'completed');

      expect(parsed['session_1']!.items.single.id, 'todo_2');
      expect(parsed['session_2']!.items.single.id, 'todo_3');
    });
  });
}
