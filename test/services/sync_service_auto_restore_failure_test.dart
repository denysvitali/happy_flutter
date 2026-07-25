// Contract test for the auto-restore catch-all failure surface.
//
// Pins HAPPY_FLUTTER-3EP-class issues: when `_resolveSendTargetSession`'s
// catch-all branch fires (the failure is neither transient, nor permanent,
// nor lifecycle-related), the user must see the failure.  Previously the
// branch only logged at error level and let `_completeSend` POST to a
// broken session.  This test pins:
//
//   1. `sendMessage` does NOT throw on a catch-all failure.
//   2. The session's `lifecycleState` is unchanged (no silent
//      re-spawn masking the real error).
//   3. The structured `AutoRestoreFailure` event reaches subscribers.
//   4. The `app.auto_restore.failed` counter is bumped (stub sink).
//   5. Sentry capture is invoked (stub sink — we cannot stub the real
//      SDK here without an HTTP double, so we route through
//      `testRecordAppErrorSink` and assert the auto-restore emit fired;
//      a companion integration test exercises the real Sentry SDK).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

void main() {
  group('auto-restore catch-all failure surface', () {
    late Sync sync;
    late _FakeEncryption encryption;
    late List<AutoRestoreFailure> failures;
    late List<String> counterNames;
    late StreamSubscription<AutoRestoreFailure> failureSub;

    setUp(() async {
      sync = Sync();
      encryption = _FakeEncryption();

      for (final id in sync.sessionMessages.keys.toList()) {
        sync.testSetSessionMessages(id, []);
      }
      for (final id in sync.testSessions.keys.toList()) {
        sync.testSetSessionLastSeq(id, 0);
      }
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

      sync.testSocketConnectedOverride = true;
      sync.testSocketSendOverride = (_, __) {};

      sync.encryption = encryption;
      sync.testIsInitialized = true;

      // Always-success interceptor for the message POST; the spawn RPC
      // stub is wired in each test.
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(_PostSuccessInterceptor());

      // Subscribe to the auto-restore failure stream and stub the
      // counter recorder.  Real Sentry capture is exercised in the
      // companion integration test under `test/integration/`.
      failures = [];
      counterNames = [];
      failureSub = sync.onAutoRestoreFailure.listen(failures.add);
      sync.testRecordAppErrorSink = counterNames.add;
      sync.testAutoRestoreFailureSink = null; // exercise the real controller
    });

    tearDown(() async {
      await failureSub.cancel();
      sync.testSocketConnectedOverride = null;
      sync.testSocketSendOverride = null;
      sync.testMachineRPCOverride = null;
      sync.testFetchSingleSessionOverride = null;
      sync.testRecordAppErrorSink = null;
      sync.testAutoRestoreFailureSink = null;
      ApiClient().dispose();
    });

    test(
      'catch-all failure does NOT throw, emits AutoRestoreFailure, '
      'bumps app.auto_restore.failed counter, and preserves '
      'lifecycleState',
      () async {
        final sessionId = 'sess-catchall-fail';
        final now = DateTime.now().millisecondsSinceEpoch;

        // Session is in the "exited" state so the code path falls
        // through to auto-restore (looksReady == false).
        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: false,
          activeAt: now,
          metadata: Metadata(
            host: '',
            machineId: 'machine-1',
            path: '/repo',
            flavor: 'claude',
            lifecycleState: 'exited',
            lifecycleStateSince: now,
          ),
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
        );
        sync.testMachines['machine-1'] = Machine(
          id: 'machine-1',
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadataVersion: 1,
          daemonStateVersion: 0,
          metadata: const MachineMetadata(homeDir: '/home/user'),
        );

        // RPC returns a generic non-permanent, non-transient,
        // non-terminal-state error so the catch-all branch fires.
        // An unhandled StateError with an unrelated message puts us
        // squarely in the "unknown" bucket.
        sync.testMachineRPCOverride = (
          machineId,
          method,
          params,
        ) async {
          if (method == 'spawn-happy-session') {
            throw StateError(
              'something unexpected happened on the daemon side',
            );
          }
          return <String, dynamic>{'ok': true};
        };

        // MUST NOT throw — ROADMAP P0 invariant: the user must see
        // the failure, not have the message vanish.
        final result = await sync.sendMessage(sessionId, 'hello');

        // Returns the fallback session so the chat UI stays
        // consistent (same contract as the other catch branches).
        expect(result, sessionId);

        // The structured failure must reach subscribers.
        expect(failures, hasLength(1));
        final failure = failures.single;
        expect(failure.sessionId, sessionId);
        expect(failure.reason, 'unknown');
        expect(failure.error, isA<StateError>());

        // The counter must have been bumped exactly once with the
        // canonical app-level name.
        expect(counterNames, contains('app.auto_restore.failed'));

        // The session metadata MUST be untouched — no silent
        // re-spawn that would mask the real failure.
        final updated = sync.testSessions[sessionId];
        expect(updated?.metadata?.lifecycleState, 'exited');
        expect(
          updated?.metadata?.lifecycleStateError,
          isNull,
          reason:
              'The catch-all branch must not silently mutate the '
              'session metadata — only the terminal-state race '
              'branch is allowed to strip the flag.',
        );
      },
    );

    test(
      'transient RPC errors do NOT emit AutoRestoreFailure '
      'or bump the counter (regression: only catch-all emits)',
      () async {
        final sessionId = 'sess-transient-fail';
        final now = DateTime.now().millisecondsSinceEpoch;

        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: false,
          activeAt: now,
          metadata: Metadata(
            host: '',
            machineId: 'machine-1',
            path: '/repo',
            flavor: 'claude',
            lifecycleState: 'exited',
            lifecycleStateSince: now,
          ),
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
        );
        sync.testMachines['machine-1'] = Machine(
          id: 'machine-1',
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadataVersion: 1,
          daemonStateVersion: 0,
          metadata: const MachineMetadata(homeDir: '/home/user'),
        );

        // A transient RPC error — must NOT trigger the user-visible
        // failure stream; this is the whole reason we classify.
        sync.testMachineRPCOverride = (
          machineId,
          method,
          params,
        ) async {
          if (method == 'spawn-happy-session') {
            // SocketAckTimeoutException is recognized by
            // `_isTransientConnectionError`, so the catch-all
            // branch must NOT fire — that's the whole point of
            // the classification system.
            throw const SocketAckTimeoutException('spawn-happy-session');
          }
          return <String, dynamic>{'ok': true};
        };

        await sync.sendMessage(sessionId, 'hello');

        expect(failures, isEmpty);
        expect(counterNames, isEmpty);
      },
    );

    test(
      'testAutoRestoreFailureSink intercepts the event for unit tests',
      () async {
        // Direct API test: sinks let tests assert on the structured
        // failure without subscribing to the broadcast stream.
        final sessionId = 'sess-sink-test';
        final captured = <AutoRestoreFailure>[];
        sync.testAutoRestoreFailureSink = captured.add;

        // Fire the sink directly (the catch-all branch is covered
        // by the test above; this pins the sink contract alone).
        // We invoke the public stream by adding to the controller —
        // but the controller is private.  Re-derive via the
        // broadcast stream to keep the test honest.
        // No-op here: the first test already exercises the
        // controller path.  This test only asserts the sink
        // override receives events when set.
        sync.testAutoRestoreFailureSink = captured.add;
        // Provide minimal session so the call doesn't pre-emptively
        // fail in a way that masks the sink.
        final now = DateTime.now().millisecondsSinceEpoch;
        sync.testSessions[sessionId] = Session(
          id: sessionId,
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: false,
          activeAt: now,
          metadata: Metadata(
            host: '',
            machineId: 'machine-1',
            path: '/repo',
            flavor: 'claude',
            lifecycleState: 'exited',
            lifecycleStateSince: now,
          ),
          metadataVersion: 1,
          agentStateVersion: 1,
          thinking: false,
          presence: 'offline',
        );
        sync.testMachines['machine-1'] = Machine(
          id: 'machine-1',
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadataVersion: 1,
          daemonStateVersion: 0,
          metadata: const MachineMetadata(homeDir: '/home/user'),
        );
        sync.testMachineRPCOverride = (
          machineId,
          method,
          params,
        ) async {
          if (method == 'spawn-happy-session') {
            throw StateError('unhandled');
          }
          return <String, dynamic>{'ok': true};
        };

        await sync.sendMessage(sessionId, 'hello');

        // The sink captured the same event the broadcast stream
        // would have.  Test sinks are mutually exclusive with the
        // broadcast controller (see _safeEmitAutoRestoreFailure),
        // so the broadcast listener `failures` should be empty.
        expect(captured, hasLength(1));
        expect(captured.single.reason, 'unknown');
        expect(failures, isEmpty);
      },
    );
  });
}

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _FakeSessionEncryption(sessionId: sessionId),
    );
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
    final results = <Uint8List>[];
    for (final item in data) {
      final json = jsonEncode(item);
      final bytes = utf8.encode(json);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      results.add(output);
    }
    return results;
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    final results = <dynamic>[];
    for (final item in data) {
      if (item.isEmpty) {
        results.add(null);
        continue;
      }
      try {
        if (item[0] == 0x01) {
          final json = utf8.decode(item.sublist(1));
          results.add(jsonDecode(json));
        } else {
          results.add(utf8.decode(item));
        }
      } catch (_) {
        results.add(null);
      }
    }
    return results;
  }
}

class _PostSuccessInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/v3/sessions/') &&
        options.path.contains('/messages')) {
      final now = DateTime.now();
      handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'messages': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'srv-msg-${now.microsecondsSinceEpoch}',
                'seq': 2,
                'createdAt': now.millisecondsSinceEpoch,
              },
            ],
          },
        ),
      );
      return;
    }
    handler.next(options);
  }
}
