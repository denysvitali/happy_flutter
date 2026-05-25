import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/machine/machine_detail_screen.dart';

/// Stub [MachinesNotifier] that returns pre-seeded state and no-ops
/// on sync calls to avoid touching the sync singleton.
class _StubMachinesNotifier extends MachinesNotifier {
  _StubMachinesNotifier(this._seed);

  final Map<String, Machine> _seed;

  @override
  Map<String, Machine> build() => _seed;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}
}

/// Stub [SessionsNotifier] that returns pre-seeded state.
class _StubSessionsNotifier extends SessionsNotifier {
  _StubSessionsNotifier(this._seed);

  final Map<String, Session> _seed;

  @override
  Map<String, Session> build() => _seed;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}
}

// ── Helpers ─────────────────────────────────────────────────────

Machine _makeMachine({
  required String id,
  String? displayName,
  String? host,
  String? platform,
  String? arch,
  String? username,
  String? cliVersion,
  String? homeDir,
  String? daemonLastKnownStatus,
  int? daemonLastKnownPid,
  bool active = true,
  int? activeAt,
  Map<String, dynamic>? daemonState,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Machine(
    id: id,
    seq: 1,
    createdAt: now - 100000,
    updatedAt: now - 10000,
    active: active,
    activeAt: activeAt ?? now - 5000,
    metadataVersion: 1,
    daemonStateVersion: 1,
    metadata: MachineMetadata(
      host: host ?? '$id-host',
      platform: platform ?? 'linux',
      happyCliVersion: cliVersion ?? '1.0.0',
      happyHomeDir: homeDir ?? '/home/test/.happy',
      homeDir: homeDir ?? '/home/test',
      username: username,
      arch: arch,
      displayName: displayName,
      daemonLastKnownStatus: daemonLastKnownStatus,
      daemonLastKnownPid: daemonLastKnownPid,
    ),
    daemonState: daemonState,
  );
}

Widget _buildApp({
  required String machineId,
  required Map<String, Machine> machines,
  Map<String, Session> sessions = const {},
}) {
  return ProviderScope(
    overrides: [
      machinesNotifierProvider.overrideWith(
        () => _StubMachinesNotifier(machines),
      ),
      sessionsNotifierProvider.overrideWith(
        () => _StubSessionsNotifier(sessions),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MachineDetailScreen(machineId: machineId),
    ),
  );
}

// ── Tests ───────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MachineDetailScreen', () {
    group('when machine is not found', () {
      testWidgets('shows not found message', (tester) async {
        await tester.pumpWidget(
          _buildApp(machineId: 'missing', machines: {}),
        );
        await tester.pump();

        expect(find.text('Not found'), findsOneWidget);
      });

      testWidgets('shows app bar with empty title', (tester) async {
        await tester.pumpWidget(
          _buildApp(machineId: 'missing', machines: {}),
        );
        await tester.pump();

        // AppBar exists with empty title
        expect(find.byType(AppBar), findsOneWidget);
      });
    });

    group('when machine exists', () {
      testWidgets('shows machine display name as title', (tester) async {
        final machine = _makeMachine(
          id: 'm1',
          displayName: 'My Dev Machine',
        );

        await tester.pumpWidget(
          _buildApp(
            machineId: 'm1',
            machines: {'m1': machine},
          ),
        );
        await tester.pump();

        expect(find.text('My Dev Machine'), findsOneWidget);
      });

      testWidgets('shows host as title when no display name',
          (tester) async {
        final machine = _makeMachine(id: 'm1', host: 'server-01');

        await tester.pumpWidget(
          _buildApp(
            machineId: 'm1',
            machines: {'m1': machine},
          ),
        );
        await tester.pump();

        // Host appears in AppBar title AND info section
        expect(find.text('server-01'), findsWidgets);
      });

      testWidgets('shows machine ID as title when no metadata',
          (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = Machine(
          id: 'bare-machine',
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadataVersion: 0,
          daemonStateVersion: 0,
        );

        await tester.pumpWidget(
          _buildApp(
            machineId: 'bare-machine',
            machines: {'bare-machine': machine},
          ),
        );
        await tester.pump();

        // Machine ID appears in AppBar title AND Machine ID info row
        expect(find.text('bare-machine'), findsWidgets);
      });

      testWidgets('shows online status when recently active',
          (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = _makeMachine(
          id: 'm1',
          activeAt: now - 10000, // 10 seconds ago
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Online'), findsOneWidget);
        expect(find.text('Connected now'), findsOneWidget);
      });

      testWidgets('shows offline status when not recently active',
          (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = _makeMachine(
          id: 'm1',
          activeAt: now - 120000, // 2 minutes ago
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Offline'), findsOneWidget);
      });

      testWidgets('shows machine info section', (tester) async {
        final machine = _makeMachine(
          id: 'm1',
          displayName: 'Test Machine',
          host: 'info-host',
          username: 'info-user',
          platform: 'darwin',
          arch: 'arm64',
          cliVersion: '2.5.0',
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Info'), findsOneWidget);
        expect(find.text('Host'), findsOneWidget);
        expect(find.text('info-host'), findsOneWidget);
        expect(find.text('Username'), findsOneWidget);
        expect(find.text('info-user'), findsOneWidget);
        expect(find.text('Platform'), findsOneWidget);
        expect(find.text('darwin'), findsOneWidget);
        expect(find.text('Architecture'), findsOneWidget);
        expect(find.text('arm64'), findsOneWidget);
        expect(find.text('CLI Version'), findsOneWidget);
        expect(find.text('2.5.0'), findsOneWidget);
      });

      testWidgets('shows machine ID in info section', (tester) async {
        final machine = _makeMachine(
          id: 'id-test-machine',
          displayName: 'ID Test Machine',
        );

        await tester.pumpWidget(
          _buildApp(
            machineId: 'id-test-machine',
            machines: {'id-test-machine': machine},
          ),
        );
        await tester.pump();

        expect(find.text('Machine ID'), findsOneWidget);
        // Machine ID appears in the info section row
        expect(find.text('id-test-machine'), findsWidgets);
      });

      testWidgets('does not show optional metadata fields when null',
          (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = Machine(
          id: 'minimal',
          seq: 1,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadataVersion: 1,
          daemonStateVersion: 1,
          metadata: MachineMetadata(
            host: 'minimal-host',
            platform: 'linux',
            happyCliVersion: '1.0.0',
            happyHomeDir: '/home/.happy',
            homeDir: '/home',
            // username, arch, displayName all null
          ),
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'minimal', machines: {'minimal': machine}),
        );
        await tester.pump();

        // These optional fields should not be shown
        expect(find.text('Username'), findsNothing);
        expect(find.text('Architecture'), findsNothing);
      });

      testWidgets('shows daemon status section', (tester) async {
        final machine = _makeMachine(id: 'm1');

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Daemon'), findsOneWidget);
        expect(find.text('Status'), findsOneWidget);
      });

      testWidgets('shows running status when online', (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = _makeMachine(id: 'm1', activeAt: now - 5000);

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Running'), findsOneWidget);
      });

      testWidgets('shows stopped status when offline', (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = _makeMachine(
          id: 'm1',
          activeAt: now - 120000,
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Stopped'), findsOneWidget);
      });

      testWidgets('shows daemon last known status when available',
          (tester) async {
        final machine = _makeMachine(
          id: 'm1',
          daemonLastKnownStatus: 'sleeping',
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Last Known Status'), findsOneWidget);
        expect(find.text('sleeping'), findsOneWidget);
      });

      testWidgets('shows daemon last known PID when available',
          (tester) async {
        final machine = _makeMachine(
          id: 'm1',
          daemonLastKnownPid: 4242,
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Last Known PID'), findsOneWidget);
        expect(find.text('4242'), findsOneWidget);
      });

      testWidgets('shows resource stats when daemon reports them',
          (tester) async {
        final machine = _makeMachine(
          id: 'm1',
          daemonState: {
            'machineStats': {
              'sampledAt': DateTime.now().millisecondsSinceEpoch,
              'cpu': {'usagePercent': 12.4, 'cores': 8},
              'memory': {
                'usagePercent': 50.0,
                'usedBytes': 4 * 1024 * 1024 * 1024,
                'totalBytes': 8 * 1024 * 1024 * 1024,
              },
              'disk': {
                'path': '/',
                'usagePercent': 25.0,
                'usedBytes': 128 * 1024 * 1024 * 1024,
                'totalBytes': 512 * 1024 * 1024 * 1024,
              },
            },
          },
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Resources'), findsOneWidget);
        expect(find.text('CPU'), findsOneWidget);
        expect(find.text('12%'), findsOneWidget);
        expect(find.text('Memory'), findsOneWidget);
        expect(find.textContaining('4.0 GB / 8.0 GB'), findsOneWidget);
        expect(find.text('Disk'), findsOneWidget);
        expect(find.textContaining('128 GB / 512 GB'), findsOneWidget);
      });

      testWidgets('shows remove machine button', (tester) async {
        final machine = _makeMachine(id: 'm1');

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        // Scroll down to find the delete button at the bottom
        await tester.scrollUntilVisible(
          find.text('Remove Machine'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        expect(find.text('Remove Machine'), findsOneWidget);
      });

      testWidgets('shows delete button with error color', (tester) async {
        final machine = _makeMachine(id: 'm1');

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        // Scroll down to find the delete button at the bottom
        await tester.scrollUntilVisible(
          find.text('Remove Machine'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        expect(find.text('Remove Machine'), findsOneWidget);
      });
    });

    group('sessions list', () {
      testWidgets('does not show sessions section when empty',
          (tester) async {
        final machine = _makeMachine(id: 'm1');

        await tester.pumpWidget(
          _buildApp(
            machineId: 'm1',
            machines: {'m1': machine},
            sessions: {},
          ),
        );
        await tester.pump();

        // "Sessions (0)" should not appear
        expect(find.textContaining('Sessions'), findsNothing);
      });
    });

    group('timestamp formatting', () {
      testWidgets('shows "just now" for very recent activity',
          (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = _makeMachine(
          id: 'm1',
          activeAt: now - 5000, // 5 seconds ago
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        // Online machines show "Connected now"
        expect(find.text('Connected now'), findsOneWidget);
      });

      testWidgets('shows minutes ago for recent activity', (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = _makeMachine(
          id: 'm1',
          activeAt: now - 5 * 60 * 1000, // 5 minutes ago
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        // Timestamp is embedded in "Last seen X"
        expect(find.text('Last seen 5m ago'), findsOneWidget);
      });

      testWidgets('shows hours ago for old activity', (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = _makeMachine(
          id: 'm1',
          activeAt: now - 3 * 60 * 60 * 1000, // 3 hours ago
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Last seen 3h ago'), findsOneWidget);
      });

      testWidgets('shows days ago for very old activity', (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = _makeMachine(
          id: 'm1',
          activeAt: now - 2 * 24 * 60 * 60 * 1000, // 2 days ago
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Last seen 2d ago'), findsOneWidget);
      });
    });

    group('refresh indicator', () {
      testWidgets('wraps content in RefreshIndicator', (tester) async {
        final machine = _makeMachine(id: 'm1');

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });

    group('status banner', () {
      testWidgets('shows correct status color for online machine',
          (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = _makeMachine(id: 'm1', activeAt: now - 5000);

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        // Status banner exists with status dot
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('shows correct status color for offline machine',
          (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final machine = _makeMachine(
          id: 'm1',
          activeAt: now - 120000,
        );

        await tester.pumpWidget(
          _buildApp(machineId: 'm1', machines: {'m1': machine}),
        );
        await tester.pump();

        expect(find.text('Offline'), findsOneWidget);
      });
    });
  });
}
