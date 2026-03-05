import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
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
    });

    test('update-account invalidates profile and settings sync', () async {
      instance.handleUpdate({'t': 'update-account'});

      await instance.profileSync.awaitQueue();
      await instance.settingsSync.awaitQueue();

      expect(profileInvalidations, 1);
      expect(settingsInvalidations, 1);
    });

    test('accepts single-element list payloads for update events', () async {
      instance.handleUpdate([
        {'t': 'update-account'},
      ]);

      await instance.profileSync.awaitQueue();
      await instance.settingsSync.awaitQueue();

      expect(profileInvalidations, 1);
      expect(settingsInvalidations, 1);
    });

    test(
      'kv-batch-update invalidates todo sync when todo payload is present',
      () async {
        instance.handleUpdate({
          't': 'kv-batch-update',
          'operations': [
            {'key': 'todo:list:session_1', 'value': []},
          ],
        });

        await instance.todosSync.awaitQueue();

        expect(todosInvalidations, 1);
      },
    );

    test(
      'kv-batch-update invalidates todo sync when todo key is in changes',
      () async {
        instance.handleUpdate({
          't': 'kv-batch-update',
          'changes': [
            {'key': 'todo.abc', 'value': 'encrypted'},
          ],
        });

        await instance.todosSync.awaitQueue();

        expect(todosInvalidations, 1);
      },
    );

    test(
      'delete-session clears in-memory message state for that session',
      () async {
        instance.messagesSync['session_1'] = InvalidateSync(() async {});

        instance.handleUpdate({'t': 'delete-session', 'sid': 'session_1'});

        await instance.sessionsSync.awaitQueue();

        expect(instance.messagesSync.containsKey('session_1'), false);
        expect(sessionsInvalidations, 1);
      },
    );

    test(
      'new-message invalidates messages sync when only id is present',
      () async {
        var messageInvalidations = 0;
        instance.messagesSync['session_1'] = InvalidateSync(() async {
          messageInvalidations++;
        });

        instance.handleUpdate({'t': 'new-message', 'id': 'session_1'});

        await instance.messagesSync['session_1']?.awaitQueue();
        expect(messageInvalidations, 1);
      },
    );

    test('update-session bursts are debounced into one sessions refresh',
        () async {
      instance.handleUpdate({'t': 'update-session', 'id': 'session_1'});
      instance.handleUpdate({'t': 'update-session', 'id': 'session_1'});
      instance.handleUpdate({'t': 'update-session', 'id': 'session_1'});

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await instance.sessionsSync.awaitQueue();

      expect(sessionsInvalidations, 1);
    });
  });

  group('Sync.handleEphemeralUpdate', () {
    test('accepts single-element list payloads', () {
      final instance = Sync();
      expect(
        () => instance.handleEphemeralUpdate([
          {'type': 'usage', 'id': 'session_1'},
        ]),
        returnsNormally,
      );
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

  group('Sync mapping helpers', () {
    test('maps friend profile shape from React Native API', () {
      final instance = Sync();
      final profile = instance.mapFriendProfile({
        'id': 'user_1',
        'firstName': 'Ada',
        'lastName': 'Lovelace',
        'username': 'ada',
        'status': 'requested',
        'avatar': {'url': 'https://example.com/avatar.png'},
      });

      expect(profile.id, 'user_1');
      expect(profile.name, 'Ada Lovelace');
      expect(profile.avatarUrl, 'https://example.com/avatar.png');
      expect(profile.status.name, 'requested');
    });

    test('maps feed item body variants', () {
      final instance = Sync();
      final feedItem = instance.mapFeedItem({
        'id': 'feed_1',
        'createdAt': 123,
        'body': {'kind': 'friend_request', 'uid': 'user_2'},
      });

      expect(feedItem.id, 'feed_1');
      expect(feedItem.userId, 'user_2');
      expect(feedItem.body.kind, 'friend_request');
    });
  });

  group('SessionEncryption', () {
    test('decryptMessages accepts numeric createdAt timestamps', () async {
      final encryption = SessionEncryption(
        sessionId: 'session_1',
        encryptor: _FakeEncryptorDecryptor(),
        decryptor: _FakeEncryptorDecryptor(),
        cache: EncryptionCache(),
      );

      final decrypted = await encryption.decryptMessages([
        {
          'id': 'msg_1',
          'seq': 1,
          'localId': null,
          'content': {'t': 'encrypted', 'c': ''},
          'createdAt': 1234567890,
        },
      ]);

      expect(decrypted, hasLength(1));
      expect(decrypted.first?.createdAt.millisecondsSinceEpoch, 1234567890);
    });

    test(
      'decryptMessages invalidates cache when same id gets new ciphertext',
      () async {
        final encryption = SessionEncryption(
          sessionId: 'session_1',
          encryptor: _ContentAwareEncryptorDecryptor(),
          decryptor: _ContentAwareEncryptorDecryptor(),
          cache: EncryptionCache(),
        );

        final first = await encryption.decryptMessages([
          {
            'id': 'msg_1',
            'seq': 1,
            'localId': null,
            'content': {
              't': 'encrypted',
              'c': base64Encode([1]),
            },
            'createdAt': 1234567890,
          },
        ]);
        final second = await encryption.decryptMessages([
          {
            'id': 'msg_1',
            'seq': 1,
            'localId': null,
            'content': {
              't': 'encrypted',
              'c': base64Encode([2]),
            },
            'createdAt': 1234567890,
          },
        ]);

        expect(first.first?.content['content']['text'] as String?, 'payload-1');
        expect(
          second.first?.content['content']['text'] as String?,
          'payload-2',
        );
      },
    );
  });

  group('Sync.applySettings', () {
    test('merges into snapshot and pending settings', () async {
      final instance = Sync();
      instance.settingsSync = InvalidateSync(() async {});

      await instance.applySettings({'themeMode': 'dark', 'viewInline': true});

      expect(instance.settingsSnapshot.themeMode, 'dark');
      expect(instance.settingsSnapshot.viewInline, true);
      expect(instance.pendingSettings['themeMode'], 'dark');
      expect(instance.pendingSettings['viewInline'], true);
    });
  });

  group('Sync.waitForAgentReady', () {
    test(
      'returns false when session is not available before timeout',
      () async {
        final instance = Sync();
        final ready = await instance.waitForAgentReady('missing', 10);
        expect(ready, false);
      },
    );

    test(
      'does not return true for stale agentStateVersion when offline',
      () async {
        final instance = Sync();
        instance.testSessions['s1'] = Session(
          id: 's1',
          seq: 1,
          createdAt: 0,
          updatedAt: 0,
          active: true,
          activeAt: 0,
          metadataVersion: 0,
          agentStateVersion: 5, // stale from previous daemon run
          thinking: false,
          presence: 'offline',
        );
        final ready = await instance.waitForAgentReady('s1', 50);
        expect(ready, false);
      },
    );

    test(
      'returns true when session presence is online',
      () async {
        final instance = Sync();
        instance.testSessions['s1'] = Session(
          id: 's1',
          seq: 1,
          createdAt: 0,
          updatedAt: 0,
          active: true,
          activeAt: 0,
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'online',
        );
        final ready = await instance.waitForAgentReady('s1', 50);
        expect(ready, true);
      },
    );

    test(
      'returns true when session comes online during wait',
      () async {
        final instance = Sync();
        instance.testSessions['s1'] = Session(
          id: 's1',
          seq: 1,
          createdAt: 0,
          updatedAt: 0,
          active: true,
          activeAt: 0,
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
        );
        // Simulate daemon coming online after a short delay.
        Future<void>.delayed(
          const Duration(milliseconds: 100),
          () {
            instance.testSessions['s1'] =
                instance.testSessions['s1']!.copyWith(
              presence: 'online',
            );
            instance.testNotifyDataChanged();
          },
        );
        final ready = await instance.waitForAgentReady('s1', 2000);
        expect(ready, true);
      },
    );
  });
}

class _FakeEncryptorDecryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data
        .map((_) => Uint8List.fromList(<int>[0]))
        .toList(growable: false);
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    return data
        .map(
          (_) => <String, dynamic>{
            'role': 'user',
            'content': <String, dynamic>{'type': 'text', 'text': 'hello'},
          },
        )
        .toList(growable: false);
  }
}

class _ContentAwareEncryptorDecryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data
        .map((_) => Uint8List.fromList(<int>[0]))
        .toList(growable: false);
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    return data
        .map((bytes) {
          final marker = bytes.isEmpty ? 0 : bytes.first;
          return <String, dynamic>{
            'role': 'user',
            'content': <String, dynamic>{
              'type': 'text',
              'text': 'payload-$marker',
            },
          };
        })
        .toList(growable: false);
  }
}
