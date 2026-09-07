import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

void main() {
  final sync = Sync();

  tearDown(() {
    sync.testMachineRPCOverride = null;
  });

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
