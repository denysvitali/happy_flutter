// Readiness retries only idempotent pings. Both attempts share one deadline;
// server routing misses never prove liveness and stale/background completions
// must not authorize a spawn.

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

void main() {
  group('ensureMachineReachable ping retry', () {
    late Sync sync;
    late _FakeEncryption encryption;

    setUp(() {
      sync = Sync();
      encryption = _FakeEncryption();

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

      sync.encryption = encryption;
      sync.testIsInitialized = true;
      InvalidateSync.isBackgrounded = false;
    });

    tearDown(() {
      InvalidateSync.isBackgrounded = false;
      sync.testEnsureMachineReachableOverride = null;
      sync.testEnsureMachineReachableMachineRPCOverride = null;
    });

    test('succeeds when first ping times out and second succeeds '
        '(common transient ACK race)', () async {
      // Simulate the production scenario: first ping ACK lost
      // to dispatcher variance; second one 300ms later goes
      // through. Without the retry, this would block the
      // session spawn for the full 60s.
      var pingAttempts = 0;
      sync.testEnsureMachineReachableMachineRPCOverride =
          (machineId, method, params) async {
            if (method != 'ping') {
              return _okRpc(method);
            }
            pingAttempts++;
            if (pingAttempts == 1) {
              throw const SocketAckTimeoutException(
                'ACK timeout for event "rpc-call"',
              );
            }
            return _okRpc(method);
          };

      // Must not throw — the second attempt succeeds.
      await sync.ensureMachineReachable('machine-1');
      expect(pingAttempts, 2, reason: 'Must attempt ping twice');
    });

    test('throws Machine is unreachable after two consecutive '
        'ping timeouts (truly unreachable)', () async {
      var pingAttempts = 0;
      sync.testEnsureMachineReachableMachineRPCOverride =
          (machineId, method, params) async {
            if (method != 'ping') return _okRpc(method);
            pingAttempts++;
            throw const SocketAckTimeoutException(
              'ACK timeout for event "rpc-call"',
            );
          };

      await expectLater(
        () => sync.ensureMachineReachable('machine-1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('unreachable'),
          ),
        ),
      );
      // Two attempts, then give up — the second timeout proves
      // the machine is truly down, not just slow on the first
      // dispatch.
      expect(
        pingAttempts,
        2,
        reason: 'Must give up after exactly two attempts',
      );
    });

    test(
      'throws Machine is unreachable when server reports no handler on any replica',
      () async {
        sync.testEnsureMachineReachableMachineRPCOverride =
            (machineId, method, params) async {
              return <String, dynamic>{
                'ok': false,
                'error':
                    'RPC handler for "machine-1:ping" is not registered on any reachable server replica',
              };
            };

        await expectLater(
          () => sync.ensureMachineReachable('machine-1'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Machine is unreachable'),
            ),
          ),
        );
      },
    );

    for (final code in [
      RpcErrorCode.handlerOffline,
      RpcErrorCode.forwardingFailed,
    ]) {
      test('retries a transient ${code.wireValue} readiness failure', () async {
        var calls = 0;
        sync.testEnsureMachineReachableMachineRPCOverride = (_, __, ___) async {
          calls++;
          if (calls == 1) {
            throw RpcException(code: code, message: 'routing', retryable: true);
          }
          return _okRpc('ping');
        };
        await sync.ensureMachineReachable('machine-1');
        expect(calls, 2);
      });
    }

    test('disconnected ping retries safely before any spawn', () async {
      var calls = 0;
      sync.testEnsureMachineReachableMachineRPCOverride = (_, __, ___) async {
        if (++calls == 1) throw const SocketNotConnectedException('rpc-call');
        return _okRpc('ping');
      };
      await sync.ensureMachineReachable('machine-1');
      expect(calls, 2);
    });

    test('missing encryption does not prove daemon liveness', () async {
      sync.testEnsureMachineReachableMachineRPCOverride = (_, __, ___) async {
        throw StateError('Machine encryption not found for machine-1');
      };
      await expectLater(
        sync.ensureMachineReachable('machine-1'),
        throwsStateError,
      );
    });

    test('typed unsupported ping proves legacy daemon liveness', () async {
      var calls = 0;
      sync.testEnsureMachineReachableMachineRPCOverride = (_, __, ___) async {
        calls++;
        throw const RpcException(
          code: RpcErrorCode.methodUnsupported,
          message: 'Method not found',
          retryable: false,
        );
      };
      await sync.ensureMachineReachable('machine-1');
      expect(calls, 1);
    });

    test('hung readiness override obeys one caller deadline', () {
      fakeAsync((async) {
        var calls = 0;
        Object? failure;
        sync.testEnsureMachineReachableMachineRPCOverride = (_, __, ___) {
          calls++;
          return Completer<Map<String, dynamic>>().future;
        };
        sync
            .ensureMachineReachable(
              'machine-1',
              timeout: const Duration(milliseconds: 100),
            )
            .then<void>(
              (_) => fail('Unexpected readiness'),
              onError: (Object e) {
                failure = e;
              },
            );
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 100));
        expect(failure, isA<StateError>());
        async.elapse(const Duration(seconds: 30));
        expect(calls, 1, reason: 'Expired work must not start another ping');
      });
    });

    for (final invalidate in ['runtime', 'background']) {
      test('late ping cannot establish readiness after $invalidate', () async {
        final pending = Completer<Map<String, dynamic>>();
        sync.testEnsureMachineReachableMachineRPCOverride = (_, __, ___) =>
            pending.future;
        final result = expectLater(
          sync.ensureMachineReachable('machine-1'),
          throwsStateError,
        );
        if (invalidate == 'runtime') {
          sync.testAdvanceRuntimeGeneration();
        } else {
          InvalidateSync.isBackgrounded = true;
        }
        pending.complete(_okRpc('ping'));
        await result;
      });

      test('readiness retry is fenced after $invalidate', () {
        fakeAsync((async) {
          var calls = 0;
          Object? failure;
          sync.testEnsureMachineReachableMachineRPCOverride =
              (_, __, ___) async {
                calls++;
                throw const RpcException(
                  code: RpcErrorCode.handlerOffline,
                  message: 'routing',
                  retryable: true,
                );
              };
          sync
              .ensureMachineReachable('machine-1')
              .then<void>(
                (_) => fail('Unexpected readiness'),
                onError: (Object e) {
                  failure = e;
                },
              );
          async.flushMicrotasks();
          if (invalidate == 'runtime') {
            sync.testAdvanceRuntimeGeneration();
          } else {
            InvalidateSync.isBackgrounded = true;
          }
          async.elapse(const Duration(seconds: 1));
          expect(calls, 1);
          expect(failure, isA<StateError>());
        });
      });
    }

    test('returns on first successful ping without retrying', () async {
      var pingAttempts = 0;
      sync.testEnsureMachineReachableMachineRPCOverride =
          (machineId, method, params) async {
            if (method != 'ping') return _okRpc(method);
            pingAttempts++;
            return _okRpc(method);
          };

      await sync.ensureMachineReachable('machine-1');
      expect(pingAttempts, 1, reason: 'Healthy daemon needs no retry');
    });
  });
}

Map<String, dynamic> _okRpc(String method) => <String, dynamic>{
  'ok': true,
  'result': '',
};

class _FakeEncryption implements Encryption {
  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _FakeSessionEncryption(sessionId: sessionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionEncryption extends SessionEncryption {
  _FakeSessionEncryption({required String sessionId})
    : super(
        sessionId: sessionId,
        encryptor: _NoopEncryptor(),
        decryptor: _NoopEncryptor(),
        cache: EncryptionCache(),
      );
}

class _NoopEncryptor implements Encryptor {
  @override
  Future<List<dynamic>> decrypt(List<dynamic> data) async {
    return data;
  }

  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data.map((d) => Uint8List(0)).toList();
  }
}
