import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';

void main() {
  group('MachineMetadata', () {
    group('fromJson', () {
      test('parses all fields from JSON', () {
        final json = <String, dynamic>{
          'host': 'my-host',
          'platform': 'linux',
          'happyCliVersion': '1.2.3',
          'happyHomeDir': '/home/user/.happy',
          'homeDir': '/home/user',
          'username': 'testuser',
          'arch': 'x86_64',
          'displayName': 'My Machine',
          'daemonLastKnownStatus': 'running',
          'daemonLastKnownPid': 1234,
          'shutdownRequestedAt': 9876543210,
          'shutdownSource': 'manual',
          'spawnBackends': ['local', 'kubernetes'],
          'defaultSpawnBackend': 'kubernetes',
          'sandboxBackend': 'boxy',
          'sandboxAvailable': true,
          'sandboxEnabled': true,
          'sandboxReason': null,
        };

        final metadata = MachineMetadata.fromJson(json);

        expect(metadata.host, 'my-host');
        expect(metadata.platform, 'linux');
        expect(metadata.happyCliVersion, '1.2.3');
        expect(metadata.happyHomeDir, '/home/user/.happy');
        expect(metadata.homeDir, '/home/user');
        expect(metadata.username, 'testuser');
        expect(metadata.arch, 'x86_64');
        expect(metadata.displayName, 'My Machine');
        expect(metadata.daemonLastKnownStatus, 'running');
        expect(metadata.daemonLastKnownPid, 1234);
        expect(metadata.shutdownRequestedAt, 9876543210);
        expect(metadata.shutdownSource, 'manual');
        expect(metadata.spawnBackends, ['local', 'kubernetes']);
        expect(metadata.defaultSpawnBackend, 'kubernetes');
        expect(metadata.sandboxBackend, 'boxy');
        expect(metadata.sandboxAvailable, isTrue);
        expect(metadata.sandboxEnabled, isTrue);
        expect(metadata.sandboxReason, isNull);
      });

      test('handles null and missing fields', () {
        final metadata = MachineMetadata.fromJson({});

        expect(metadata.host, isNull);
        expect(metadata.platform, isNull);
        expect(metadata.happyCliVersion, isNull);
        expect(metadata.happyHomeDir, isNull);
        expect(metadata.homeDir, isNull);
        expect(metadata.username, isNull);
        expect(metadata.arch, isNull);
        expect(metadata.displayName, isNull);
        expect(metadata.daemonLastKnownStatus, isNull);
        expect(metadata.daemonLastKnownPid, isNull);
        expect(metadata.shutdownRequestedAt, isNull);
        expect(metadata.shutdownSource, isNull);
        expect(metadata.spawnBackends, isNull);
        expect(metadata.defaultSpawnBackend, isNull);
        expect(metadata.sandboxBackend, isNull);
        expect(metadata.sandboxAvailable, isNull);
        expect(metadata.sandboxEnabled, isNull);
        expect(metadata.sandboxReason, isNull);
      });

      test('filters non-string spawn backend values', () {
        final metadata = MachineMetadata.fromJson({
          'spawnBackends': ['local', 1, 'kubernetes', null],
        });

        expect(metadata.spawnBackends, ['local', 'kubernetes']);
      });

      test('handles double values for int fields', () {
        final json = <String, dynamic>{
          'daemonLastKnownPid': 1234.0,
          'shutdownRequestedAt': 9876543210.0,
        };

        final metadata = MachineMetadata.fromJson(json);

        expect(metadata.daemonLastKnownPid, 1234);
        expect(metadata.shutdownRequestedAt, 9876543210);
      });
    });

    group('toJson', () {
      test('serializes all fields to JSON', () {
        final metadata = MachineMetadata(
          host: 'my-host',
          platform: 'darwin',
          happyCliVersion: '2.0.0',
          happyHomeDir: '/Users/test/.happy',
          homeDir: '/Users/test',
          username: 'testuser',
          arch: 'arm64',
          displayName: 'MacBook',
          daemonLastKnownStatus: 'stopped',
          daemonLastKnownPid: 5678,
          shutdownRequestedAt: 1111111111,
          shutdownSource: 'auto',
          spawnBackends: ['local', 'kubernetes'],
          defaultSpawnBackend: 'local',
          sandboxBackend: 'boxy',
          sandboxAvailable: false,
          sandboxEnabled: false,
          sandboxReason: 'boxy doctor failed',
        );

        final json = metadata.toJson();

        expect(json['host'], 'my-host');
        expect(json['platform'], 'darwin');
        expect(json['happyCliVersion'], '2.0.0');
        expect(json['happyHomeDir'], '/Users/test/.happy');
        expect(json['homeDir'], '/Users/test');
        expect(json['username'], 'testuser');
        expect(json['arch'], 'arm64');
        expect(json['displayName'], 'MacBook');
        expect(json['daemonLastKnownStatus'], 'stopped');
        expect(json['daemonLastKnownPid'], 5678);
        expect(json['shutdownRequestedAt'], 1111111111);
        expect(json['shutdownSource'], 'auto');
        expect(json['spawnBackends'], ['local', 'kubernetes']);
        expect(json['defaultSpawnBackend'], 'local');
        expect(json['sandboxBackend'], 'boxy');
        expect(json['sandboxAvailable'], isFalse);
        expect(json['sandboxEnabled'], isFalse);
        expect(json['sandboxReason'], 'boxy doctor failed');
      });

      test('includes null values in output', () {
        final metadata = MachineMetadata(
          host: 'test-host',
          platform: 'linux',
          happyCliVersion: '1.0.0',
          happyHomeDir: '/home/.happy',
          homeDir: '/home',
        );

        final json = metadata.toJson();

        expect(json['username'], isNull);
        expect(json['arch'], isNull);
        expect(json['displayName'], isNull);
      });
    });

    group('equality', () {
      test('equal instances compare as equal', () {
        final a = MachineMetadata(
          host: 'host',
          platform: 'linux',
          happyCliVersion: '1.0.0',
          happyHomeDir: '/home/.happy',
          homeDir: '/home',
          username: 'user',
          arch: 'x86_64',
          displayName: 'Machine',
        );
        final b = MachineMetadata(
          host: 'host',
          platform: 'linux',
          happyCliVersion: '1.0.0',
          happyHomeDir: '/home/.happy',
          homeDir: '/home',
          username: 'user',
          arch: 'x86_64',
          displayName: 'Machine',
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different instances compare as not equal', () {
        final a = MachineMetadata(host: 'host-a');
        final b = MachineMetadata(host: 'host-b');

        expect(a, isNot(equals(b)));
      });

      test('identical instance returns true', () {
        final a = MachineMetadata(host: 'host');
        expect(a, equals(a));
      });
    });
  });

  group('Machine', () {
    group('fromJson', () {
      test('parses all required fields', () {
        final json = <String, dynamic>{
          'id': 'machine-123',
          'seq': 5,
          'createdAt': 1000000000,
          'updatedAt': 2000000000,
          'active': true,
          'activeAt': 3000000000,
          'metadataVersion': 2,
          'daemonStateVersion': 3,
        };

        final machine = Machine.fromJson(json);

        expect(machine.id, 'machine-123');
        expect(machine.seq, 5);
        expect(machine.createdAt, 1000000000);
        expect(machine.updatedAt, 2000000000);
        expect(machine.active, isTrue);
        expect(machine.activeAt, 3000000000);
        expect(machine.metadataVersion, 2);
        expect(machine.daemonStateVersion, 3);
        expect(machine.metadata, isNull);
        expect(machine.daemonState, isNull);
      });

      test('parses nested metadata', () {
        final json = <String, dynamic>{
          'id': 'machine-456',
          'seq': 1,
          'createdAt': 1000000000,
          'updatedAt': 1000000000,
          'active': false,
          'activeAt': 1000000000,
          'metadataVersion': 1,
          'daemonStateVersion': 0,
          'metadata': <String, dynamic>{
            'host': 'test-host',
            'platform': 'win32',
            'happyCliVersion': '3.0.0',
            'happyHomeDir': r'C:\\.happy',
            'homeDir': r'C:\',
          },
        };

        final machine = Machine.fromJson(json);

        expect(machine.metadata, isNotNull);
        expect(machine.metadata?.host, 'test-host');
        expect(machine.metadata?.platform, 'win32');
      });

      test('parses daemon state map', () {
        final json = <String, dynamic>{
          'id': 'machine-789',
          'seq': 1,
          'createdAt': 1000000000,
          'updatedAt': 1000000000,
          'active': true,
          'activeAt': 1000000000,
          'metadataVersion': 0,
          'daemonStateVersion': 1,
          'daemonState': <String, dynamic>{'status': 'idle', 'pid': 9999},
        };

        final machine = Machine.fromJson(json);

        expect(machine.daemonState, isNotNull);
        expect(machine.daemonState?['status'], 'idle');
        expect(machine.daemonState?['pid'], 9999);
      });

      test('throws on missing required fields', () {
        expect(
          () => Machine.fromJson(<String, dynamic>{}),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on wrong type for id', () {
        final json = <String, dynamic>{
          'id': 123,
          'seq': 1,
          'createdAt': 1,
          'updatedAt': 1,
          'active': true,
          'activeAt': 1,
          'metadataVersion': 0,
          'daemonStateVersion': 0,
        };

        expect(() => Machine.fromJson(json), throwsA(isA<FormatException>()));
      });

      test('throws on wrong type for active', () {
        final json = <String, dynamic>{
          'id': 'm1',
          'seq': 1,
          'createdAt': 1,
          'updatedAt': 1,
          'active': 'yes',
          'activeAt': 1,
          'metadataVersion': 0,
          'daemonStateVersion': 0,
        };

        expect(() => Machine.fromJson(json), throwsA(isA<FormatException>()));
      });

      test('converts double values to int for numeric fields', () {
        final json = <String, dynamic>{
          'id': 'm1',
          'seq': 1.0,
          'createdAt': 1000.0,
          'updatedAt': 2000.0,
          'active': true,
          'activeAt': 3000.0,
          'metadataVersion': 1.0,
          'daemonStateVersion': 1.0,
        };

        final machine = Machine.fromJson(json);

        expect(machine.seq, 1);
        expect(machine.createdAt, 1000);
        expect(machine.updatedAt, 2000);
        expect(machine.activeAt, 3000);
        expect(machine.metadataVersion, 1);
        expect(machine.daemonStateVersion, 1);
      });
    });

    group('toJson', () {
      test('serializes all fields to JSON', () {
        final machine = Machine(
          id: 'machine-abc',
          seq: 10,
          createdAt: 1111111111,
          updatedAt: 2222222222,
          active: true,
          activeAt: 3333333333,
          metadataVersion: 1,
          daemonStateVersion: 2,
          metadata: MachineMetadata(
            host: 'json-host',
            platform: 'linux',
            happyCliVersion: '1.0.0',
            happyHomeDir: '/home/.happy',
            homeDir: '/home',
          ),
          daemonState: {'status': 'running'},
        );

        final json = machine.toJson();

        expect(json['id'], 'machine-abc');
        expect(json['seq'], 10);
        expect(json['createdAt'], 1111111111);
        expect(json['updatedAt'], 2222222222);
        expect(json['active'], true);
        expect(json['activeAt'], 3333333333);
        expect(json['metadataVersion'], 1);
        expect(json['daemonStateVersion'], 2);
        expect(json['metadata'], isA<Map<String, dynamic>>());
        expect(json['daemonState'], isA<Map<String, dynamic>>());
      });

      test('roundtrips through fromJson/toJson', () {
        final original = Machine(
          id: 'roundtrip-test',
          seq: 42,
          createdAt: 1000000,
          updatedAt: 2000000,
          active: false,
          activeAt: 3000000,
          metadataVersion: 3,
          daemonStateVersion: 4,
          metadata: MachineMetadata(
            host: 'rt-host',
            platform: 'darwin',
            happyCliVersion: '5.0.0',
            happyHomeDir: '/Users/rt/.happy',
            homeDir: '/Users/rt',
            username: 'rt-user',
            arch: 'arm64',
            displayName: 'Roundtrip Machine',
          ),
          daemonState: {'key': 'value', 'count': 7},
        );

        final json = original.toJson();
        final roundtripped = Machine.fromJson(json);

        expect(roundtripped, equals(original));
      });
    });

    group('online status', () {
      Machine machine({required bool active, required int activeAt}) {
        return Machine(
          id: 'status-machine',
          seq: 1,
          createdAt: 1,
          updatedAt: 1,
          active: active,
          activeAt: activeAt,
          metadataVersion: 0,
          daemonStateVersion: 0,
        );
      }

      test('requires active flag and fresh heartbeat', () {
        const now = 1_000_000;

        expect(
          machine(
            active: true,
            activeAt: now - machineOnlineThresholdMs + 1,
          ).isOnlineAt(now),
          isTrue,
        );
        expect(
          machine(
            active: true,
            activeAt: now - machineOnlineThresholdMs,
          ).isOnlineAt(now),
          isFalse,
        );
        expect(machine(active: false, activeAt: now).isOnlineAt(now), isFalse);
      });

      test('reports stale only for active machines with expired heartbeat', () {
        const now = 1_000_000;

        expect(
          machine(
            active: true,
            activeAt: now - machineOnlineThresholdMs,
          ).isStaleAt(now),
          isTrue,
        );
        expect(machine(active: false, activeAt: 1).isStaleAt(now), isFalse);
      });
    });

    group('selection helpers', () {
      Machine machine({
        required String id,
        required int activeAt,
        String? displayName,
        String? host,
        bool active = true,
      }) {
        return Machine(
          id: id,
          seq: 1,
          createdAt: 1,
          updatedAt: 1,
          active: active,
          activeAt: activeAt,
          metadataVersion: 0,
          daemonStateVersion: 0,
          metadata: MachineMetadata(displayName: displayName, host: host),
        );
      }

      test('display label prefers display name, host, then id', () {
        expect(
          machine(
            id: 'id-1',
            displayName: 'Display',
            host: 'host.local',
            activeAt: 1,
          ).displayLabel,
          'Display',
        );
        expect(
          machine(id: 'id-2', host: 'host.local', activeAt: 1).displayLabel,
          'host.local',
        );
        expect(machine(id: 'id-3', activeAt: 1).displayLabel, 'id-3');
      });

      test('sorts online machines before offline machines by label', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machines = [
          machine(
            id: 'offline',
            displayName: 'Alpha Offline',
            active: false,
            activeAt: now,
          ),
          machine(id: 'z-online', displayName: 'Zed Online', activeAt: now),
          machine(id: 'a-online', displayName: 'Alpha Online', activeAt: now),
        ]..sort((a, b) => compareMachinesByAvailabilityAt(now, a, b));

        expect(machines.map((machine) => machine.id), [
          'a-online',
          'z-online',
          'offline',
        ]);
      });
    });

    group('equality', () {
      test('equal machines compare as equal', () {
        final a = Machine(
          id: 'eq-test',
          seq: 1,
          createdAt: 100,
          updatedAt: 200,
          active: true,
          activeAt: 300,
          metadataVersion: 1,
          daemonStateVersion: 1,
        );
        final b = Machine(
          id: 'eq-test',
          seq: 1,
          createdAt: 100,
          updatedAt: 200,
          active: true,
          activeAt: 300,
          metadataVersion: 1,
          daemonStateVersion: 1,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different ids are not equal', () {
        final a = Machine(
          id: 'a',
          seq: 1,
          createdAt: 1,
          updatedAt: 1,
          active: true,
          activeAt: 1,
          metadataVersion: 0,
          daemonStateVersion: 0,
        );
        final b = Machine(
          id: 'b',
          seq: 1,
          createdAt: 1,
          updatedAt: 1,
          active: true,
          activeAt: 1,
          metadataVersion: 0,
          daemonStateVersion: 0,
        );

        expect(a, isNot(equals(b)));
      });

      test('identical instance returns true', () {
        final a = Machine(
          id: 'same',
          seq: 1,
          createdAt: 1,
          updatedAt: 1,
          active: true,
          activeAt: 1,
          metadataVersion: 0,
          daemonStateVersion: 0,
        );

        expect(a, equals(a));
      });
    });
  });

  group('GitStatus', () {
    group('fromJson', () {
      test('parses all fields from JSON', () {
        final json = <String, dynamic>{
          'branch': 'main',
          'isDirty': true,
          'modifiedCount': 3,
          'untrackedCount': 2,
          'stagedCount': 1,
          'lastUpdatedAt': 1234567890,
          'stagedLinesAdded': 10,
          'stagedLinesRemoved': 5,
          'unstagedLinesAdded': 8,
          'unstagedLinesRemoved': 3,
          'linesAdded': 18,
          'linesRemoved': 8,
          'linesChanged': 26,
          'upstreamBranch': 'origin/main',
          'aheadCount': 2,
          'behindCount': 0,
          'stashCount': 1,
        };

        final status = GitStatus.fromJson(json);

        expect(status.branch, 'main');
        expect(status.isDirty, isTrue);
        expect(status.modifiedCount, 3);
        expect(status.untrackedCount, 2);
        expect(status.stagedCount, 1);
        expect(status.lastUpdatedAt, 1234567890);
        expect(status.stagedLinesAdded, 10);
        expect(status.stagedLinesRemoved, 5);
        expect(status.unstagedLinesAdded, 8);
        expect(status.unstagedLinesRemoved, 3);
        expect(status.linesAdded, 18);
        expect(status.linesRemoved, 8);
        expect(status.linesChanged, 26);
        expect(status.upstreamBranch, 'origin/main');
        expect(status.aheadCount, 2);
        expect(status.behindCount, 0);
        expect(status.stashCount, 1);
      });

      test('defaults optional line counts to 0', () {
        final json = <String, dynamic>{
          'branch': 'dev',
          'isDirty': false,
          'modifiedCount': 0,
          'untrackedCount': 0,
          'stagedCount': 0,
          'lastUpdatedAt': 0,
        };

        final status = GitStatus.fromJson(json);

        expect(status.stagedLinesAdded, 0);
        expect(status.stagedLinesRemoved, 0);
        expect(status.unstagedLinesAdded, 0);
        expect(status.unstagedLinesRemoved, 0);
        expect(status.linesAdded, 0);
        expect(status.linesRemoved, 0);
        expect(status.linesChanged, 0);
        expect(status.upstreamBranch, isNull);
        expect(status.aheadCount, isNull);
        expect(status.behindCount, isNull);
        expect(status.stashCount, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields to JSON', () {
        final status = GitStatus(
          branch: 'feature/test',
          isDirty: true,
          modifiedCount: 1,
          untrackedCount: 0,
          stagedCount: 2,
          lastUpdatedAt: 999999,
          stagedLinesAdded: 50,
          stagedLinesRemoved: 25,
          unstagedLinesAdded: 10,
          unstagedLinesRemoved: 5,
          linesAdded: 60,
          linesRemoved: 30,
          linesChanged: 90,
          upstreamBranch: 'origin/feature/test',
          aheadCount: 3,
          behindCount: 1,
          stashCount: 2,
        );

        final json = status.toJson();

        expect(json['branch'], 'feature/test');
        expect(json['isDirty'], true);
        expect(json['modifiedCount'], 1);
        expect(json['aheadCount'], 3);
        expect(json['behindCount'], 1);
        expect(json['stashCount'], 2);
      });
    });

    group('copyWith', () {
      test('copies with overridden fields', () {
        final original = GitStatus(
          branch: 'main',
          isDirty: false,
          modifiedCount: 0,
          untrackedCount: 0,
          stagedCount: 0,
          lastUpdatedAt: 1000,
        );

        final modified = original.copyWith(
          branch: 'develop',
          isDirty: true,
          modifiedCount: 5,
        );

        expect(modified.branch, 'develop');
        expect(modified.isDirty, true);
        expect(modified.modifiedCount, 5);
        // Unchanged fields preserved
        expect(modified.untrackedCount, 0);
        expect(modified.stagedCount, 0);
        expect(modified.lastUpdatedAt, 1000);
      });

      test('copyWith with no args returns equal copy', () {
        final original = GitStatus(
          branch: 'main',
          isDirty: true,
          modifiedCount: 1,
          untrackedCount: 2,
          stagedCount: 3,
          lastUpdatedAt: 500,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
      });
    });

    group('equality', () {
      test('equal instances compare as equal', () {
        final a = GitStatus(
          branch: 'main',
          isDirty: false,
          modifiedCount: 0,
          untrackedCount: 0,
          stagedCount: 0,
          lastUpdatedAt: 100,
        );
        final b = GitStatus(
          branch: 'main',
          isDirty: false,
          modifiedCount: 0,
          untrackedCount: 0,
          stagedCount: 0,
          lastUpdatedAt: 100,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different branches are not equal', () {
        final a = GitStatus(
          branch: 'main',
          isDirty: false,
          modifiedCount: 0,
          untrackedCount: 0,
          stagedCount: 0,
          lastUpdatedAt: 100,
        );
        final b = GitStatus(
          branch: 'develop',
          isDirty: false,
          modifiedCount: 0,
          untrackedCount: 0,
          stagedCount: 0,
          lastUpdatedAt: 100,
        );

        expect(a, isNot(equals(b)));
      });
    });
  });
}
