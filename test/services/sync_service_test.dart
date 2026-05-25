import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
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
import '../helpers/test_helpers.dart';

void main() {
  group('Sync.handleUpdate', () {
    late Sync instance;
    late int sessionsInvalidations;
    late int settingsInvalidations;
    late int profileInvalidations;

    setUp(() {
      instance = Sync();
      sessionsInvalidations = 0;
      settingsInvalidations = 0;
      profileInvalidations = 0;

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
      'known update-session with simple fields does not fetch sessions',
      () async {
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
          'id': 'session_1',
          'presence': 'online',
          'thinking': true,
          'lastSeq': 7,
        });

        await Future<void>.delayed(const Duration(milliseconds: 2500));
        await instance.sessionsSync.awaitQueue();

        final session = instance.testSessions['session_1']!;
        expect(session.presence, 'online');
        expect(session.thinking, true);
        expect(session.lastSeq, 7);
        expect(sessionsInvalidations, 0);
      },
    );

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
        instance.handleUpdate({'t': 'update-session', 'id': 'unknown_1'});
        instance.handleUpdate({'t': 'update-session', 'id': 'unknown_1'});
        instance.handleUpdate({'t': 'update-session', 'id': 'unknown_1'});

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

    test('alive-batch marks sessions online without top-level sid', () {
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

      instance.handleEphemeralUpdate({
        'type': 'alive-batch',
        'sessions': [
          {'id': 's1', 'activeAt': 1234, 'thinking': true},
        ],
      });

      final session = instance.testSessions['s1']!;
      expect(session.presence, 'online');
      expect(session.thinking, isTrue);
      expect(session.thinkingAt, 1234);
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

    test('machine-activity for unknown machine schedules machines refresh', () {
      fakeAsync((async) {
        final instance = Sync();
        var machinesRefreshes = 0;
        instance.machinesSync = InvalidateSync(() async {
          machinesRefreshes++;
        });

        instance.handleEphemeralUpdate({
          'type': 'machine-activity',
          'id': 'm-new',
          'active': true,
        });

        expect(
          machinesRefreshes,
          0,
          reason: 'unknown machine activity should debounce refresh first',
        );

        async.elapse(const Duration(milliseconds: 300));

        expect(
          machinesRefreshes,
          1,
          reason:
              'unknown machine activity must trigger a machines fetch so '
              'newly connected daemons appear without a manual refresh',
        );
      });
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
      instance.artifactsSync = InvalidateSync(() async {});
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

    test('refreshSessionsListData dedupes concurrent callers', () async {
      final instance = Sync();
      instance.testIsInitialized = true;

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
      instance.sessionGitStatusSync = InvalidateSync(() async {});

      final first = instance.refreshSessionsListData();
      final second = instance.refreshSessionsListData();

      expect(first, same(second));

      await first;
      expect(
        sessionsInvalidations,
        1,
        reason: 'Concurrent session-list refresh requests should coalesce',
      );
    });

    test('refreshSessionsListData defers machine refresh with delay', () {
      fakeAsync((async) {
        final instance = Sync();
        instance.testIsInitialized = true;
        instance.testSessions['warm-session'] = Session(
          id: 'warm-session',
          seq: 1,
          createdAt: 1,
          updatedAt: 1,
          active: true,
          activeAt: 1,
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
        );
        final started = <String>[];
        instance.sessionsSync = InvalidateSync(() async {
          started.add('sessions');
        });
        instance.settingsSync = InvalidateSync(() async {});
        instance.profileSync = InvalidateSync(() async {});
        instance.purchasesSync = InvalidateSync(() async {});
        instance.machinesSync = InvalidateSync(() async {
          started.add('machines');
        });
        instance.pushTokenSync = InvalidateSync(() async {});
        instance.nativeUpdateSync = InvalidateSync(() async {});
        instance.artifactsSync = InvalidateSync(() async {});
        instance.sessionGitStatusSync = InvalidateSync(() async {});

        instance.refreshSessionsListData(includeMachines: true);

        async.flushMicrotasks();
        expect(started, ['sessions']);

        async.elapse(const Duration(milliseconds: 800));
        expect(started, ['sessions', 'machines']);
      });
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

  group('Sync cold-start message cache warmup', () {
    test(
      'sorts all sessions by updatedAt desc so previews warm most-recent '
      'first',
      () {
        final instance = Sync();
        instance.testSessions.clear();

        for (var i = 0; i < 25; i++) {
          final id = 'session-$i';
          instance.testSessions[id] = Session(
            id: id,
            seq: 0,
            createdAt: i,
            updatedAt: i,
            active: true,
            activeAt: i,
            metadataVersion: 0,
            agentStateVersion: 0,
            thinking: false,
            presence: 'offline',
          );
        }

        final selected = instance.testSortedSessionIdsForCacheWarmup();

        // All sessions are processed (no 20-session cap) so older sessions
        // also get their last-message previews warmed instead of falling
        // back to session.updatedAt ("Just now") in the list UI.
        expect(selected, hasLength(25));
        expect(selected.first, 'session-24');
        expect(selected.last, 'session-0');
      },
    );
  });

  group('Sync model change detection', () {
    late Sync sync;

    setUp(() {
      sync = createPartialMockSync();
      // Initialize all InvalidateSync fields to no-ops
      sync.sessionsSync = InvalidateSync(() async {});
      sync.settingsSync = InvalidateSync(() async {});
      sync.profileSync = InvalidateSync(() async {});
      sync.purchasesSync = InvalidateSync(() async {});
      sync.machinesSync = InvalidateSync(() async {});
      sync.pushTokenSync = InvalidateSync(() async {});
      sync.nativeUpdateSync = InvalidateSync(() async {});
      sync.artifactsSync = InvalidateSync(() async {});
      sync.sessionGitStatusSync = InvalidateSync(() async {});
      sync.messagesSync.clear();
    });

    test(
      'model change detected when session spawned with different modelMode',
      () async {
        const sessionId = 'session-test-model';
        final now = DateTime.now().millisecondsSinceEpoch;

        // Set up a spawned session with lifecycleState='running'
        // This makes session.isOnline true and lifecycleStateRecent true
        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadata: Metadata(
            host: 'test-host',
            machineId: 'machine-1',
            path: '/repo',
            flavor: 'claude',
            lifecycleState: 'running',
            lifecycleStateSince: now,
          ),
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'online',
        );

        // Register the session as recently spawned with modelMode = 'default'
        sync.testSetSessionSpawnedAt(sessionId, now);
        sync.testSetSessionSpawnedProfile(sessionId, null);
        sync.testSetSessionSpawnedModel(sessionId, 'default');

        // Simulate ephemeral activity so online presence is trusted
        sync.testSetLastEphemeralAt(sessionId, now);

        // Verify preconditions: model change is detected in _resolveSendTargetSession
        // modelChanged = modelMode != 'default' && _sessionSpawnedModel[sessionId] == 'default'
        // The spawned model is 'default' and we will send with 'opus' modelMode
        expect(sync.testSessionSpawnedModel[sessionId], 'default');

        // Verify session looks ready
        final session = sync.testSessions[sessionId]!;
        expect(session.isOnline, true);
        expect(session.metadata?.lifecycleState, 'running');

        // Set up a machine so the session is eligible for kill+respawn
        sync.testMachines['machine-1'] = Machine(
          id: 'machine-1',
          seq: 1,
          createdAt: 0,
          updatedAt: 0,
          active: true,
          activeAt: now,
          metadataVersion: 0,
          daemonStateVersion: 0,
        );
      },
    );
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
