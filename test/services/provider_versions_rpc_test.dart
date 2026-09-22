import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/models/provider_versions.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

void main() {
  final sync = Sync();

  tearDown(() {
    sync.testMachineRPCOverride = null;
  });

  test(
    'checks versions on the selected machine with refresh by default',
    () async {
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(machineId, 'connected-machine');
        expect(method, 'get-provider-versions');
        expect(params, {'refresh': true});
        return <String, dynamic>{
          'success': true,
          'providers': [
            {
              'provider': 'codex',
              'installed': true,
              'version': '1.0.0',
              'latestVersion': '1.1.0',
              'updateAvailable': true,
              'canUpdate': true,
            },
          ],
        };
      };

      final response = await sync.machineGetProviderVersions(
        machineId: 'connected-machine',
      );

      expect(response.success, isTrue);
      expect(response.providers.single.provider, CodingAgent.codex);
      expect(response.providers.single.version, '1.0.0');
      expect(response.providers.single.latestVersion, '1.1.0');
      expect(response.providers.single.updateAvailable, isTrue);
      expect(response.providers.single.canUpdate, isTrue);
    },
  );

  test(
    'polls update status without requesting another version lookup',
    () async {
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(machineId, 'second-machine');
        expect(method, 'get-provider-versions');
        expect(params, {'refresh': false});
        return <String, dynamic>{
          'success': true,
          'providers': [
            {'provider': 'claude', 'updateStatus': 'running'},
          ],
        };
      };

      final response = await sync.machineGetProviderVersions(
        machineId: 'second-machine',
        refresh: false,
      );

      expect(response.providers.single.isUpdating, isTrue);
    },
  );

  for (final provider in CodingAgent.values) {
    test('requests only the selected ${provider.wireValue} update', () async {
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(machineId, 'update-machine');
        expect(method, 'update-provider');
        expect(params, {'provider': provider.wireValue});
        return <String, dynamic>{
          'success': true,
          'provider': {
            'provider': provider.wireValue,
            'installed': true,
            'updateStatus': 'running',
          },
        };
      };

      final response = await sync.machineUpdateProvider(
        machineId: 'update-machine',
        provider: provider,
      );

      expect(response.success, isTrue);
      expect(response.provider?.provider, provider);
      expect(response.provider?.isUpdating, isTrue);
    });
  }

  test('preserves a daemon version-check rejection', () async {
    sync.testMachineRPCOverride = (machineId, method, params) async =>
        <String, dynamic>{'success': false, 'error': 'Check unavailable'};

    final response = await sync.machineGetProviderVersions(
      machineId: 'connected-machine',
    );

    expect(response.success, isFalse);
    expect(response.error, 'Check unavailable');
    expect(response.providers, isEmpty);
  });

  test('preserves a daemon update rejection', () async {
    sync.testMachineRPCOverride = (machineId, method, params) async =>
        <String, dynamic>{'success': false, 'error': 'Update already running'};

    final response = await sync.machineUpdateProvider(
      machineId: 'connected-machine',
      provider: CodingAgent.claude,
    );

    expect(response.success, isFalse);
    expect(response.error, 'Update already running');
    expect(response.provider, isNull);
  });

  test('version checks propagate disconnect errors to the screen', () async {
    const failure = SocketNotConnectedException('rpc-call');
    sync.testMachineRPCOverride = (machineId, method, params) async {
      throw failure;
    };

    await expectLater(
      sync.machineGetProviderVersions(machineId: 'offline-machine'),
      throwsA(same(failure)),
    );
  });

  test(
    'update requests propagate timeouts without retrying the update',
    () async {
      const failure = SocketAckTimeoutException('rpc-call');
      var calls = 0;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        calls += 1;
        throw failure;
      };

      await expectLater(
        sync.machineUpdateProvider(
          machineId: 'connected-machine',
          provider: CodingAgent.codex,
        ),
        throwsA(same(failure)),
      );
      expect(calls, 1);
    },
  );
}
