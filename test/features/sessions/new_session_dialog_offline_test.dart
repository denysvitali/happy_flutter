import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/sessions/widgets/new_session_dialog.dart';

import '../../helpers/test_helpers.dart';

Machine _machine({
  required String id,
  required String displayName,
  required bool active,
  required int activeAtMs,
}) {
  return Machine(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: active,
    activeAt: activeAtMs,
    metadataVersion: 1,
    daemonStateVersion: 1,
    metadata: MachineMetadata(displayName: displayName, host: displayName),
  );
}

class _StubMachinesNotifier extends MachinesNotifier {
  _StubMachinesNotifier(this._machines);
  final Map<String, Machine> _machines;

  @override
  Map<String, Machine> build() => _machines;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}
}

class _StubSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings();

  @override
  Future<void> updateSetting<T>(String key, T value) async {}
}

class _StubSessionsNotifier extends SessionsNotifier {
  @override
  Map<String, Session> build() => <String, Session>{};

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}
}

class _StubConnectionNotifier extends ConnectionNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.connected;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('newSessionCreateBlocker', () {
    final onlineMachine = _machine(
      id: 'm1',
      displayName: 'm1',
      active: true,
      activeAtMs: 1,
    );

    test('returns missingMachine when no machine selected', () {
      expect(
        newSessionCreateBlocker(
          machine: null,
          machineOnline: false,
          path: '/some/path',
          isCreating: false,
          connectionStatus: ConnectionStatus.connected,
          syncInitialized: true,
        ),
        NewSessionCreateBlocker.missingMachine,
      );
    });

    test('returns offlineMachine when selected machine is offline', () {
      expect(
        newSessionCreateBlocker(
          machine: onlineMachine,
          machineOnline: false,
          path: '/some/path',
          isCreating: false,
          connectionStatus: ConnectionStatus.connected,
          syncInitialized: true,
        ),
        NewSessionCreateBlocker.offlineMachine,
      );
    });

    test('returns missingPath when path is empty', () {
      expect(
        newSessionCreateBlocker(
          machine: onlineMachine,
          machineOnline: true,
          path: '   ',
          isCreating: false,
          connectionStatus: ConnectionStatus.connected,
          syncInitialized: true,
        ),
        NewSessionCreateBlocker.missingPath,
      );
    });

    test('returns null on the happy path (online machine + path)', () {
      expect(
        newSessionCreateBlocker(
          machine: onlineMachine,
          machineOnline: true,
          path: '/repo',
          isCreating: false,
          connectionStatus: ConnectionStatus.connected,
          syncInitialized: true,
        ),
        isNull,
      );
    });

    test('offline blocker fires even when path is missing', () {
      expect(
        newSessionCreateBlocker(
          machine: onlineMachine,
          machineOnline: false,
          path: '',
          isCreating: false,
          connectionStatus: ConnectionStatus.connected,
          syncInitialized: true,
        ),
        NewSessionCreateBlocker.offlineMachine,
      );
    });
  });

  group('NewSessionDialog offline guard', () {
    setUp(() {
      // The dialog checks `sync.isInitialized` to decide whether to block on
      // sync readiness; flip it to true so the offline blocker (not the
      // sync-not-ready blocker) is what disables the button.
      final testSync = createTestSync();
      testSync.testIsInitialized = true;
    });

    Widget buildHarness({
      required Map<String, Machine> machines,
      String? initialMachineId,
    }) {
      return ProviderScope(
        overrides: [
          machinesNotifierProvider.overrideWith(
            () => _StubMachinesNotifier(machines),
          ),
          settingsNotifierProvider.overrideWith(_StubSettingsNotifier.new),
          sessionsNotifierProvider.overrideWith(_StubSessionsNotifier.new),
          connectionNotifierProvider.overrideWith(_StubConnectionNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NewSessionDialog(
              initialMachineId: initialMachineId,
              initialPath: '/repo',
            ),
          ),
        ),
      );
    }

    testWidgets('Create button is disabled when selected machine is offline', (
      tester,
    ) async {
      final stale = DateTime.now()
          .subtract(const Duration(minutes: 10))
          .millisecondsSinceEpoch;
      final offlineMachine = _machine(
        id: 'm-offline',
        displayName: 'My Laptop',
        active: false,
        activeAtMs: stale,
      );
      await tester.pumpWidget(
        buildHarness(
          machines: {'m-offline': offlineMachine},
          initialMachineId: 'm-offline',
        ),
      );
      await tester.pump();

      // The requirement banner must mention the offline state.
      expect(
        find.text('Launcher disabled while machine is offline'),
        findsOneWidget,
      );

      // The Create button must be present but disabled.
      final createButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create'),
      );
      expect(
        createButton.onPressed,
        isNull,
        reason: 'offline machine must disable Create',
      );
    });

    testWidgets('Create button is enabled when machine is online', (
      tester,
    ) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final onlineMachine = _machine(
        id: 'm-online',
        displayName: 'My Laptop',
        active: true,
        activeAtMs: now,
      );
      await tester.pumpWidget(
        buildHarness(
          machines: {'m-online': onlineMachine},
          initialMachineId: 'm-online',
        ),
      );
      await tester.pump();

      final createButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create'),
      );
      expect(
        createButton.onPressed,
        isNotNull,
        reason: 'online machine + path must allow Create',
      );
    });
  });
}
