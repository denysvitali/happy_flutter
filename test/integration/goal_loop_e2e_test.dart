import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/goal_loops_notifier.dart';
import 'package:happy_flutter/core/providers/machines_notifier.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/loops/create_goal_loop_sheet.dart';

import '../helpers/test_helpers.dart';

/// E2E-style coverage for the Flutter half of the happy-cli-go goal-loop
/// contract. The fake RPC returns the same JSON shape as
/// daemon.Manager.MachineLoopCreate; subsequent state arrives through the
/// same daemonState.machineLoops projection used in production.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Sync testSync;

  setUp(() {
    testSync = createTestSync()
      ..testIsInitialized = true
      ..testMachines.clear();
  });

  tearDown(() {
    testSync.testMachineRPCOverride = null;
    testSync.testMachines.clear();
    testSync.testIsInitialized = false;
  });

  testWidgets('create sheet sends the selected model to happy-cli-go', (
    tester,
  ) async {
    final machine = _machine();
    Map<String, dynamic>? capturedParams;
    Loop? createdLoop;
    testSync.testMachineRPCOverride = (machineId, method, params) async {
      expect(machineId, machine.id);
      expect(method, 'loop-create');
      capturedParams = Map<String, dynamic>.from(params);
      return <String, dynamic>{
        'ok': true,
        'loop': _daemonGoalLoop(
          agent: params['agent']! as String,
          model: params['model']! as String,
        ),
      };
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machinesNotifierProvider.overrideWith(
            () => _StubMachinesNotifier(machine),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  createdLoop = await CreateGoalLoopSheet.show(
                    context,
                    initialMachineId: machine.id,
                    initialDirectory: '/workspace/project',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-loop-goal')),
      'Ship goal loops reliably',
    );
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('codex').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-loop-model')),
      'gpt-5.5:high',
    );

    final start = find.text('Start loop');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(capturedParams, isNotNull);
    expect(capturedParams!['goal'], 'Ship goal loops reliably');
    expect(capturedParams!['directory'], '/workspace/project');
    expect(capturedParams!['agent'], 'codex');
    expect(capturedParams!['model'], 'gpt-5.5:high');
    expect(createdLoop, isNotNull);
    expect(createdLoop!.model, 'gpt-5.5:high');
  });

  test(
    'daemonState drives completion and resume uses the machine RPC',
    () async {
      final running = _daemonGoalLoop(
        model: 'opus:max',
        activeSessionId: 'iteration-session-1',
      );
      final machine = _machine(loop: running);
      testSync.testMachines[machine.id] = machine;
      final container = ProviderContainer(
        overrides: [
          machinesNotifierProvider.overrideWith(
            () => _StubMachinesNotifier(machine),
          ),
        ],
      );
      addTearDown(container.dispose);

      final projected = container.read(goalLoopsNotifierProvider).single;
      expect(projected.model, 'opus:max');
      expect(projected.activeSessionId, 'iteration-session-1');
      expect(projected.isTerminal, isFalse);

      final completed = _daemonGoalLoop(
        model: 'opus:max',
        status: 'complete',
        statusDetail: 'All checks passed.',
        fireCount: 2,
      );
      final completedMachine = _machine(loop: completed);
      testSync.testMachines[machine.id] = completedMachine;
      container.read(machinesNotifierProvider.notifier).state =
          <String, Machine>{machine.id: completedMachine};

      final finished = container.read(goalLoopsNotifierProvider).single;
      expect(finished.loopStatus, LoopStatus.complete);
      expect(finished.statusDetail, 'All checks passed.');

      testSync.testMachineRPCOverride = (machineId, method, params) async {
        expect(machineId, machine.id);
        expect(method, 'loop-resume');
        expect(params, <String, dynamic>{'loopId': 'cafef00d'});
        return <String, dynamic>{'ok': true};
      };
      final response = await container
          .read(goalLoopsNotifierProvider.notifier)
          .resume(machineId: machine.id, loopId: finished.id);

      expect(response.success, isTrue);
      expect(
        container.read(goalLoopsNotifierProvider).single.isTerminal,
        isFalse,
      );
    },
  );
}

class _StubMachinesNotifier extends MachinesNotifier {
  _StubMachinesNotifier(this.machine);

  final Machine machine;

  @override
  Map<String, Machine> build() => <String, Machine>{machine.id: machine};
}

Machine _machine({Map<String, dynamic>? loop}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Machine(
    id: 'machine-1',
    seq: 1,
    createdAt: now - 60000,
    updatedAt: now,
    active: true,
    activeAt: now,
    metadataVersion: 1,
    daemonStateVersion: 1,
    metadata: const MachineMetadata(host: 'workstation'),
    daemonState: loop == null
        ? const <String, dynamic>{}
        : <String, dynamic>{
            'machineLoops': <Map<String, dynamic>>[loop],
          },
  );
}

Map<String, dynamic> _daemonGoalLoop({
  String agent = 'claude',
  String model = '',
  String? activeSessionId,
  String status = 'running',
  String statusDetail = '',
  int fireCount = 1,
}) {
  return <String, dynamic>{
    'id': 'cafef00d',
    'sessionId': '',
    'expression': '',
    'prompt': '',
    'recurring': true,
    'createdAt': 1786190400000,
    'expiresAt': 1788782400000,
    'fireCount': fireCount,
    'paused': false,
    'machineId': 'machine-1',
    'directory': '/workspace/project',
    'agent': agent,
    if (model.isNotEmpty) 'model': model,
    'activeSessionId': ?activeSessionId,
    'goal': 'Ship goal loops reliably',
    'maxIterations': 25,
    'status': status,
    if (statusDetail.isNotEmpty) 'statusDetail': statusDetail,
  };
}
