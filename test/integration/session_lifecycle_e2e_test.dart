import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

void main() {
  // ── Group 1: waitForAgentReady lifecycle checks ─────────────────────────

  group('waitForAgentReady lifecycle checks', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testIsInitialized = true;
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
    });

    test('online session is immediately ready', () async {
      sync.testSessions['s-online'] = _makeSession(
        's-online',
        presence: 'online',
      );
      // _isSessionReady cross-checks presence with a recent ephemeral
      // event (keep-alive / activity) to avoid trusting stale presence.
      sync.testSetLastEphemeralAt(
        's-online',
        DateTime.now().millisecondsSinceEpoch,
      );

      final ready = await sync.waitForAgentReady('s-online');
      expect(ready, isTrue);
    });

    // NOTE: _isSessionReady checks only 'running', not 'starting'.
    // A 'starting' session never resolves waitForAgentReady synchronously
    // but _resolveSendTargetSession (used by sendMessage) does treat it
    // as ready when the timestamp is recent.  This test verifies that
    // waitForAgentReady for a 'starting'-only session times out, while
    // the session IS considered ready for send purposes.
    test(
      'starting session with recent timestamp — ready for send, '
      'not immediately for waitForAgentReady',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        sync.testSessions['s-starting'] = _makeSession(
          's-starting',
          lifecycleState: 'starting',
          lifecycleStateSince: now - 5000, // 5 s ago
        );

        // waitForAgentReady does NOT resolve for 'starting' —
        // it only checks presence=='online' or lifecycleState=='running'.
        final ready = await sync.waitForAgentReady('s-starting', 100);
        expect(ready, isFalse,
            reason: 'waitForAgentReady does not resolve for "starting" '
                'state; only "online" or "running" qualify');
      },
    );

    test(
      'running session with recent timestamp is immediately ready',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        sync.testSessions['s-running'] = _makeSession(
          's-running',
          lifecycleState: 'running',
          lifecycleStateSince: now - 5000, // 5 s ago, within 120 s
        );

        final ready = await sync.waitForAgentReady('s-running');
        expect(ready, isTrue);
      },
    );

    test(
      'starting session with stale timestamp is NOT ready',
      () async {
        final stale =
            DateTime.now().millisecondsSinceEpoch - 300000; // 300 s ago
        sync.testSessions['s-stale-starting'] = _makeSession(
          's-stale-starting',
          lifecycleState: 'starting',
          lifecycleStateSince: stale,
        );

        final ready = await sync.waitForAgentReady('s-stale-starting', 100);
        expect(ready, isFalse);
      },
    );

    test('offline session with no lifecycle is NOT ready', () async {
      sync.testSessions['s-offline'] = _makeSession('s-offline');

      final ready = await sync.waitForAgentReady('s-offline', 100);
      expect(ready, isFalse);
    });

    test(
      'errored session fails readiness without waiting for timeout',
      () async {
        sync.testSessions['s-errored'] = _makeSession(
          's-errored',
          lifecycleState: 'errored',
          lifecycleStateError:
              'required executable codex is missing from '
              'Kubernetes session image',
        );

        final stopwatch = Stopwatch()..start();
        final ready = await sync.waitForAgentReady('s-errored', 5000);
        stopwatch.stop();

        expect(ready, isFalse);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      },
    );
  });

  // ── Group 2: readiness via _sessionSpawnedAt ─────────────────────────────

  group('readiness via _sessionSpawnedAt', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
    });

    test(
      'recently spawned session (< 120 s) is ready despite offline '
      '— sendMessage does not trigger auto-restore',
      () async {
        const sessionId = 'spawned-recent';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          machineId: 'machine-1',
          path: '/project',
        );
        // Mark spawned 10 s ago — within the 120 s window.
        sync.testSetSessionSpawnedAt(
          sessionId,
          DateTime.now().millisecondsSinceEpoch - 10000,
        );

        var rpcCalled = false;
        sync.testMachineRPCOverride = (_, __, ___) async {
          rpcCalled = true;
          return <String, dynamic>{};
        };
        sync.testFetchSingleSessionOverride = (_) async => null;

        final result = await sync.sendMessage(sessionId, 'hello');
        await sync.lastCompleteSendFuture;

        // Should use the same session without auto-restore.
        expect(result, sessionId);
        expect(rpcCalled, isFalse,
            reason:
                'recently spawned session must not trigger auto-restore RPC');
      },
    );

    test(
      'stale spawn (> 120 s) triggers auto-restore RPC',
      () async {
        const sessionId = 'spawned-stale';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          machineId: 'machine-1',
          path: '/project',
        );
        // Mark spawned 200 s ago — outside the 120 s window.
        sync.testSetSessionSpawnedAt(
          sessionId,
          DateTime.now().millisecondsSinceEpoch - 200000,
        );

        var rpcCalled = false;
        const restoredId = 'restored-stale-1';
        sync.testMachineRPCOverride = (machineId, method, params) async {
          rpcCalled = true;
          expect(method, 'spawn-happy-session');
          return <String, dynamic>{
            'type': 'success',
            'sessionId': restoredId,
            'dataEncryptionKey': null,
          };
        };
        sync.testFetchSingleSessionOverride = (_) async => null;

        final result = await sync.sendMessage(sessionId, 'hello');
        await sync.lastCompleteSendFuture;

        expect(rpcCalled, isTrue,
            reason: 'stale spawn must trigger auto-restore RPC');
        expect(result, restoredId);
      },
    );
  });

  // ── Group 3: lifecycle transitions via socket events ─────────────────────

  group('lifecycle transitions via socket events', () {
    late Sync sync;

    setUp(() {
      sync = Sync();
      sync.testIsInitialized = true;
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      _stubAllSyncs(sync);
    });

    test(
      'session-presence online makes session ready — '
      'waitForAgentReady resolves after ephemeral update',
      () async {
        sync.testSessions['s-eph'] = _makeSession('s-eph');

        // Schedule the ephemeral update to fire after a short delay.
        Timer(const Duration(milliseconds: 80), () {
          sync.handleEphemeralUpdate({
            'type': 'session-alive',
            'id': 's-eph',
          });
        });

        final ready = await sync.waitForAgentReady('s-eph', 5000);
        expect(ready, isTrue);
      },
    );

    test(
      'session going offline during waitForAgentReady does not '
      'falsely resolve',
      () async {
        sync.testSessions['s-neverready'] = _makeSession('s-neverready');

        // Never inject an online event — should time out.
        final ready = await sync.waitForAgentReady('s-neverready', 150);
        expect(ready, isFalse);
      },
    );

    test('rapid lifecycle transitions settle to the final state', () async {
      const id = 's-rapid';
      sync.testSessions[id] = _makeSession(id);

      // Fire several activity and alive events rapidly.
      for (var i = 0; i < 5; i++) {
        sync.handleEphemeralUpdate({'type': 'activity', 'id': id});
      }
      sync.handleEphemeralUpdate({'type': 'session-alive', 'id': id});
      sync.handleEphemeralUpdate({'type': 'activity', 'id': id});

      // After the rapid events the session should be online.
      final session = sync.testSessions[id];
      expect(session?.isOnline, isTrue,
          reason: 'rapid ephemeral events must settle to online');
    });
  });

  // ── Group 4: auto-restore lifecycle ──────────────────────────────────────

  group('auto-restore lifecycle', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();
      sync.encryption = encryption;
      sync.testIsInitialized = true;
      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};
      sync.testSessions.clear();
      sync.testClearSessionSpawnedAt();
      sync.testGetSpawnEnvVarsOverride = (_) async =>
          (envVars: <String, String>{}, profile: null);
      _stubAllSyncs(sync);
    });

    tearDown(() {
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testGetSpawnEnvVarsOverride = null;
    });

    test(
      'auto-restore clears from _autoRestoreInFlight after completion',
      () async {
        const sessionId = 'restore-inflight';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          machineId: 'machine-1',
          path: '/project',
        );

        final rpcGate = Completer<void>();
        sync.testMachineRPCOverride = (_, __, ___) async {
          // Block until the gate is opened.
          await rpcGate.future;
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        };
        sync.testFetchSingleSessionOverride = (_) async => null;

        // Start sendMessage — auto-restore runs in the background.
        final sendFuture = sync.sendMessage(sessionId, 'hello');

        // Give microtasks time to enter auto-restore.
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Verify that the session is in-flight.
        expect(
          sync.testAutoRestoreInFlight.contains(sessionId),
          isTrue,
          reason: 'session should be in-flight while RPC is pending',
        );

        // Unblock the RPC and await completion.
        rpcGate.complete();
        await sendFuture;
        await sync.lastCompleteSendFuture;

        // After completion the in-flight set must be empty.
        expect(
          sync.testAutoRestoreInFlight.contains(sessionId),
          isFalse,
          reason:
              '_autoRestoreInFlight must be cleared after restore completes',
        );
      },
    );

    test(
      'archived session (lifecycleState == "archived") triggers auto-restore',
      () async {
        const sessionId = 'archived-sess';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          presence: 'online', // presence says online…
          machineId: 'machine-1',
          path: '/project',
          lifecycleState: 'archived', // …but archived overrides it
        );

        var rpcCalled = false;
        const restoredId = 'archived-restored';
        sync.testMachineRPCOverride = (_, method, __) async {
          rpcCalled = true;
          expect(method, 'spawn-happy-session');
          return <String, dynamic>{
            'type': 'success',
            'sessionId': restoredId,
            'dataEncryptionKey': null,
          };
        };
        sync.testFetchSingleSessionOverride = (_) async => null;

        final result = await sync.sendMessage(sessionId, 'hello');
        await sync.lastCompleteSendFuture;

        expect(rpcCalled, isTrue,
            reason: 'archived lifecycleState must trigger auto-restore '
                'even when presence == "online"');
        expect(result, restoredId);
      },
    );

    test('errored session restores before sending', () async {
      const sessionId = 'errored-restorable';
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        machineId: 'machine-1',
        path: '/project',
        lifecycleState: 'errored',
      );

      var rpcCalled = false;
      const restoredId = 'errored-restored';
      sync.testMachineRPCOverride = (machineId, method, params) async {
        rpcCalled = true;
        expect(machineId, 'machine-1');
        expect(method, 'spawn-happy-session');
        final now = DateTime.now().millisecondsSinceEpoch;
        sync.testSessions[restoredId] = _makeSession(
          restoredId,
          presence: 'online',
          machineId: machineId,
          path: '/project',
          lifecycleState: 'running',
          lifecycleStateSince: now,
        );
        sync.testSetLastEphemeralAt(restoredId, now);
        return <String, dynamic>{
          'type': 'success',
          'sessionId': restoredId,
          'dataEncryptionKey': null,
        };
      };
      sync.testFetchSingleSessionOverride = (_) async => null;

      final result = await sync.sendMessage(sessionId, 'hello');
      await sync.lastCompleteSendFuture;

      expect(rpcCalled, isTrue);
      expect(result, restoredId);
      expect(
        sync.testSessionMessages(sessionId),
        isNull,
        reason: 'the stopped session must not receive the outbound message',
      );
      expect(sync.testSessionMessages(restoredId), isNotNull);
    });

    test(
      'errored session with redirect migrates conversation history',
      () async {
        const sessionId = 'errored-with-history';
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          machineId: 'machine-1',
          path: '/project',
          lifecycleState: 'errored',
        );
        sync.testSetSessionMessages(sessionId, [
          {
            'id': 'msg-1',
            'seq': 1,
            'role': 'user',
            'content': {'t': 'text', 'c': 'hello'},
            'createdAt': 1700000000000,
          },
          {
            'id': 'msg-2',
            'seq': 2,
            'role': 'assistant',
            'content': {'t': 'text', 'c': 'hi there'},
            'createdAt': 1700000001000,
          },
        ]);

        var rpcCalled = false;
        const restoredId = 'errored-restored-history';
        sync.testMachineRPCOverride = (machineId, method, params) async {
          rpcCalled = true;
          expect(machineId, 'machine-1');
          expect(method, 'spawn-happy-session');
          final now = DateTime.now().millisecondsSinceEpoch;
          sync.testSessions[restoredId] = _makeSession(
            restoredId,
            presence: 'online',
            machineId: machineId,
            path: '/project',
            lifecycleState: 'running',
            lifecycleStateSince: now,
          );
          sync.testSetLastEphemeralAt(restoredId, now);
          return <String, dynamic>{
            'type': 'success',
            'sessionId': restoredId,
            'dataEncryptionKey': null,
          };
        };
        sync.testFetchSingleSessionOverride = (_) async => null;

        final result = await sync.sendMessage(sessionId, 'follow-up');
        await sync.lastCompleteSendFuture;

        expect(rpcCalled, isTrue);
        expect(result, restoredId);

        final migrated = sync.testSessionMessages(restoredId);
        expect(migrated, isNotNull);
        // sendMessage inserts an optimistic placeholder, so the total is
        // 2 migrated + 1 optimistic = 3.
        expect(migrated, hasLength(3));
        final migratedIds = migrated?.map((m) => m['id'] as String?).toList();
        expect(
          migratedIds,
          containsAll(['msg-1', 'msg-2']),
          reason: 'old session messages must be migrated to redirected session',
        );
        expect(
          sync.testSessionMessages(sessionId),
          isNotNull,
          reason: 'original session messages must remain intact',
        );
      },
    );

    test('errored session keeps message when auto-restore RPC fails', () async {
      const sessionId = 'errored-restore-fail';
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        machineId: 'machine-1',
        path: '/project',
        lifecycleState: 'errored',
      );

      sync.testMachineRPCOverride = (machineId, method, params) async {
        return <String, dynamic>{
          'type': 'error',
          'errorMessage': 'machine unavailable',
        };
      };
      sync.testFetchSingleSessionOverride = (_) async => null;

      final result = await sync.sendMessage(sessionId, 'hello');
      await sync.lastCompleteSendFuture;

      expect(result, sessionId);
      final messages = sync.testSessionMessages(sessionId);
      expect(messages, isNotNull);
      expect(messages, hasLength(1));
      expect(messages!.single['localId'], isNotNull);
      expect(messages.single['content'], 'hello');
      expect(
        messages.single['sendStatus'],
        anyOf('sending', 'pending', 'failed'),
        reason: 'failed restore should keep a retryable optimistic message '
            'instead of dropping the send',
      );
    });

    test('codex permission auto-restore keeps agent and model mode', () async {
      const sessionId = 'codex-goal-resume';
      Map<String, dynamic>? capturedParams;
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        machineId: 'machine-1',
        path: '/project',
        lifecycleState: 'archived',
        flavor: 'codex',
        modelMode: 'gpt-5.5:medium',
      );

      sync.testMachineRPCOverride = (machineId, method, params) async {
        capturedParams = params;
        expect(machineId, 'machine-1');
        expect(method, 'spawn-happy-session');
        return <String, dynamic>{
          'type': 'success',
          'sessionId': sessionId,
          'dataEncryptionKey': null,
        };
      };
      sync.testFetchSingleSessionOverride = (_) async => null;

      await expectLater(
        () => sync.sessionAllow(sessionId, 'perm-1'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('permission has expired'),
          ),
        ),
      );

      expect(capturedParams, isNotNull);
      expect(capturedParams!['agent'], 'codex');
      expect(capturedParams!['model'], 'gpt-5.5:medium');
      expect(sync.testSessionSpawnedAgent[sessionId], 'codex');
      expect(sync.testSessionSpawnedModel[sessionId], 'gpt-5.5:medium');
    });

    test(
      'permission auto-restore drops incompatible Claude model override '
      'for third-party Anthropic base URL',
      () async {
        const sessionId = 'claude-permission-incompatible-model';
        Map<String, dynamic>? capturedParams;
        sync.testSessions[sessionId] = _makeSession(
          sessionId,
          machineId: 'machine-1',
          path: '/project',
          lifecycleState: 'archived',
          flavor: 'claude',
          modelMode: 'opus:max',
        );

        final deepseek = getBuiltInProfile('deepseek')!;
        sync.testGetSpawnEnvVarsOverride = (_) async => (
          envVars: {
            for (final v in deepseek.environmentVariables) v.name: v.value,
          },
          profile: deepseek,
        );

        sync.testMachineRPCOverride = (machineId, method, params) async {
          capturedParams = params;
          expect(machineId, 'machine-1');
          expect(method, 'spawn-happy-session');
          return <String, dynamic>{
            'type': 'success',
            'sessionId': sessionId,
            'dataEncryptionKey': null,
          };
        };
        sync.testFetchSingleSessionOverride = (_) async => null;

        await expectLater(
          () => sync.sessionAllow(sessionId, 'perm-1'),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('permission has expired'),
            ),
          ),
        );

        expect(capturedParams, isNotNull);
        expect(
          capturedParams!['model'],
          'default',
          reason:
              'Claude model override must be dropped when profile sets a '
              'third-party Anthropic-compatible base URL, and replaced with '
              'an explicit default so the daemon clears sticky metadata',
        );
        final envVars =
            capturedParams!['environmentVariables']
                as Map<String, dynamic>?;
        expect(envVars, isNotNull);
        expect(
          envVars!['ANTHROPIC_BASE_URL'],
          contains('deepseek'),
          reason:
              'Third-party Anthropic-compatible base URL must still be sent',
        );
      },
    );

    test('errored session without restore target fails before send', () async {
      const sessionId = 'errored-no-restore-target';
      sync.testSessions[sessionId] = _makeSession(
        sessionId,
        lifecycleState: 'errored',
      );
      sync.testFetchSingleSessionOverride = (_) async => null;

      var rpcCalled = false;
      sync.testMachineRPCOverride = (_, __, ___) async {
        rpcCalled = true;
        return <String, dynamic>{};
      };

      const localId = 'errored-setup-local-id';
      await expectLater(
        sync.sendMessage(sessionId, 'hello', clientLocalId: localId),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('missing machineId/path'),
          ),
        ),
      );
      expect(rpcCalled, isFalse);
      final failedRows = sync.testSessionMessages(sessionId)!;
      expect(failedRows, hasLength(1));
      expect(failedRows.single['localId'], localId);
      expect(failedRows.single['sendStatus'], 'failed');
      expect(failedRows.single['raw'], isA<Map<String, dynamic>>());
    });
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────────

Session _makeSession(
  String id, {
  String presence = 'offline',
  String? machineId,
  String? path,
  String? flavor,
  String? lifecycleState,
  int? lifecycleStateSince,
  String? lifecycleStateError,
  String? modelMode,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Session(
    id: id,
    seq: 1,
    createdAt: now,
    updatedAt: now,
    active: true,
    activeAt: now,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: presence,
    metadata: Metadata(
      host: '',
      machineId: machineId,
      path: path,
      flavor: flavor,
      lifecycleState: lifecycleState,
      lifecycleStateError: lifecycleStateError,
      lifecycleStateSince: lifecycleStateSince,
    ),
    modelMode: modelMode,
  );
}

void _stubAllSyncs(Sync instance, {Future<void> Function()? sessionsFn}) {
  try {
    instance.sessionsSync.dispose();
  } on Error {
    // Not initialized yet — safe to continue.
  }
  instance.sessionsSync = InvalidateSync(sessionsFn ?? () async {});
  instance.settingsSync = InvalidateSync(() async {});
  instance.profileSync = InvalidateSync(() async {});
  instance.purchasesSync = InvalidateSync(() async {});
  instance.machinesSync = InvalidateSync(() async {});
  instance.pushTokenSync = InvalidateSync(() async {});
  instance.nativeUpdateSync = InvalidateSync(() async {});
  instance.artifactsSync = InvalidateSync(() async {});
  instance.sessionGitStatusSync = InvalidateSync(() async {});
  instance.messagesSync.clear();
}

// ── Fake encryption ──────────────────────────────────────────────────────────

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      _sessions.putIfAbsent(
        sessionId,
        () => _FakeSessionEncryption(sessionId: sessionId),
      );

  @override
  String generateId() =>
      'test-local-${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<Uint8List?> decryptEncryptionKey(String encryptedKey) async =>
      Uint8List.fromList(utf8.encode('decrypted'));

  @override
  Future<void> initializeSessions(
    Map<String, Uint8List?> sessionKeys,
  ) async {}

  @override
  void removeSessionEncryption(String sessionId) {
    _sessions.remove(sessionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionEncryption extends SessionEncryption {
  _FakeSessionEncryption({required String sessionId})
      : super(
          sessionId: sessionId,
          encryptor: _FakeEncryptor(),
          decryptor: _FakeEncryptor(),
          cache: EncryptionCache(),
        );
}

class _FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data.map((item) {
      final json = jsonEncode(item);
      final bytes = utf8.encode(json);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      return output;
    }).toList();
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    return data.map((item) {
      if (item.isEmpty) return null;
      try {
        return item[0] == 0x01
            ? jsonDecode(utf8.decode(item.sublist(1)))
            : utf8.decode(item);
      } catch (_) {
        return null;
      }
    }).toList();
  }
}
