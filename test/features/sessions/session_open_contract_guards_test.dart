// Contract guards around "tap session X opens session X":
//
// * two fast taps open exactly one chat, and it is the FIRST tapped id
//   (`SessionsListContent` 400 ms navigation debounce);
// * after the tapped session is archived — server-confirmed via the
//   sessions map, or optimistically via `SessionUiState` — and the list
//   rebuilds, the card with the same label still routes to the same id;
// * selection mode toggles selection instead of navigating, for every
//   sessions view style.
//
// Companion suites: `session_open_contract_test.dart` (every list-level
// entry point) and `session_open_contract_screens_test.dart` (tablet,
// palette, notifications, artifacts).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/performance_context_service.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_workspace_list.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_list_content.dart';

import '../../helpers/session_open_harness.dart';

class _Harness {
  _Harness({
    required this.recorder,
    required this.router,
    required this.container,
    required this.selection,
    required this.folder,
  });

  final SessionOpenRecorder recorder;
  final GoRouter router;
  final ProviderContainer container;
  final ValueNotifier<SelectionState> selection;
  final ValueNotifier<SessionFolderHeader?> folder;

  ContractSessionsNotifier get sessions =>
      container.read(sessionsNotifierProvider.notifier)
          as ContractSessionsNotifier;

  ContractSessionUiStateNotifier get uiState =>
      container.read(sessionUiStateNotifierProvider.notifier)
          as ContractSessionUiStateNotifier;
}

Future<_Harness> _pump(WidgetTester tester, {required String viewStyle}) async {
  tester.view.physicalSize = const Size(480 * 2, 2400 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final performanceContext = PerformanceContextService()
    ..setCurrentRoute('sessions');
  addTearDown(performanceContext.resetForTesting);

  final recorder = SessionOpenRecorder();
  final container = ProviderContainer(
    overrides: contractListOverrides(
      settings: () => Settings()..sessionsViewStyle = viewStyle,
    ),
  );
  final selection = ValueNotifier<SelectionState>(const SelectionState());
  final folder = ValueNotifier<SessionFolderHeader?>(null);
  addTearDown(() {
    cancelContractChatSwitchMetrics(extraIds: recorder.opened);
    selection.dispose();
    folder.dispose();
    container.dispose();
  });
  final router = buildSessionOpenRouter(
    recorder: recorder,
    home: (_) => Scaffold(
      body: SessionsListContent(
        selectionNotifier: selection,
        folderNotifier: folder,
      ),
    ),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    buildSessionOpenApp(container: container, router: router),
  );
  await _settle(tester);
  return _Harness(
    recorder: recorder,
    router: router,
    container: container,
    selection: selection,
    folder: folder,
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsOneWidget, reason: 'expected exactly one "$text" row');
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

/// Labels of every tappable row in the current view, in layout order.
List<String> _visibleLabels(WidgetTester tester) {
  final labels = <String>[];
  for (final label in contractLabels.values) {
    if (find.text(label).evaluate().isNotEmpty) labels.add(label);
  }
  return labels;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('double-tap debounce', () {
    // Mission Control's focus queue only lists actionable sessions, so the
    // pair there is Bravo (blocked) then Alpha (live).
    for (final entry in const {
      'list': (contractCharlieId, contractCharlieLabel, contractAlphaLabel),
      'mission_control': (
        contractBravoId,
        contractBravoLabel,
        contractAlphaLabel,
      ),
    }.entries) {
      final (firstId, firstLabel, secondLabel) = entry.value;
      testWidgets('[${entry.key}] two fast taps open only the first id', (
        tester,
      ) async {
        final h = await _pump(tester, viewStyle: entry.key);
        // Both taps dispatch before any frame is pumped, so the second one
        // lands well inside the 400 ms wall-clock debounce window.
        await _tap(tester, firstLabel);
        await tester.tap(find.text(secondLabel));
        await _settle(tester);
        expect(h.recorder.opened, [firstId]);
        expect(find.text('chat:$firstId'), findsOneWidget);
        expect(find.text('chat:$contractAlphaId'), findsNothing);
      });
    }

    testWidgets('[list] same card tapped twice fast opens one chat', (
      tester,
    ) async {
      final h = await _pump(tester, viewStyle: 'list');
      await _tap(tester, contractBravoLabel);
      await tester.tap(find.text(contractBravoLabel));
      await _settle(tester);
      expect(h.recorder.opened, [contractBravoId]);
    });

    testWidgets('[list] a tap after the debounce window opens normally', (
      tester,
    ) async {
      final h = await _pump(tester, viewStyle: 'list');
      await _tap(tester, contractCharlieLabel);
      await _settle(tester);
      expect(h.recorder.opened, [contractCharlieId]);
      // Back to the list, then a later tap on a different card must work.
      h.router.pop();
      await _settle(tester);
      // The debounce compares wall-clock `DateTime.now()`, which FakeAsync
      // does not advance — let real time pass the 400 ms window.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 450)),
      );
      await _tap(tester, contractAlphaLabel);
      await _settle(tester);
      expect(h.recorder.opened, [contractCharlieId, contractAlphaId]);
    });
  });

  group('archive then rebuild keeps label→id', () {
    testWidgets('[list] server-confirmed archive moves the card, same id', (
      tester,
    ) async {
      final h = await _pump(tester, viewStyle: 'list');
      // Alpha starts active (online, thinking).
      expect(find.text(contractAlphaLabel), findsOneWidget);
      h.sessions.archive(contractAlphaId);
      await _settle(tester);
      // The card re-renders in the archived section with the same label.
      expect(find.text(contractAlphaLabel), findsOneWidget);
      expect(h.sessions.state[contractAlphaId]!.archived, isTrue);
      await _tap(tester, contractAlphaLabel);
      await _settle(tester);
      expect(h.recorder.opened, [contractAlphaId]);
    });

    testWidgets('[list] optimistic archive hides, confirmation keeps the id', (
      tester,
    ) async {
      final h = await _pump(tester, viewStyle: 'list');
      // Optimistically archived ids are withheld from both lists until the
      // server confirms, so there is no card to mis-route in between.
      h.uiState.publish(
        const SessionUiState(optimisticallyArchivedIds: {contractBravoId}),
      );
      await _settle(tester);
      expect(find.text(contractBravoLabel), findsNothing);
      // Server confirmation lands and the optimistic marker clears.
      h.sessions.archive(contractBravoId);
      h.uiState.publish(const SessionUiState());
      await _settle(tester);
      expect(find.text(contractBravoLabel), findsOneWidget);
      await _tap(tester, contractBravoLabel);
      await _settle(tester);
      expect(h.recorder.opened, [contractBravoId]);
    });

    testWidgets('[list] archiving one session does not shift its siblings', (
      tester,
    ) async {
      final h = await _pump(tester, viewStyle: 'list');
      h.sessions.archive(contractAlphaId);
      await _settle(tester);
      // Every remaining label must still resolve to its own id.
      await _tap(tester, contractCharlieLabel);
      await _settle(tester);
      expect(h.recorder.opened, [contractCharlieId]);
    });

    testWidgets('[folder] archive inside an open folder keeps the id', (
      tester,
    ) async {
      final h = await _pump(tester, viewStyle: 'folder');
      await _tap(tester, 'happy_flutter');
      await _settle(tester);
      expect(h.folder.value, isNotNull);
      h.sessions.archive(contractCharlieId);
      await _settle(tester);
      // Charlie left the active group; it is now behind "Show archived".
      expect(find.text(contractCharlieLabel), findsNothing);
      await tester.tap(find.textContaining('Show archived'));
      await _settle(tester);
      await _tap(tester, contractCharlieLabel);
      await _settle(tester);
      expect(h.recorder.opened, [contractCharlieId]);
    });

    testWidgets('[mission_control] archived row reachable via workspace', (
      tester,
    ) async {
      final h = await _pump(tester, viewStyle: 'mission_control');
      // Bravo sits in the focus queue (blocked lane) before archiving.
      expect(find.text(contractBravoLabel), findsOneWidget);
      h.sessions.archive(contractBravoId);
      await _settle(tester);
      // Archived sessions leave the focus queue; drill into the workspace.
      expect(find.text(contractBravoLabel), findsNothing);
      final workspace = find.descendant(
        of: find.byType(MissionWorkspaceList),
        matching: find.byType(InkWell),
      );
      expect(workspace, findsOneWidget);
      await tester.ensureVisible(workspace);
      await tester.tap(workspace);
      await _settle(tester);
      expect(h.folder.value, isNotNull);
      await tester.tap(find.textContaining('Show archived'));
      await _settle(tester);
      await _tap(tester, contractBravoLabel);
      await _settle(tester);
      expect(h.recorder.opened, [contractBravoId]);
    });
  });

  group('selection mode toggles instead of navigating', () {
    for (final viewStyle in const ['list', 'folder', 'mission_control']) {
      testWidgets('[$viewStyle] long-press enters selection; tap toggles', (
        tester,
      ) async {
        final h = await _pump(tester, viewStyle: viewStyle);
        if (viewStyle == 'folder') {
          await _tap(tester, 'happy_flutter');
          await _settle(tester);
        }
        final first = _visibleLabels(tester).first;
        final firstId = contractLabels.entries
            .firstWhere((e) => e.value == first)
            .key;
        await tester.longPress(find.text(first));
        await _settle(tester);
        expect(h.selection.value.isActive, isTrue);
        expect(h.selection.value.selectedIds, {firstId});
        expect(h.recorder.opened, isEmpty);

        // Tapping another card selects it instead of opening it.
        final labels = _visibleLabels(tester);
        final second = labels.firstWhere((l) => l != first);
        final secondId = contractLabels.entries
            .firstWhere((e) => e.value == second)
            .key;
        await _tap(tester, second);
        await _settle(tester);
        expect(h.selection.value.selectedIds, {firstId, secondId});
        expect(h.recorder.opened, isEmpty);

        // Tapping it again deselects; still no navigation.
        await _tap(tester, second);
        await _settle(tester);
        expect(h.selection.value.selectedIds, {firstId});
        expect(h.recorder.opened, isEmpty);
        expect(find.textContaining('chat:'), findsNothing);
      });
    }

    testWidgets('[list] archived card in selection mode toggles too', (
      tester,
    ) async {
      final h = await _pump(tester, viewStyle: 'list');
      h.selection.value = const SelectionState(
        isActive: true,
        selectedIds: {contractAlphaId},
      );
      await _settle(tester);
      await _tap(tester, contractDeltaLabel);
      await _settle(tester);
      expect(h.selection.value.selectedIds, {contractAlphaId, contractDeltaId});
      expect(h.recorder.opened, isEmpty);
    });

    testWidgets('[list] leaving selection mode restores navigation', (
      tester,
    ) async {
      final h = await _pump(tester, viewStyle: 'list');
      h.selection.value = const SelectionState(
        isActive: true,
        selectedIds: {contractAlphaId},
      );
      await _settle(tester);
      h.selection.value = const SelectionState();
      await _settle(tester);
      await _tap(tester, contractEchoLabel);
      await _settle(tester);
      expect(h.recorder.opened, [contractEchoId]);
    });
  });
}
