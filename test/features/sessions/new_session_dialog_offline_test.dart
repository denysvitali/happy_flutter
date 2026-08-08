import 'dart:async';

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
import 'package:happy_flutter/core/services/logger_service.dart';
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

  @override
  Future<void> applySettings(Map<String, dynamic> values) async {}
}

class _StubSessionsNotifier extends SessionsNotifier {
  _StubSessionsNotifier({this.onCreateSession});

  /// When set, replaces the real `createSession` so a test can hold the
  /// dialog inside the async gap between the spawn request and its reply.
  final Future<String> Function()? onCreateSession;

  @override
  Map<String, Session> build() => <String, Session>{};

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}

  @override
  Future<String> createSession({
    required String machineId,
    required String path,
    required String agent,
    String? profileId,
    String? modelMode,
    String? spawnBackend,
    String? repoUrl,
    String? repoRef,
    String? repoCommit,
  }) {
    final hook = onCreateSession;
    if (hook == null) {
      return super.createSession(
        machineId: machineId,
        path: path,
        agent: agent,
        profileId: profileId,
        modelMode: modelMode,
        spawnBackend: spawnBackend,
        repoUrl: repoUrl,
        repoRef: repoRef,
        repoCommit: repoCommit,
      );
    }
    return hook();
  }
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

  group('newSessionCreateErrorMessage', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('does not expose unclassified daemon error prose', () {
      const daemonError =
          'directory /home/workspace/happy_flutter must be within '
          '/workspace';

      expect(
        newSessionCreateErrorMessage(
          l10n: l10n,
          error: StateError(daemonError),
        ),
        l10n.newSessionCouldNotStartSession,
      );
    });

    test('keeps the localized machine unreachable message', () {
      expect(
        newSessionCreateErrorMessage(
          l10n: l10n,
          error: StateError('Machine is offline'),
        ),
        l10n.newSessionMachineUnreachable,
      );
    });

    test('keeps generic non-StateError failures terse', () {
      expect(
        newSessionCreateErrorMessage(l10n: l10n, error: Exception('boom')),
        l10n.newSessionCouldNotStartSession,
      );
    });

    test('maps daemon deadline-exceeded errors to generic message', () {
      expect(
        newSessionCreateErrorMessage(
          l10n: l10n,
          error: StateError(
            'failed to resolve session: context deadline exceeded',
          ),
        ),
        l10n.newSessionCouldNotStartSession,
      );
      expect(
        newSessionCreateErrorMessage(
          l10n: l10n,
          error: StateError('rpc spawn-happy-session: deadline exceeded'),
        ),
        l10n.newSessionCouldNotStartSession,
      );
    });

    test('maps stale daemon agent errors to an update instruction', () {
      expect(
        newSessionCreateErrorMessage(
          l10n: l10n,
          error: StateError('unknown agent "grok"'),
        ),
        l10n.newSessionDaemonOutdated,
      );
    });
  });

  group('resolveAvailableMachineId', () {
    final now = DateTime.now().millisecondsSinceEpoch;

    test(
      'replaces a stale registration with the freshest online same host',
      () {
        final stale = _machine(
          id: 'stale',
          displayName: 'Kubernetes daemon',
          active: false,
          activeAtMs: now - 300000,
        );
        final olderOnline = _machine(
          id: 'online-older',
          displayName: 'Kubernetes daemon',
          active: true,
          activeAtMs: now - 2000,
        );
        final freshestOnline = _machine(
          id: 'online-fresh',
          displayName: 'Kubernetes daemon',
          active: true,
          activeAtMs: now - 1000,
        );

        expect(
          resolveAvailableMachineId(stale.id, {
            stale.id: stale,
            olderOnline.id: olderOnline,
            freshestOnline.id: freshestOnline,
          }, nowMs: now),
          freshestOnline.id,
        );
      },
    );

    test('does not replace a stale registration with another host', () {
      final stale = _machine(
        id: 'stale',
        displayName: 'Kubernetes daemon',
        active: false,
        activeAtMs: now - 300000,
      );
      final unrelated = _machine(
        id: 'unrelated',
        displayName: 'Developer laptop',
        active: true,
        activeAtMs: now,
      );

      expect(
        resolveAvailableMachineId(stale.id, {
          stale.id: stale,
          unrelated.id: unrelated,
        }, nowMs: now),
        stale.id,
      );
    });
  });

  group('resolveReachableMachineId', () {
    final now = DateTime.now().millisecondsSinceEpoch;

    test(
      'falls back to another reachable registration for the same host',
      () async {
        final selected = _machine(
          id: 'selected',
          displayName: 'Shared host',
          active: true,
          activeAtMs: now,
        );
        final reachable = _machine(
          id: 'reachable',
          displayName: 'Shared host',
          active: true,
          activeAtMs: now - 1000,
        );
        final probed = <String>[];

        await expectLater(
          resolveReachableMachineId(
            selected.id,
            {selected.id: selected, reachable.id: reachable},
            nowMs: now,
            probe: (machineId) async {
              probed.add(machineId);
              if (machineId == selected.id) {
                throw StateError('Machine is unreachable');
              }
            },
          ),
          completion(reachable.id),
        );
        expect(probed, [selected.id, reachable.id]);
      },
    );

    test('does not probe registrations from another host', () async {
      final selected = _machine(
        id: 'selected',
        displayName: 'Selected host',
        active: true,
        activeAtMs: now,
      );
      final unrelated = _machine(
        id: 'unrelated',
        displayName: 'Other host',
        active: true,
        activeAtMs: now,
      );
      final probed = <String>[];

      await expectLater(
        resolveReachableMachineId(
          selected.id,
          {selected.id: selected, unrelated.id: unrelated},
          nowMs: now,
          probe: (machineId) async {
            probed.add(machineId);
            throw StateError('Machine is unreachable');
          },
        ),
        throwsStateError,
      );
      expect(probed, [selected.id]);
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

    Future<void> pumpDialog(WidgetTester tester, Widget widget) async {
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
      Future<String> Function()? onCreateSession,
    }) {
      return ProviderScope(
        overrides: [
          machinesNotifierProvider.overrideWith(
            () => _StubMachinesNotifier(machines),
          ),
          settingsNotifierProvider.overrideWith(_StubSettingsNotifier.new),
          sessionsNotifierProvider.overrideWith(
            () => _StubSessionsNotifier(onCreateSession: onCreateSession),
          ),
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

    Widget buildDialogRouteHarness({
      required Map<String, Machine> machines,
      required String initialMachineId,
      required Future<String> Function() onCreateSession,
    }) {
      return ProviderScope(
        overrides: [
          machinesNotifierProvider.overrideWith(
            () => _StubMachinesNotifier(machines),
          ),
          settingsNotifierProvider.overrideWith(_StubSettingsNotifier.new),
          sessionsNotifierProvider.overrideWith(
            () => _StubSessionsNotifier(onCreateSession: onCreateSession),
          ),
          connectionNotifierProvider.overrideWith(_StubConnectionNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => unawaited(
                  showNewSessionDialog(
                    context,
                    initialMachineId: initialMachineId,
                    initialPath: '/repo',
                  ),
                ),
                child: const Text('Open dialog'),
              ),
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

    testWidgets(
      'Create button is disabled when active flag has a stale heartbeat',
      (tester) async {
        final stale = DateTime.now()
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch;
        final staleMachine = _machine(
          id: 'm-stale',
          displayName: 'Stale Laptop',
          active: true,
          activeAtMs: stale,
        );
        await pumpDialog(
          tester,
          buildHarness(
            machines: {'m-stale': staleMachine},
            initialMachineId: 'm-stale',
          ),
        );

        final createButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Create'),
        );
        expect(createButton.onPressed, isNull);
      },
    );

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

    testWidgets(
      'dismissal during reachability probe does not use disposed ref',
      (tester) async {
        final testSync = createTestSync();
        final probeStarted = Completer<void>();
        final finishProbe = Completer<void>();
        testSync.testEnsureMachineReachableOverride = (_) async {
          probeStarted.complete();
          await finishProbe.future;
        };
        addTearDown(() {
          testSync.testEnsureMachineReachableOverride = null;
          LoggerService().clear();
        });
        LoggerService().clear();

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

        await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
        await tester.pump();
        await probeStarted.future;

        expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'an indeterminate ticker cannot outlive dialog disposal',
        );
        finishProbe.complete();
        await tester.pump();

        expect(
          LoggerService().getLogs().where(
            (entry) =>
                entry.message.contains('createSession failed') &&
                entry.error.toString().contains('disposed'),
          ),
          isEmpty,
        );
      },
    );

    testWidgets(
      'dismissal during the spawn request does not use a disposed ref',
      (tester) async {
        final testSync = createTestSync();
        testSync.testEnsureMachineReachableOverride = (_) async {};
        final spawnStarted = Completer<void>();
        final finishSpawn = Completer<String>();
        addTearDown(() {
          testSync.testEnsureMachineReachableOverride = null;
          LoggerService().clear();
        });
        LoggerService().clear();

        final now = DateTime.now().millisecondsSinceEpoch;
        await pumpDialog(
          tester,
          buildHarness(
            machines: {
              'm-online': _machine(
                id: 'm-online',
                displayName: 'My Laptop',
                active: true,
                activeAtMs: now,
              ),
            },
            initialMachineId: 'm-online',
            onCreateSession: () {
              if (!spawnStarted.isCompleted) spawnStarted.complete();
              return finishSpawn.future;
            },
          ),
        );

        await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
        await tester.pump();
        await spawnStarted.future;

        // Dismiss while the daemon spawn is still in flight, then let the
        // request complete: every post-await `ref` touch in _createSession
        // must be skipped rather than throwing.
        await tester.pumpWidget(const SizedBox.shrink());
        finishSpawn.complete('s-new');
        await tester.pump();
        // _createSession persists the model mode on its way out, and MMKV
        // debounces that write behind a 500ms timer. Draining it keeps the
        // binding's "timer still pending after dispose" invariant happy —
        // the timer belongs to storage, not to the disposed dialog.
        await tester.pump(const Duration(milliseconds: 600));

        expect(
          LoggerService().getLogs().where(
            (entry) =>
                entry.message.contains('createSession failed') &&
                (entry.message.contains('unmounted') ||
                    entry.message.contains('disposed')),
          ),
          isEmpty,
          reason: 'ref must not be read after the dialog is gone',
        );
      },
    );

    testWidgets(
      'creation disables cancel, barrier, and system back dismissal',
      (tester) async {
        final testSync = createTestSync();
        testSync.testEnsureMachineReachableOverride = (_) async {};
        final spawnStarted = Completer<void>();
        final finishSpawn = Completer<String>();
        addTearDown(() {
          testSync.testEnsureMachineReachableOverride = null;
          LoggerService().clear();
        });

        final now = DateTime.now().millisecondsSinceEpoch;
        await pumpDialog(
          tester,
          buildDialogRouteHarness(
            machines: {
              'm-online': _machine(
                id: 'm-online',
                displayName: 'My Laptop',
                active: true,
                activeAtMs: now,
              ),
            },
            initialMachineId: 'm-online',
            onCreateSession: () {
              if (!spawnStarted.isCompleted) spawnStarted.complete();
              return finishSpawn.future;
            },
          ),
        );

        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
        await tester.pump();
        await spawnStarted.future;

        final cancel = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Cancel'),
        );
        expect(cancel.onPressed, isNull);
        expect(find.byType(ModalBarrier), findsWidgets);
        expect(
          tester
              .widgetList<ModalBarrier>(find.byType(ModalBarrier))
              .map((barrier) => barrier.dismissible),
          everyElement(isFalse),
        );

        await tester.tapAt(const Offset(4, 4));
        await tester.pump();
        expect(find.byType(NewSessionDialog), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(NewSessionDialog), findsOneWidget);

        finishSpawn.completeError(StateError('spawn failed'));
        await tester.pump();
        await tester.pump();

        final enabledCancel = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Cancel'),
        );
        expect(enabledCancel.onPressed, isNotNull);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(NewSessionDialog), findsNothing);
      },
    );

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
        buildHarness(machines: {'m-kube': machine}, initialMachineId: 'm-kube'),
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

    testWidgets('switching from offline to online machine clears the warning '
        'and enables Create', (tester) async {
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
          machines: {'m-offline': offlineMachine, 'm-online': onlineMachine},
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
    });
  });
}
