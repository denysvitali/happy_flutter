import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';

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

    test('update-session accepts sid payloads', () async {
      instance.testSessions['session_1'] = Session(
        id: 'session_1',
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

      instance.handleUpdate({
        't': 'update-session',
        'sid': 'session_1',
        'presence': 'online',
        'thinking': true,
      });

      await instance.sessionsSync.awaitQueue();

      final session = instance.testSessions['session_1']!;
      expect(session.presence, 'online');
      expect(session.thinking, true);
    });

    test(
      'new-message marks non-visible session dirty when only id is present',
      () {
        instance.handleUpdate({'t': 'new-message', 'id': 'session_1'});

        expect(instance.testSessionsWithPendingUpdates, contains('session_1'));
      },
    );

    test('new-message invalidates messages sync for visible session '
        'when only id is present', () async {
      var messageInvalidations = 0;
      instance.testVisibleSessionId = 'session_1';
      instance.messagesSync['session_1'] = InvalidateSync(() async {
        messageInvalidations++;
      });

      instance.handleUpdate({'t': 'new-message', 'id': 'session_1'});

      await instance.messagesSync['session_1']?.awaitQueue();
      expect(messageInvalidations, 1);
    });

    test('new-message with only id marks visible session for fetch probe', () {
      instance.testVisibleSessionId = 'session_1';
      instance.messagesSync['session_1'] = InvalidateSync(() async {});

      instance.handleUpdate({'t': 'new-message', 'id': 'session_1'});

      expect(instance.testHasFetchProbe('session_1'), isTrue);
    });

    test(
      'update-session bursts are debounced into one sessions refresh',
      () async {
        instance.handleUpdate({'t': 'update-session', 'id': 'session_1'});
        instance.handleUpdate({'t': 'update-session', 'id': 'session_1'});
        instance.handleUpdate({'t': 'update-session', 'id': 'session_1'});

        // _sessionsRefreshDebounce is 2s; wait long enough for it to fire.
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        await instance.sessionsSync.awaitQueue();

        expect(sessionsInvalidations, 1);
      },
    );

    test(
      'new-session bursts are debounced into one refresh when ready',
      () async {
        instance.encryption = _TestEncryption(
          sessions: {'session_1': _NoopSessionEncryption()},
        );

        instance.handleUpdate({'t': 'new-session', 'id': 'session_1'});
        instance.handleUpdate({'t': 'new-session', 'id': 'session_1'});
        instance.handleUpdate({'t': 'new-session', 'id': 'session_1'});

        await Future<void>.delayed(const Duration(milliseconds: 2500));
        await instance.sessionsSync.awaitQueue();

        expect(sessionsInvalidations, 1);
        expect(instance.testForceFullFetchNext, false);
      },
    );

    test(
      'new-session triggers one recovery full fetch when encryption missing',
      () async {
        instance.encryption = _TestEncryption();

        instance.handleUpdate({'t': 'new-session', 'id': 'session_1'});

        await Future<void>.delayed(const Duration(milliseconds: 2500));
        await instance.sessionsSync.awaitQueue();

        expect(sessionsInvalidations, 2);
        expect(instance.testForceFullFetchNext, true);
      },
    );

    test(
      'new-session burst triggers only one recovery full fetch when missing',
      () async {
        instance.encryption = _TestEncryption();

        instance.handleUpdate({'t': 'new-session', 'id': 'session_1'});
        instance.handleUpdate({'t': 'new-session', 'id': 'session_1'});
        instance.handleUpdate({'t': 'new-session', 'id': 'session_1'});

        await Future<void>.delayed(const Duration(milliseconds: 2500));
        await instance.sessionsSync.awaitQueue();

        expect(sessionsInvalidations, 2);
      },
    );
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

    test('session-alive marks session online without clearing thinking', () {
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
        thinking: true,
        thinkingAt: 123,
        presence: 'offline',
      );

      instance.handleEphemeralUpdate({'type': 'session-alive', 'id': 's1'});

      final session = instance.testSessions['s1']!;
      expect(session.presence, 'online');
      expect(session.thinking, true);
      expect(session.thinkingAt, 123);
    });

    test('session-alive accepts t/sid payloads', () {
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

      instance.handleEphemeralUpdate({'t': 'session-alive', 'sid': 's1'});

      final session = instance.testSessions['s1']!;
      expect(session.presence, 'online');
    });

    test('machine-activity without activeAt synthesises activeAt=now '
        'so createSession 120s check stays fresh', () {
      final instance = Sync();
      final staleAt = DateTime.now().millisecondsSinceEpoch - 200000;
      instance.testMachines['m1'] = Machine(
        id: 'm1',
        seq: 1,
        createdAt: 0,
        updatedAt: 0,
        active: true,
        activeAt: staleAt, // 200 s ago — older than the 120 s threshold
        metadataVersion: 0,
        daemonStateVersion: 0,
      );

      final before = DateTime.now().millisecondsSinceEpoch;
      instance.handleEphemeralUpdate({
        'type': 'machine-activity',
        'id': 'm1',
        'active': true,
        // no activeAt field
      });
      final after = DateTime.now().millisecondsSinceEpoch;

      final machine = instance.testMachines['m1']!;
      expect(machine.active, isTrue);
      // activeAt must have been refreshed to ~now
      expect(machine.activeAt, greaterThanOrEqualTo(before));
      expect(machine.activeAt, lessThanOrEqualTo(after));
    });

    test('machine-activity with activeAt uses the provided value', () {
      final instance = Sync();
      final serverActiveAt = DateTime.now().millisecondsSinceEpoch - 5000;
      instance.testMachines['m1'] = Machine(
        id: 'm1',
        seq: 1,
        createdAt: 0,
        updatedAt: 0,
        active: false,
        activeAt: 0,
        metadataVersion: 0,
        daemonStateVersion: 0,
      );

      instance.handleEphemeralUpdate({
        'type': 'machine-activity',
        'id': 'm1',
        'active': true,
        'activeAt': serverActiveAt,
      });

      final machine = instance.testMachines['m1']!;
      expect(machine.active, isTrue);
      expect(machine.activeAt, serverActiveAt);
    });

    test('machine-activity with active=false does not synthesise activeAt', () {
      final instance = Sync();
      final originalActiveAt = DateTime.now().millisecondsSinceEpoch - 5000;
      instance.testMachines['m1'] = Machine(
        id: 'm1',
        seq: 1,
        createdAt: 0,
        updatedAt: 0,
        active: true,
        activeAt: originalActiveAt,
        metadataVersion: 0,
        daemonStateVersion: 0,
      );

      instance.handleEphemeralUpdate({
        'type': 'machine-activity',
        'id': 'm1',
        'active': false,
        // no activeAt
      });

      final machine = instance.testMachines['m1']!;
      expect(machine.active, isFalse);
      // activeAt unchanged — allows 120s window to expire naturally
      expect(machine.activeAt, originalActiveAt);
    });
  });

  group('Sync global invalidation', () {
    test(
      'coalesces duplicate full-sync invalidations within cooldown',
      () async {
        final instance = Sync();
        var sessionsInvalidations = 0;

        instance.sessionsSync = InvalidateSync(() async {
          sessionsInvalidations++;
        });
        instance.settingsSync = InvalidateSync(() async {});
        instance.profileSync = InvalidateSync(() async {});
        instance.purchasesSync = InvalidateSync(() async {});
        instance.machinesSync = InvalidateSync(() async {});
        instance.pushTokenSync = InvalidateSync(() async {});
        instance.nativeUpdateSync = InvalidateSync(() async {});
        instance.artifactsSync = InvalidateSync(() async {});
        instance.friendsSync = InvalidateSync(() async {});
        instance.friendRequestsSync = InvalidateSync(() async {});
        instance.feedSync = InvalidateSync(() async {});
        instance.todosSync = InvalidateSync(() async {});
        instance.sessionGitStatusSync = InvalidateSync(() async {});

        instance.testInvalidateAllSyncs(force: true);
        await instance.sessionsSync.awaitQueue();

        instance.testInvalidateAllSyncs();
        await instance.sessionsSync.awaitQueue();

        expect(sessionsInvalidations, 1);
      },
    );

    test('preserves sessions delta cursor during normal invalidation', () {
      final instance = Sync();
      instance.testLastSessionsFetchedAt = 123456;

      instance.testInvalidateAllSyncs(force: true);

      expect(instance.testLastSessionsFetchedAt, 123456);
    });

    test('can explicitly clear sessions delta cursor for recovery', () {
      final instance = Sync();
      instance.testLastSessionsFetchedAt = 123456;

      instance.testInvalidateAllSyncs(
        force: true,
        resetSessionDeltaCursor: true,
      );

      expect(instance.testLastSessionsFetchedAt, isNull);
    });

    test('defers non-critical syncs during phased invalidation', () async {
      final instance = Sync();
      instance.testIsInitialized = true; // Enable deferred sync timer
      var criticalInvalidations = 0;
      var deferredInvalidations = 0;

      // Track critical syncs (sessions)
      instance.sessionsSync = InvalidateSync(() async {
        criticalInvalidations++;
      });
      // Track deferred syncs that the timer actually invalidates
      instance.machinesSync = InvalidateSync(() async {
        deferredInvalidations++;
      });
      instance.settingsSync = InvalidateSync(() async {
        deferredInvalidations++;
      });
      instance.profileSync = InvalidateSync(() async {});
      instance.purchasesSync = InvalidateSync(() async {});
      instance.pushTokenSync = InvalidateSync(() async {});
      instance.nativeUpdateSync = InvalidateSync(() async {});

      // On-demand syncs (not invalidated by phased invalidation)
      instance.friendsSync = InvalidateSync(() async {});
      instance.feedSync = InvalidateSync(() async {});
      instance.todosSync = InvalidateSync(() async {});
      instance.artifactsSync = InvalidateSync(() async {});
      instance.friendRequestsSync = InvalidateSync(() async {});
      instance.sessionGitStatusSync = InvalidateSync(() async {});

      // Trigger invalidation
      instance.testInvalidateAllSyncs(force: true);

      // Critical syncs should invalidate immediately
      await instance.sessionsSync.awaitQueue();
      expect(
        criticalInvalidations,
        1,
        reason: 'Critical syncs should invalidate immediately',
      );

      // Deferred syncs should NOT have invalidated yet
      expect(
        deferredInvalidations,
        0,
        reason: 'Deferred syncs should not invalidate immediately',
      );

      // Wait for deferred syncs to be invalidated (after 3s delay)
      await Future.delayed(const Duration(milliseconds: 3100));
      await instance.machinesSync.awaitQueue();
      await instance.settingsSync.awaitQueue();

      expect(
        deferredInvalidations,
        2,
        reason: 'Deferred syncs should invalidate after delay',
      );
    });
  });

  group('Sync auto-restore priming', () {
    test(
      'primes redirected spawned session locally without forcing full fetch',
      () async {
        final instance = Sync();
        instance.testForceFullFetchNext = false;
        final seedSession = Session(
          id: 'old-session',
          seq: 1,
          createdAt: 1700000000000,
          updatedAt: 1700000000000,
          active: true,
          activeAt: 1700000000000,
          metadata: Metadata(
            host: 'test-host',
            machineId: 'machine-1',
            path: '/repo',
            flavor: 'claude',
          ),
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
          permissionMode: 'default',
          modelMode: 'default',
        );

        instance.testSessions['old-session'] = seedSession;

        await instance.testPrimeSessionFromSpawnResult(
          requestedSessionId: 'old-session',
          restoredSessionId: 'new-session',
          seedSession: seedSession,
          result: const SpawnSessionResponse(
            type: 'success',
            sessionId: 'new-session',
            directory: '/repo',
          ),
        );

        final restored = instance.sessions['new-session'];
        expect(restored, isNotNull);
        expect(restored?.metadata?.machineId, 'machine-1');
        expect(restored?.metadata?.path, '/repo');
        expect(restored?.metadata?.flavor, 'claude');
        expect(instance.testForceFullFetchNext, false);
      },
    );
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

    test('returns true when session presence is online', () async {
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
    });

    test('returns true when session comes online during wait', () async {
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
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        instance.testSessions['s1'] = instance.testSessions['s1']!.copyWith(
          presence: 'online',
        );
        instance.testNotifyDataChanged();
      });
      final ready = await instance.waitForAgentReady('s1', 2000);
      expect(ready, true);
    });
  });

  group('Sync.getLastMessagePreview', () {
    late Sync instance;

    setUp(() {
      instance = Sync();
      instance.sessionsSync = InvalidateSync(() async {});
      instance.settingsSync = InvalidateSync(() async {});
      instance.profileSync = InvalidateSync(() async {});
      instance.purchasesSync = InvalidateSync(() async {});
      instance.machinesSync = InvalidateSync(() async {});
      instance.pushTokenSync = InvalidateSync(() async {});
      instance.nativeUpdateSync = InvalidateSync(() async {});
      instance.artifactsSync = InvalidateSync(() async {});
      instance.friendsSync = InvalidateSync(() async {});
      instance.friendRequestsSync = InvalidateSync(() async {});
      instance.feedSync = InvalidateSync(() async {});
      instance.todosSync = InvalidateSync(() async {});
      instance.sessionGitStatusSync = InvalidateSync(() async {});
      instance.messagesSync.clear();
    });

    test('returns null when no messages', () {
      expect(instance.getLastMessagePreview('s1'), isNull);
    });

    test('finds last user message', () {
      instance.testSetSessionMessages('s1', [
        {'role': 'agent', 'text': 'hello', 'createdAt': 1},
        {'role': 'user', 'text': 'how are you?', 'createdAt': 2},
      ]);
      expect(instance.getLastMessagePreview('s1'), 'how are you?');
    });

    test('finds last agent message', () {
      instance.testSetSessionMessages('s1', [
        {'role': 'user', 'text': 'hi', 'createdAt': 1},
        {'role': 'agent', 'text': 'Hi! How can I help?', 'createdAt': 2},
      ]);
      expect(instance.getLastMessagePreview('s1'), 'Hi! How can I help?');
    });

    test('skips system and tool messages', () {
      instance.testSetSessionMessages('s1', [
        {'role': 'system', 'text': 'system prompt', 'createdAt': 1},
        {'role': 'agent', 'text': 'actual response', 'createdAt': 2},
        {'role': 'user', 'text': 'question', 'createdAt': 3},
      ]);
      expect(instance.getLastMessagePreview('s1'), 'question');
    });

    test('skips messages with empty text', () {
      instance.testSetSessionMessages('s1', [
        {'role': 'agent', 'text': '', 'createdAt': 1},
        {'role': 'user', 'text': '   ', 'createdAt': 2},
        {'role': 'agent', 'text': 'real content', 'createdAt': 3},
      ]);
      expect(instance.getLastMessagePreview('s1'), 'real content');
    });

    test('skips messages missing text field', () {
      instance.testSetSessionMessages('s1', [
        {'role': 'agent', 'createdAt': 1},
        {'role': 'user', 'text': 'visible', 'createdAt': 2},
      ]);
      expect(instance.getLastMessagePreview('s1'), 'visible');
    });

    test('does not match wrong role names', () {
      instance.testSetSessionMessages('s1', [
        {'role': 'human', 'text': 'wrong role name', 'createdAt': 1},
        {'role': 'assistant', 'text': 'also wrong', 'createdAt': 2},
        {'role': 'user', 'text': 'correct role', 'createdAt': 3},
      ]);
      expect(instance.getLastMessagePreview('s1'), 'correct role');
    });

    test('finds message via content field (processed messages)', () {
      instance.testSetSessionMessages('s1', [
        {
          'role': 'user',
          'kind': 'text',
          'content': 'user prompt',
          'createdAt': 1,
        },
        {
          'role': 'agent',
          'kind': 'text',
          'content': 'agent response',
          'createdAt': 2,
        },
      ]);
      expect(instance.getLastMessagePreview('s1'), 'agent response');
      expect(instance.getLastMessageRole('s1'), 'agent');
    });

    test('skips sidechain messages', () {
      instance.testSetSessionMessages('s1', [
        {
          'role': 'user',
          'kind': 'text',
          'content': 'main chat',
          'createdAt': 1,
        },
        {
          'role': 'agent',
          'kind': 'text',
          'content': 'sidechain text',
          'isSidechain': true,
          'createdAt': 2,
        },
      ]);
      expect(instance.getLastMessagePreview('s1'), 'main chat');
      expect(instance.getLastMessageRole('s1'), 'user');
    });

    test('skips tool-call and agent-event messages', () {
      instance.testSetSessionMessages('s1', [
        {'role': 'user', 'kind': 'text', 'content': 'prompt', 'createdAt': 1},
        {
          'role': 'agent',
          'kind': 'tool-call',
          'name': 'Agent',
          'content': 'tool data',
          'createdAt': 2,
        },
        {'role': 'agent', 'kind': 'agent-event', 'content': '', 'createdAt': 3},
      ]);
      expect(instance.getLastMessagePreview('s1'), 'prompt');
    });

    test('skips thinking blocks', () {
      instance.testSetSessionMessages('s1', [
        {
          'role': 'agent',
          'kind': 'text',
          'content': 'actual response',
          'createdAt': 1,
        },
        {
          'role': 'agent',
          'kind': 'text',
          'content': '*Thinking...*',
          'isThinking': true,
          'createdAt': 2,
        },
      ]);
      expect(instance.getLastMessagePreview('s1'), 'actual response');
    });
  });
}

class _TestEncryption implements Encryption {
  _TestEncryption({Map<String, SessionEncryption>? sessions})
    : _sessions = sessions ?? {};

  final Map<String, SessionEncryption> _sessions;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessions[sessionId];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopSessionEncryption implements SessionEncryption {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
