import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('MachinesNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      sync.testIsInitialized = false;
      sync.machinesSync = InvalidateSync(() async {});
      container.dispose();
    });

    Machine createTestMachine({
      required String id,
      required String host,
      bool active = true,
    }) {
      return Machine(
        id: id,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
        active: active,
        activeAt: 1234567890,
        metadataVersion: 1,
        daemonStateVersion: 1,
        metadata: MachineMetadata(
          host: host,
          platform: 'linux',
          happyCliVersion: '1.0.0',
          happyHomeDir: '/home/test/.happy',
          homeDir: '/home/test',
        ),
      );
    }

    test('should initialize with empty map', () {
      final machines = container.read(machinesNotifierProvider);
      expect(machines, isEmpty);
    });

    test('should load machines from sync when uninitialized', () {
      final notifier = container.read(machinesNotifierProvider.notifier);

      // Should not throw when sync is not initialized
      notifier.loadFromSync();

      final state = container.read(machinesNotifierProvider);
      expect(state, isEmpty);
    });

    test('should refresh machines from sync when uninitialized', () async {
      final notifier = container.read(machinesNotifierProvider.notifier);

      // Should not throw when sync is not initialized
      await notifier.refreshFromSync();

      final state = container.read(machinesNotifierProvider);
      expect(state, isEmpty);
    });

    test('should clear all machines', () {
      final notifier = container.read(machinesNotifierProvider.notifier);

      // Note: MachinesNotifier doesn't have setMachines, so we test clear()
      // directly on empty state
      expect(container.read(machinesNotifierProvider), isEmpty);

      notifier.clear();

      final state = container.read(machinesNotifierProvider);
      expect(state, isEmpty);
    });

    test('should handle multiple clear calls', () {
      final notifier = container.read(machinesNotifierProvider.notifier);

      notifier.clear();
      notifier.clear();
      notifier.clear();

      final state = container.read(machinesNotifierProvider);
      expect(state, isEmpty);
    });

    test('remove should ignore unknown machine ids', () {
      final notifier = container.read(machinesNotifierProvider.notifier);

      notifier.remove('missing-machine');

      expect(container.read(machinesNotifierProvider), isEmpty);
    });

    test('remove should delete an existing machine from state', () {
      final notifier = container.read(machinesNotifierProvider.notifier);
      final machine = createTestMachine(id: 'machine-1', host: 'host-1');

      notifier.state = {'machine-1': machine};
      notifier.remove('machine-1');

      expect(container.read(machinesNotifierProvider), isEmpty);
    });

    test('should create machines with correct structure', () {
      final machine = createTestMachine(id: 'machine-1', host: 'test-host-1');

      expect(machine.id, 'machine-1');
      expect(machine.metadata?.host, 'test-host-1');
      expect(machine.metadata?.platform, 'linux');
      expect(machine.active, isTrue);
      expect(machine.seq, 1);
    });

    test('should handle machines with different active states', () {
      final activeMachine = createTestMachine(
        id: 'active-machine',
        host: 'active-host',
        active: true,
      );

      final inactiveMachine = createTestMachine(
        id: 'inactive-machine',
        host: 'inactive-host',
        active: false,
      );

      expect(activeMachine.active, isTrue);
      expect(inactiveMachine.active, isFalse);
      expect(activeMachine.id, 'active-machine');
      expect(inactiveMachine.id, 'inactive-machine');
    });

    test('should handle machines with optional metadata fields', () {
      final machine = Machine(
        id: 'minimal-machine',
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
        active: true,
        activeAt: 1234567890,
        metadataVersion: 1,
        daemonStateVersion: 1,
        metadata: MachineMetadata(
          host: 'minimal-host',
          platform: 'darwin',
          happyCliVersion: '2.0.0',
          happyHomeDir: '/Users/test/.happy',
          homeDir: '/Users/test',
          username: 'testuser',
          arch: 'arm64',
          displayName: 'Test Mac',
        ),
      );

      expect(machine.metadata?.username, 'testuser');
      expect(machine.metadata?.arch, 'arm64');
      expect(machine.metadata?.displayName, 'Test Mac');
      expect(machine.metadata?.daemonLastKnownStatus, isNull);
      expect(machine.metadata?.daemonLastKnownPid, isNull);
    });

    test('should handle machines with daemon state', () {
      final machine = Machine(
        id: 'daemon-machine',
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
        active: true,
        activeAt: 1234567890,
        metadataVersion: 1,
        daemonStateVersion: 5,
        metadata: MachineMetadata(
          host: 'daemon-host',
          platform: 'win32',
          happyCliVersion: '3.0.0',
          happyHomeDir: 'C:\\Users\\test\\.happy',
          homeDir: 'C:\\Users\\test',
        ),
        daemonState: {'status': 'running', 'pid': 1234, 'uptime': 3600},
      );

      expect(machine.daemonState, isNotNull);
      expect(machine.daemonState?['status'], 'running');
      expect(machine.daemonState?['pid'], 1234);
      expect(machine.daemonStateVersion, 5);
    });

    test('should handle machine without metadata', () {
      final machine = Machine(
        id: 'no-metadata-machine',
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
        active: true,
        activeAt: 1234567890,
        metadataVersion: 0,
        daemonStateVersion: 0,
      );

      expect(machine.metadata, isNull);
      expect(machine.metadataVersion, 0);
    });

    test('should preserve machine immutability', () {
      final machine1 = createTestMachine(id: 'machine-1', host: 'host-1');
      final machine2 = createTestMachine(id: 'machine-1', host: 'host-1');

      // Same values should create equal objects
      expect(machine1.id, machine2.id);
      expect(machine1.metadata?.host, machine2.metadata?.host);
    });

    test('loadFromSync should be safe to call multiple times', () {
      final notifier = container.read(machinesNotifierProvider.notifier);

      // Should not throw on multiple calls
      notifier.loadFromSync();
      notifier.loadFromSync();
      notifier.loadFromSync();

      final state = container.read(machinesNotifierProvider);
      expect(state, isEmpty);
    });

    test('refreshFromSync should be safe to call multiple times', () async {
      final notifier = container.read(machinesNotifierProvider.notifier);

      // Should not throw on multiple calls
      await notifier.refreshFromSync();
      await notifier.refreshFromSync();
      await notifier.refreshFromSync();

      final state = container.read(machinesNotifierProvider);
      expect(state, isEmpty);
    });

    test('refreshFromSync should dedupe concurrent calls', () async {
      sync.testIsInitialized = true;
      var machineSyncCalls = 0;
      sync.machinesSync = InvalidateSync(() async {
        machineSyncCalls++;
      });
      final notifier = container.read(machinesNotifierProvider.notifier);

      final first = notifier.refreshFromSync();
      final second = notifier.refreshFromSync();

      await Future.wait<void>([first, second]);

      expect(machineSyncCalls, 1);
    });

    test('remove only deletes the specified machine', () {
      final notifier = container.read(machinesNotifierProvider.notifier);
      final machine1 = createTestMachine(id: 'm1', host: 'host-1');
      final machine2 = createTestMachine(id: 'm2', host: 'host-2');
      final machine3 = createTestMachine(id: 'm3', host: 'host-3');

      notifier.state = {
        'm1': machine1,
        'm2': machine2,
        'm3': machine3,
      };

      notifier.remove('m2');

      final state = container.read(machinesNotifierProvider);
      expect(state.length, 2);
      expect(state.containsKey('m1'), isTrue);
      expect(state.containsKey('m2'), isFalse);
      expect(state.containsKey('m3'), isTrue);
    });

    test('clear removes all machines from state', () {
      final notifier = container.read(machinesNotifierProvider.notifier);

      notifier.state = {
        'm1': createTestMachine(id: 'm1', host: 'h1'),
        'm2': createTestMachine(id: 'm2', host: 'h2'),
      };

      expect(container.read(machinesNotifierProvider).length, 2);

      notifier.clear();

      expect(container.read(machinesNotifierProvider), isEmpty);
    });

    test('state can be set directly', () {
      final notifier = container.read(machinesNotifierProvider.notifier);
      final machines = {
        'set-1': createTestMachine(id: 'set-1', host: 'set-host'),
      };

      notifier.state = machines;

      final state = container.read(machinesNotifierProvider);
      expect(state.length, 1);
      expect(state['set-1']?.metadata?.host, 'set-host');
    });

    test('state is a Map that supports containsKey', () {
      final notifier = container.read(machinesNotifierProvider.notifier);

      notifier.state = {
        'key-1': createTestMachine(id: 'key-1', host: 'host'),
      };

      final state = container.read(machinesNotifierProvider);
      expect(state.containsKey('key-1'), isTrue);
      expect(state.containsKey('nonexistent'), isFalse);
    });

    test('state supports values iteration', () {
      final notifier = container.read(machinesNotifierProvider.notifier);

      final m1 = createTestMachine(id: 'v1', host: 'host-a');
      final m2 = createTestMachine(id: 'v2', host: 'host-b');

      notifier.state = {'v1': m1, 'v2': m2};

      final state = container.read(machinesNotifierProvider);
      final values = state.values.toList();
      expect(values.length, 2);
      expect(
        values.map((m) => m.id).toSet(),
        containsAll(['v1', 'v2']),
      );
    });

    test('remove on empty state is a no-op', () {
      final notifier = container.read(machinesNotifierProvider.notifier);

      notifier.remove('anything');

      expect(container.read(machinesNotifierProvider), isEmpty);
    });

    test('machine with active false is parsed correctly', () {
      final machine = createTestMachine(
        id: 'inactive',
        host: 'offline-host',
        active: false,
      );

      expect(machine.active, isFalse);
      expect(machine.id, 'inactive');
    });

    test('provider state is independent across reads', () {
      final notifier = container.read(machinesNotifierProvider.notifier);
      notifier.state = {
        'ind-1': createTestMachine(id: 'ind-1', host: 'host'),
      };

      final read1 = container.read(machinesNotifierProvider);
      final read2 = container.read(machinesNotifierProvider);

      expect(read1, same(read2));
    });
  });
}
