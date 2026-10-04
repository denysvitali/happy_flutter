import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/machine_encryption.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

void main() {
  final sync = Sync();

  tearDown(() {
    sync.testMachineRPCOverride = null;
    InvalidateSync.isBackgrounded = false;
  });

  for (final invalidate in ['runtime', 'background']) {
    test(
      'production spawn is fenced during encryption after $invalidate',
      () async {
        final machine = _DeferredMachineEncryption();
        sync.encryption = _MachineEncryptionStore(machine);
        final expected = invalidate == 'runtime'
            ? 'Machine RPC runtime changed'
            : 'Machine RPC suspended';
        final result = expectLater(
          sync.machineRPC('machine-1', 'spawn-happy-session', {}),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              expected,
            ),
          ),
        );
        await machine.started.future;
        if (invalidate == 'runtime') {
          sync.testAdvanceRuntimeGeneration();
        } else {
          InvalidateSync.isBackgrounded = true;
        }
        machine.release.complete('encrypted-spawn');
        await result;
      },
    );
  }

  test('machine bash exposes disconnect as offline', () async {
    sync.testMachineRPCOverride = (machineId, method, params) async {
      throw const SocketNotConnectedException('rpc-call');
    };

    final response = await sync.machineBash(
      machineId: 'machine-1',
      command: 'pwd',
      cwd: '/',
    );

    expect(response.success, isFalse);
    expect(response.stderr, 'machine offline');
  });

  test(
    'machine bash keeps ACK timeout distinct from command failure',
    () async {
      sync.testMachineRPCOverride = (machineId, method, params) async {
        throw const SocketAckTimeoutException('rpc-call');
      };

      final response = await sync.machineBash(
        machineId: 'machine-1',
        command: 'pwd',
        cwd: '/',
      );

      expect(response.success, isFalse);
      expect(response.stderr, 'RPC ACK timeout');
    },
  );
}

class _DeferredMachineEncryption implements MachineEncryption {
  final started = Completer<void>();
  final release = Completer<String>();

  @override
  Future<String> encryptRaw(dynamic data) {
    started.complete();
    return release.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MachineEncryptionStore implements Encryption {
  _MachineEncryptionStore(this.machine);
  final MachineEncryption machine;

  @override
  MachineEncryption? getMachineEncryption(String machineId) => machine;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
