import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/components/prime_agent_logo.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/features/sessions/widgets/new_session_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      spawnBackends: spawnBackends ?? const ['kubernetes'],
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
  _StubSessionsNotifier({
    this.onCreateSession,
    this.onCreateModelMode,
    this.onCreateSessionArgs,
    this.sessions = const {},
  });

  final void Function(String machineId, String? spawnBackend)?
  onCreateSessionArgs;

  final Map<String, Session> sessions;

  /// When set, replaces the real `createSession` so a test can hold the
  /// dialog inside the async gap between the spawn request and its reply.
  final Future<String> Function()? onCreateSession;
  final ValueChanged<String?>? onCreateModelMode;

  @override
  Map<String, Session> build() => sessions;

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
    onCreateModelMode?.call(modelMode);
    onCreateSessionArgs?.call(machineId, spawnBackend);
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
    setUp(() async {
      // Successful creation persists its model before closing the dialog.
      // Initialize the fake store outside widget fake time so platform
      // migration cannot leave the progress indicator waiting indefinitely.
      SharedPreferences.setMockInitialValues({});
      await MMKVStorage.initialize();
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
      String? initialPath,
      String? initialAgent,
      Map<String, Session> sessions = const {},
      String? initialRepositoryUrl = 'https://example.com/repo.git',
      Future<String> Function()? onCreateSession,
      ValueChanged<String?>? onCreateModelMode,
      void Function(String machineId, String? spawnBackend)?
      onCreateSessionArgs,
    }) {
      return ProviderScope(
        overrides: [
          machinesNotifierProvider.overrideWith(
            () => _StubMachinesNotifier(machines),
          ),
          settingsNotifierProvider.overrideWith(_StubSettingsNotifier.new),
          sessionsNotifierProvider.overrideWith(
            () => _StubSessionsNotifier(
              onCreateSession: onCreateSession,
              onCreateModelMode: onCreateModelMode,
              onCreateSessionArgs: onCreateSessionArgs,
              sessions: sessions,
            ),
          ),
          connectionNotifierProvider.overrideWith(_StubConnectionNotifier.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NewSessionDialog(
              initialMachineId: initialMachineId,
              initialPath: initialPath,
              initialAgent: initialAgent,
              initialRepositoryUrl: initialRepositoryUrl,
            ),
          ),
        ),
      );
    }

    Widget buildDialogRouteHarness({
      required Map<String, Machine> machines,
      required String initialMachineId,
      required Future<String> Function() onCreateSession,
      bool nestedNavigator = false,
      ValueChanged<String?>? onResult,
    }) {
      Widget launcher(BuildContext context) => Scaffold(
        body: FilledButton(
          onPressed: () async {
            final result = await showNewSessionDialog(
              context,
              initialMachineId: initialMachineId,
              initialPath: null,
              initialRepositoryUrl: 'https://example.com/repo.git',
              useRootNavigator: !nestedNavigator,
            );
            onResult?.call(result);
          },
          child: const Text('Open dialog'),
        ),
      );

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
          home: nestedNavigator
              ? Navigator(
                  onGenerateRoute: (_) =>
                      MaterialPageRoute<void>(builder: launcher),
                )
              : Builder(builder: launcher),
        ),
      );
    }

    testWidgets('compact choices stay scrollable above the phone keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(buildHarness(machines: {}));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(8));
      // AlertDialog's outer alignment fills the available viewport; measure
      // the Material card rather than that full-height wrapper.
      final dialogCard = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getSize(dialogCard).height, lessThanOrEqualTo(544));
      expect(tester.getBottomRight(dialogCard).dy, lessThanOrEqualTo(544));
      expect(
        tester.getBottomRight(find.widgetWithText(TextButton, 'Cancel')).dy,
        lessThanOrEqualTo(544),
      );
      await tester.ensureVisible(find.text('Prime Agent'));
      await tester.tap(find.text('Prime Agent'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Prime Agent'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text keeps harness cards readable and selectable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(buildHarness(machines: {}));
      await tester.pumpAndSettle();

      for (final chip in find.byType(ChoiceChip).evaluate()) {
        final size = tester.getSize(find.byWidget(chip.widget));
        expect(size.width, greaterThan(250));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      final codex = find.widgetWithText(ChoiceChip, 'Codex');
      await tester.ensureVisible(codex);
      await tester.tap(codex);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(codex).selected, isTrue);
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .where((chip) => chip.selected),
        hasLength(1),
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'narrow large-text Advanced setup preserves worktree selection',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final machine = _machine(
          id: 'local',
          displayName: 'Laptop',
          active: true,
          activeAtMs: DateTime.now().millisecondsSinceEpoch,
          spawnBackends: const ['local'],
        );
        await tester.pumpWidget(
          buildHarness(
            machines: {'local': machine},
            initialMachineId: 'local',
            initialPath: '/repo',
          ),
        );
        await tester.pumpAndSettle();
        final advanced = find.text('Advanced options');
        await tester.ensureVisible(advanced);
        await tester.tap(advanced);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final setupPicker = find.ancestor(
          of: find.text('Simple'),
          matching: find.byType(SegmentedButton<String>),
        );
        final simple = find.descendant(
          of: setupPicker,
          matching: find.text('Simple'),
        );
        final worktree = find.descendant(
          of: setupPicker,
          matching: find.text('Worktree'),
        );
        expect(setupPicker, findsOneWidget);
        expect(tester.widget<SegmentedButton<String>>(setupPicker).selected, {
          'simple',
        });
        expect(
          tester.getBottomRight(simple).dy,
          lessThan(tester.getTopLeft(worktree).dy),
        );
        await tester.ensureVisible(worktree);
        await tester.tap(worktree);
        await tester.pumpAndSettle();
        expect(tester.widget<SegmentedButton<String>>(setupPicker).selected, {
          'worktree',
        });
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(advanced);
        await tester.tap(advanced);
        await tester.pumpAndSettle();
        expect(setupPicker, findsNothing);
        await tester.tap(advanced);
        await tester.pumpAndSettle();
        expect(tester.widget<SegmentedButton<String>>(setupPicker).selected, {
          'worktree',
        });
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Prime Agent picker uses the official logo', (tester) async {
      await pumpDialog(tester, buildHarness(machines: {}));
      await tester.pumpAndSettle();

      final option = find.ancestor(
        of: find.text('Prime Agent'),
        matching: find.byType(ChoiceChip),
      );
      expect(option, findsOneWidget);
      expect(
        find.descendant(of: option, matching: find.byType(PrimeAgentLogo)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: option,
          matching: find.byIcon(Icons.auto_awesome_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('creation returns through the dialog owning navigator', (
      tester,
    ) async {
      final testSync = createTestSync();
      testSync.testEnsureMachineReachableOverride = (_) async {};
      addTearDown(() {
        testSync.testEnsureMachineReachableOverride = null;
      });
      String? createdSession;
      await pumpDialog(
        tester,
        buildDialogRouteHarness(
          machines: {
            'm-online': _machine(
              id: 'm-online',
              displayName: 'My Laptop',
              active: true,
              activeAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          },
          initialMachineId: 'm-online',
          onCreateSession: () async => 'nested-session',
          nestedNavigator: true,
          onResult: (result) => createdSession = result,
        ),
      );
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));

      expect(createdSession, 'nested-session');
      expect(
        await MMKVStorage().getSessionModelMode('nested-session'),
        'default',
      );
      expect(find.byType(NewSessionDialog), findsNothing);
      expect(find.text('Open dialog'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

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
      final createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
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

        final createButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Create'),
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

      final createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
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

        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
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

        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
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
        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
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

    testWidgets('prefers local despite the advertised Kubernetes default', (
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

      expect(find.text('Git repository'), findsNothing);
      expect(find.text('Branch or ref'), findsNothing);
      expect(find.byType(Autocomplete<String>), findsOneWidget);
      await tester.tap(find.text('Kubernetes'));
      await tester.pumpAndSettle();
      expect(find.text('Git repository'), findsOneWidget);
      expect(find.text('Branch or ref'), findsOneWidget);
    });

    testWidgets('recent workspace selection updates the path without '
        'inheriting the agent', (tester) async {
      Session recent(String id, String machineId, String path) => Session(
        id: id,
        seq: 1,
        createdAt: 1,
        updatedAt: 2,
        active: false,
        thinking: false,
        activeAt: 1,
        metadataVersion: 1,
        agentStateVersion: 1,
        metadata: Metadata(machineId: machineId, path: path, flavor: 'har'),
      );
      await pumpDialog(
        tester,
        buildHarness(
          machines: {
            'm-local': _machine(
              id: 'm-local',
              displayName: 'Laptop',
              active: true,
              activeAtMs: DateTime.now().millisecondsSinceEpoch,
              spawnBackends: const ['local'],
            ),
          },
          initialMachineId: 'm-local',
          sessions: {
            'local': recent('local', 'm-local', '/recent-repo'),
            'other': recent('other', 'm-other', '/other-machine'),
          },
        ),
      );
      expect(find.text('/other-machine'), findsNothing);
      await tester.tap(find.text('Start a new session in a recent workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/recent-repo'));
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '/recent-repo',
      );
      expect(find.text('Har model'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '/edited');
      await tester.pump();
      expect(find.text('/edited'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Har creation uses the agent default without a model picker', (
      tester,
    ) async {
      final testSync = createTestSync();
      testSync.testEnsureMachineReachableOverride = (_) async {};
      addTearDown(() {
        testSync.testEnsureMachineReachableOverride = null;
      });
      var modelMode = 'not-called';
      final spawnStarted = Completer<void>();
      final finishSpawn = Completer<String>();
      await pumpDialog(
        tester,
        buildHarness(
          machines: {
            'm-local': _machine(
              id: 'm-local',
              displayName: 'Local',
              active: true,
              activeAtMs: DateTime.now().millisecondsSinceEpoch,
              spawnBackends: const ['local'],
            ),
          },
          initialMachineId: 'm-local',
          initialPath: '/repo',
          initialAgent: 'har',
          onCreateSession: () {
            spawnStarted.complete();
            return finishSpawn.future;
          },
          onCreateModelMode: (model) => modelMode = model ?? 'unset',
        ),
      );
      expect(find.text('Har model'), findsNothing);
      expect(find.textContaining('Requires an installed'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pump();
      await spawnStarted.future;
      expect(modelMode, 'unset');
      await tester.pumpWidget(const SizedBox.shrink());
      finishSpawn.complete('har-session');
      await tester.pump();
    });

    testWidgets('supports local sessions alongside Kubernetes sessions', (
      tester,
    ) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final machine = _machine(
        id: 'm-both',
        displayName: 'Hybrid Box',
        active: true,
        activeAtMs: now,
        spawnBackends: const ['local', 'kubernetes'],
        defaultSpawnBackend: 'local',
      );
      await pumpDialog(
        tester,
        buildHarness(
          machines: {'m-both': machine},
          initialMachineId: 'm-both',
          initialPath: '/home/me/project',
        ),
      );

      // The Machine / Kubernetes switch sits above everything else.
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Kubernetes')).dy,
        lessThan(tester.getTopLeft(find.text('Who')).dy),
      );
      expect(find.text('Worktree'), findsNothing);
      await tester.tap(find.text('Advanced options'));
      await tester.pumpAndSettle();
      expect(find.text('Worktree'), findsOneWidget);
      expect(find.text('Path'), findsOneWidget);
      expect(find.text('Git repository'), findsNothing);
      final createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
      );
      expect(createButton.onPressed, isNotNull);
    });

    testWidgets('Kubernetes mode lists only Kubernetes-capable daemons', (
      tester,
    ) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      String? spawnBackend;
      String? spawnMachine;
      final spawnStarted = Completer<void>();
      final finishSpawn = Completer<String>();
      final testSync = createTestSync();
      testSync.testEnsureMachineReachableOverride = (_) async {};
      addTearDown(() {
        testSync.testEnsureMachineReachableOverride = null;
      });
      await pumpDialog(
        tester,
        buildHarness(
          machines: {
            'm-laptop': _machine(
              id: 'm-laptop',
              displayName: 'Laptop',
              active: true,
              activeAtMs: now,
              spawnBackends: const ['local'],
            ),
            'm-cluster': _machine(
              id: 'm-cluster',
              displayName: 'Cluster',
              active: true,
              activeAtMs: now,
              spawnBackends: const ['local', 'kubernetes'],
            ),
          },
          initialMachineId: 'm-laptop',
          onCreateSession: () {
            spawnStarted.complete();
            return finishSpawn.future;
          },
          onCreateSessionArgs: (machineId, backend) {
            spawnMachine = machineId;
            spawnBackend = backend;
          },
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Laptop'), findsWidgets);
      expect(find.text('Cluster'), findsWidgets);
      await tester.tap(find.text('Laptop').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kubernetes'));
      await tester.pumpAndSettle();
      // The laptop cannot run pods, so the online cluster daemon replaces it.
      expect(find.text('Kubernetes daemon'), findsOneWidget);
      expect(find.text('Cluster'), findsOneWidget);
      expect(find.text('Laptop'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Laptop'), findsNothing);
      await tester.tap(find.text('Cluster').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Git repository'),
        'https://github.com/acme/repo.git',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pump();
      await spawnStarted.future;
      expect(spawnMachine, 'm-cluster');
      expect(spawnBackend, 'kubernetes');
      await tester.pumpWidget(const SizedBox.shrink());
      finishSpawn.complete('kube-session');
      await tester.pump();
    });

    testWidgets('Kubernetes mode explains when no daemon supports it', (
      tester,
    ) async {
      await pumpDialog(
        tester,
        buildHarness(
          machines: {
            'm-laptop': _machine(
              id: 'm-laptop',
              displayName: 'Laptop',
              active: true,
              activeAtMs: DateTime.now().millisecondsSinceEpoch,
              spawnBackends: const ['local'],
            ),
          },
          initialMachineId: 'm-laptop',
        ),
      );
      await tester.tap(find.text('Kubernetes'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No daemon can create Kubernetes pods'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      final createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
      );
      expect(createButton.onPressed, isNull);
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
        buildHarness(
          machines: {'m-kube': machine},
          initialMachineId: 'm-kube',
          initialRepositoryUrl: null,
        ),
      );

      expect(find.text('Git repository'), findsOneWidget);
      expect(find.text('A git repository is required'), findsOneWidget);
      var createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
      );
      expect(createButton.onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Git repository'),
        'https://example.com/repo.git',
      );
      await tester.pump();

      createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
      );
      expect(createButton.onPressed, isNotNull);
    });

    testWidgets(
      'Kubernetes spawn failure keeps one warning and shows the error',
      (tester) async {
        final testSync = createTestSync();
        testSync.testEnsureMachineReachableOverride = (_) async {};
        LoggerService().clear();
        addTearDown(() {
          testSync.testEnsureMachineReachableOverride = null;
          LoggerService().clear();
        });

        final now = DateTime.now().millisecondsSinceEpoch;
        final failure = StateError(
          'Kubernetes session creation failed: GHProxyURL is required',
        );
        await pumpDialog(
          tester,
          buildHarness(
            machines: {
              'm-kube': _machine(
                id: 'm-kube',
                displayName: 'Kube Box',
                active: true,
                activeAtMs: now,
                spawnBackends: const ['kubernetes'],
                defaultSpawnBackend: 'kubernetes',
              ),
            },
            initialMachineId: 'm-kube',
            onCreateSession: () {
              logger.info(
                '[createSession] spawn RPC failed',
                failure,
                StackTrace.current,
              );
              return Future<String>.error(failure);
            },
          ),
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
        await tester.pump();
        await tester.pump();

        final createWarnings = LoggerService()
            .getLogsByLevel(LogLevel.warning)
            .where((entry) => entry.message.contains('createSession'))
            .toList();
        expect(createWarnings, hasLength(1));
        expect(
          createWarnings.single.message,
          '[NewSessionDialog] createSession failed',
        );
        expect(
          LoggerService().getLogs().where(
            (entry) =>
                entry.level == LogLevel.info &&
                entry.message == '[createSession] spawn RPC failed',
          ),
          hasLength(1),
        );
        expect(
          find.text('Could not start session. Please try again.'),
          findsOneWidget,
        );
      },
    );

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
      var createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
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

      // Kubernetes creation is repository/ref centric. Switching machines
      // clears the repository selection, so provide both required fields.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Git repository'),
        'https://github.com/acme/repo.git',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Branch or ref'),
        'main',
      );
      await tester.pump();

      createButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
      );
      expect(
        createButton.onPressed,
        isNotNull,
        reason: 'online machine + repository/ref must enable Create',
      );
    });

    testWidgets('agent chips expose exclusive selected semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      // Dispose explicitly via try/finally — addTearDown runs after
      // _verifySemanticsHandlesWereDisposed in this SDK, so a teardown-only
      // handle is always reported as leaked.
      try {
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
                spawnBackends: const ['local'],
                defaultSpawnBackend: 'local',
              ),
            },
            initialMachineId: 'm-online',
            initialPath: '/home/me/project',
          ),
        );

        expect(
          tester.getSemantics(find.bySemanticsLabel('Claude')),
          isSemantics(
            isButton: true,
            isSelected: true,
            isInMutuallyExclusiveGroup: true,
          ),
        );

        await tester.tap(find.bySemanticsLabel('Codex'));
        await tester.pump();

        expect(
          tester.getSemantics(find.bySemanticsLabel('Codex')),
          isSemantics(
            isButton: true,
            isSelected: true,
            isInMutuallyExclusiveGroup: true,
          ),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('Claude')),
          isSemantics(
            isButton: true,
            isSelected: false,
            isInMutuallyExclusiveGroup: true,
          ),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('requirement status and spawn errors are live regions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      // See the test above: dispose explicitly; addTearDown would be
      // verified as a leak by _verifySemanticsHandlesWereDisposed.
      try {
        final testSync = createTestSync();
        testSync.testEnsureMachineReachableOverride = (_) async {};
        addTearDown(() {
          testSync.testEnsureMachineReachableOverride = null;
        });

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
                spawnBackends: const ['local'],
                defaultSpawnBackend: 'local',
              ),
            },
            initialMachineId: 'm-online',
            initialPath: '/home/me/project',
            onCreateSession: () =>
                Future<String>.error(StateError('spawn failed')),
          ),
        );

        expect(
          tester.getSemantics(find.text('Ready to create session')),
          isSemantics(isLiveRegion: true),
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
        await tester.pump();
        await tester.pump();

        expect(
          tester.getSemantics(
            find.text('Could not start session. Please try again.'),
          ),
          isSemantics(isLiveRegion: true),
        );
      } finally {
        handle.dispose();
      }
    });
  });
}
