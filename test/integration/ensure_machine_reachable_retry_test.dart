// Contract test for the ensureMachineReachable retry behavior.
//
// Pins the HAPPY_FLUTTER-3DF fix: a single ping ACK timeout
// (SocketAckTimeoutException) no longer blocks a session
// spawn — the client retries once before declaring the
// machine unreachable. The 12s budget + 300ms gap absorbs
// the common "first ACK lost to dispatcher variance" race
// without burning the 60s spawn timeout.
//
// The pre-fix behavior was: 1 timeout → user blocked for
// 60s. The post-fix behavior is: 1 timeout → 1 retry
// (300ms gap, another 12s budget) → success most of the
// time, or a fast second-timeout that doesn't change the
// user-visible 8s-after-bump blocking time.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

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
    });

    tearDown(() {
      sync.testEnsureMachineReachableOverride = null;
      sync.testEnsureMachineReachableMachineRPCOverride = null;
    });

    test(
      'succeeds when first ping times out and second succeeds '
      '(common transient ACK race)',
      () async {
        // Simulate the production scenario: first ping ACK lost
        // to dispatcher variance; second one 300ms later goes
        // through. Without the retry, this would block the
        // session spawn for the full 60s.
        var pingAttempts = 0;
        sync.testEnsureMachineReachableMachineRPCOverride = (
          machineId,
          method,
          params,
        ) async {
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
      },
    );

    test(
      'throws Machine is unreachable after two consecutive '
      'ping timeouts (truly unreachable)',
      () async {
        var pingAttempts = 0;
        sync.testEnsureMachineReachableMachineRPCOverride = (
          machineId,
          method,
          params,
        ) async {
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
      },
    );

    test(
      'throws Machine is unreachable when server reports no handler on any replica',
      () async {
        sync.testEnsureMachineReachableMachineRPCOverride = (
          machineId,
          method,
          params,
        ) async {
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

    test(
      'returns on first successful ping without retrying',
      () async {
        var pingAttempts = 0;
        sync.testEnsureMachineReachableMachineRPCOverride = (
          machineId,
          method,
          params,
        ) async {
          if (method != 'ping') return _okRpc(method);
          pingAttempts++;
          return _okRpc(method);
        };

        await sync.ensureMachineReachable('machine-1');
        expect(pingAttempts, 1, reason: 'Healthy daemon needs no retry');
      },
    );
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
