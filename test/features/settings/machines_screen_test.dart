import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/machines_notifier.dart';
import 'package:happy_flutter/features/settings/machines_screen.dart';

class _StubMachinesNotifier extends MachinesNotifier {
  final Map<String, Machine> _initial;

  _StubMachinesNotifier(this._initial);

  @override
  Map<String, Machine> build() => _initial;

  @override
  Future<void> refreshFromSync() async {}
}

Machine _makeMachine({
  required String id,
  required bool active,
  int? activeAt,
  String? displayName,
  String? platform,
  String? host,
}) {
  return Machine(
    id: id,
    seq: 1,
    createdAt: 1000,
    updatedAt: 2000,
    active: active,
    activeAt: activeAt ?? DateTime.now().millisecondsSinceEpoch,
    metadataVersion: 1,
    daemonStateVersion: 1,
    metadata: MachineMetadata(
      displayName: displayName,
      platform: platform,
      host: host,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MachinesScreen', () {
    testWidgets('renders app bar with machines title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Machines'), findsOneWidget);
    });

    testWidgets('renders empty state when no machines', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No machines'), findsOneWidget);
      expect(find.text('Connect computer'), findsOneWidget);
    });

    testWidgets('renders machine list when machines exist', (tester) async {
      final machines = {
        'machine-1': _makeMachine(
          id: 'machine-1',
          active: true,
          displayName: 'Dev Laptop',
          platform: 'linux',
        ),
        'machine-2': _makeMachine(
          id: 'machine-2',
          active: false,
          displayName: 'Work Desktop',
          platform: 'macos',
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier(machines),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Dev Laptop'), findsOneWidget);
      expect(find.text('Work Desktop'), findsOneWidget);
    });

    testWidgets('renders machine with host when no display name', (
      tester,
    ) async {
      final machines = {
        'machine-1': _makeMachine(
          id: 'machine-1',
          active: true,
          host: 'my-server',
          platform: 'linux',
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier(machines),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('my-server'), findsOneWidget);
    });

    testWidgets('shows online status for active machine', (tester) async {
      final machines = {
        'machine-1': _makeMachine(
          id: 'machine-1',
          active: true,
          displayName: 'Dev Laptop',
          platform: 'linux',
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier(machines),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('linux • Online'), findsOneWidget);
    });

    testWidgets('shows offline status for stale active machine', (
      tester,
    ) async {
      final staleActiveAt = DateTime.now()
          .subtract(const Duration(minutes: 10))
          .millisecondsSinceEpoch;
      final machines = {
        'machine-1': _makeMachine(
          id: 'machine-1',
          active: true,
          activeAt: staleActiveAt,
          displayName: 'Stale Laptop',
          platform: 'linux',
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier(machines),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('linux • Offline'), findsOneWidget);
    });

    testWidgets('shows offline status for inactive machine', (tester) async {
      final machines = {
        'machine-1': _makeMachine(
          id: 'machine-1',
          active: false,
          displayName: 'Old Laptop',
          platform: 'macos',
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier(machines),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('macos • Offline'), findsOneWidget);
    });

    testWidgets('renders delete button for each machine', (tester) async {
      final machines = {
        'machine-1': _makeMachine(
          id: 'machine-1',
          active: true,
          displayName: 'Dev Laptop',
          platform: 'linux',
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier(machines),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('renders computer icon for machines', (tester) async {
      final machines = {
        'machine-1': _makeMachine(
          id: 'machine-1',
          active: true,
          displayName: 'Dev Laptop',
          platform: 'linux',
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier(machines),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.computer_outlined), findsOneWidget);
    });

    testWidgets('sorts online machines before offline ones', (tester) async {
      final machines = {
        'machine-inactive': _makeMachine(
          id: 'machine-inactive',
          active: false,
          displayName: 'Inactive Machine',
          platform: 'windows',
        ),
        'machine-active': _makeMachine(
          id: 'machine-active',
          active: true,
          displayName: 'Active Machine',
          platform: 'linux',
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier(machines),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Online machine should appear before offline.
      final activeFinder = find.text('Active Machine');
      final inactiveFinder = find.text('Inactive Machine');
      expect(activeFinder, findsOneWidget);
      expect(inactiveFinder, findsOneWidget);

      final activePosition = tester.getCenter(activeFinder);
      final inactivePosition = tester.getCenter(inactiveFinder);
      expect(activePosition.dy, lessThan(inactivePosition.dy));
    });

    testWidgets('renders machines section header', (tester) async {
      final machines = {
        'machine-1': _makeMachine(
          id: 'machine-1',
          active: true,
          displayName: 'Dev Laptop',
          platform: 'linux',
        ),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier(machines),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MachinesScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Settings section title should be 'Machines'
      final sectionTitles = find.text('Machines');
      // One in AppBar, one in SettingsSection header
      expect(sectionTitles, findsWidgets);
    });
  });
}
