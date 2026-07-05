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
  List<String>? spawnBackends,
  String? defaultSpawnBackend,
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
    metadata: MachineMetadata(
      displayName: displayName,
      host: displayName,
      spawnBackends: spawnBackends,
      defaultSpawnBackend: defaultSpawnBackend,
    ),
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
  Future<void> refreshFromSync({bool includeMachines = false}) async {}
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

    test('returns missingRepository for Kubernetes without a repo URL', () {
      expect(
        newSessionCreateBlocker(
          machine: onlineMachine,
          machineOnline: true,
          path: '/repo',
          isCreating: false,
          connectionStatus: ConnectionStatus.connected,
          syncInitialized: true,
          repositoryRequired: true,
          repositoryUrl: ' ',
        ),
        NewSessionCreateBlocker.missingRepository,
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
      testSync.isInitialized = true;
    });

    Future<void> pumpDialog(
      WidgetTester tester,
      Widget widget,
    ) async {
      // The dialog's intrinsic height exceeds the default 600px test
      // viewport when the offline banner expands; give it room to lay
      // out so the test does not fail on a 4px RenderFlex overflow.
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(widget);
      await tester.pump();
    }

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
      await pumpDialog(
        tester,
        buildHarness(
          machines: {'m-offline': offlineMachine},
          initialMachineId: 'm-offline',
        ),
      );

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
      await pumpDialog(
        tester,
        buildHarness(
          machines: {'m-online': onlineMachine},
          initialMachineId: 'm-online',
        ),
      );

      final createButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create'),
      );
      expect(
        createButton.onPressed,
        isNotNull,
        reason: 'online machine + path must allow Create',
      );
    });

    testWidgets('shows spawn backend selector when machine advertises it', (
      tester,
    ) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final machine = _machine(
        id: 'm-kube',
        displayName: 'Kube Box',
        active: true,
        activeAtMs: now,
        spawnBackends: const ['local', 'kubernetes'],
        defaultSpawnBackend: 'kubernetes',
      );
      await pumpDialog(
        tester,
        buildHarness(
          machines: {'m-kube': machine},
          initialMachineId: 'm-kube',
        ),
      );

      expect(find.text('Spawn on'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Kubernetes'), findsOneWidget);
    });

    testWidgets('Kubernetes session requires repository URL', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final machine = _machine(
        id: 'm-kube',
        displayName: 'Kube Box',
        active: true,
        activeAtMs: now,
        spawnBackends: const ['kubernetes'],
        defaultSpawnBackend: 'kubernetes',
      );
      await pumpDialog(
        tester,
        buildHarness(machines: {'m-kube': machine}, initialMachineId: 'm-kube'),
      );

      expect(find.text('Repository URL'), findsOneWidget);
      expect(
        find.text('Repository URL required for Kubernetes'),
        findsOneWidget,
      );
      var createButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create'),
      );
      expect(createButton.onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Repository URL'),
        'https://example.com/repo.git',
      );
      await tester.pump();

      createButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create'),
      );
      expect(createButton.onPressed, isNotNull);
    });

    testWidgets(
      'switching from offline to online machine clears the warning '
      'and enables Create',
      (tester) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final staleMs = DateTime.now()
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch;
        final offlineMachine = _machine(
          id: 'm-offline',
          displayName: 'Offline Box',
          active: false,
          activeAtMs: staleMs,
        );
        final onlineMachine = _machine(
          id: 'm-online',
          displayName: 'Online Box',
          active: true,
          activeAtMs: now,
        );
        await pumpDialog(
          tester,
          buildHarness(
            machines: {
              'm-offline': offlineMachine,
              'm-online': onlineMachine,
            },
            initialMachineId: 'm-offline',
          ),
        );

        // Offline machine selected: warning shown, Create disabled.
        expect(
          find.text('Launcher disabled while machine is offline'),
          findsOneWidget,
        );
        var createButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Create'),
        );
        expect(
          createButton.onPressed,
          isNull,
          reason: 'offline machine must disable Create',
        );

        // Open the machine dropdown and pick the online machine.
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Online Box').last);
        await tester.pumpAndSettle();

        // Warning must disappear once an online machine is selected.
        expect(
          find.text('Launcher disabled while machine is offline'),
          findsNothing,
        );

        // Switching machines clears the previously-selected path; type a
        // path so the only remaining gate is the machine status.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Path'),
          '/repo',
        );
        await tester.pump();

        createButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Create'),
        );
        expect(
          createButton.onPressed,
          isNotNull,
          reason: 'online machine + path must enable Create',
        );
      },
    );
  });
}
