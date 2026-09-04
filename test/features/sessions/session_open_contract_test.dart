// Contract: tapping session X in the sessions collection opens session X.
//
// Covers every `SessionsListContent` entry point — the legacy list (active
// cards, archived cards grouped by date and by folder), the folder-centric
// view (active, recent-archived and older-archived rows), the unread-focus
// view and Mission Control (focus-queue rows, Live wire rows, the peek
// sheet and the workspace drill-in to an archived row). Companion suites:
// `session_open_contract_screens_test.dart` (tablet master-detail, command
// palette, notifications, artifacts) and
// `session_open_contract_guards_test.dart` (debounce, archive rebuild,
// selection mode).
//
// The fixture seeds six sessions that differ only by label, so a card that
// routes by list position, by text, or by the wrong id shows up as the
// wrong recorded session id.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/performance_context_service.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_workspace_list.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';
import 'package:happy_flutter/features/sessions/widgets/session_peek_sheet.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_list_content.dart';
import 'package:happy_flutter/features/sessions/widgets/stream_wall.dart';

import '../../helpers/session_open_harness.dart';

class _ListHarness {
  _ListHarness({
    required this.recorder,
    required this.container,
    required this.selection,
    required this.folder,
  });

  final SessionOpenRecorder recorder;
  final ProviderContainer container;
  final ValueNotifier<SelectionState> selection;
  final ValueNotifier<SessionFolderHeader?> folder;

  ContractSessionsNotifier get sessions =>
      container.read(sessionsNotifierProvider.notifier)
          as ContractSessionsNotifier;
}

Future<_ListHarness> _pumpList(
  WidgetTester tester, {
  required String viewStyle,
  Map<String, Session>? sessions,
  SessionUiState uiState = const SessionUiState(),
}) async {
  // Tall viewport so every fixture row is laid out without scrolling. 480 px
  // wide (not 390): at 390 the archived folder row with a pending-archive
  // badge and the NeedsAttention permission row overflow by ~10 px, which
  // would fail these tests for a reason unrelated to routing.
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
      sessions: sessions,
      uiState: uiState,
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
  return _ListHarness(
    recorder: recorder,
    container: container,
    selection: selection,
    folder: folder,
  );
}

/// Bounded pumps: stagger/slide animations finish within ~600 ms and the
/// route push transition within ~400 ms. Never `pumpAndSettle` here —
/// Mission Control owns repeating tickers.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsOneWidget, reason: 'expected exactly one "$text" row');
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

void _expectOpened(_ListHarness h, String id) {
  expect(h.recorder.opened, [id]);
  expect(find.text('chat:$id'), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('legacy list view', () {
    for (final entry in const {
      contractAlphaId: contractAlphaLabel,
      contractBravoId: contractBravoLabel,
      contractCharlieId: contractCharlieLabel,
    }.entries) {
      testWidgets('active card "${entry.value}" opens ${entry.key}', (
        tester,
      ) async {
        final h = await _pumpList(tester, viewStyle: 'list');
        await _tapText(tester, entry.value);
        _expectOpened(h, entry.key);
      });
    }

    for (final entry in const {
      contractDeltaId: contractDeltaLabel,
      contractFoxtrotId: contractFoxtrotLabel,
      contractEchoId: contractEchoLabel,
    }.entries) {
      testWidgets('date-grouped archived card "${entry.value}" opens '
          '${entry.key}', (tester) async {
        final h = await _pumpList(tester, viewStyle: 'list');
        await _tapText(tester, entry.value);
        _expectOpened(h, entry.key);
      });

      testWidgets('folder-grouped archived card "${entry.value}" opens '
          '${entry.key}', (tester) async {
        final h = await _pumpList(tester, viewStyle: 'list');
        // Switch the history section from date to folder grouping.
        await tester.tap(find.byIcon(Icons.folder_outlined).first);
        await _settle(tester);
        await _tapText(tester, entry.value);
        _expectOpened(h, entry.key);
      });
    }
  });

  group('folder view', () {
    Future<_ListHarness> openFolder(WidgetTester tester) async {
      final h = await _pumpList(tester, viewStyle: 'folder');
      // One folder because every fixture shares machine + path.
      await _tapText(tester, 'happy_flutter');
      expect(h.folder.value, isNotNull);
      return h;
    }

    for (final entry in const {
      contractAlphaId: contractAlphaLabel,
      contractCharlieId: contractCharlieLabel,
    }.entries) {
      testWidgets('active row "${entry.value}" opens ${entry.key}', (
        tester,
      ) async {
        final h = await openFolder(tester);
        await _tapText(tester, entry.value);
        _expectOpened(h, entry.key);
      });
    }

    for (final entry in const {
      contractDeltaId: contractDeltaLabel,
      contractFoxtrotId: contractFoxtrotLabel,
    }.entries) {
      testWidgets('recent archived row "${entry.value}" opens ${entry.key}', (
        tester,
      ) async {
        final h = await openFolder(tester);
        expect(find.text(entry.value), findsNothing);
        await tester.tap(find.textContaining('Show archived'));
        await _settle(tester);
        await _tapText(tester, entry.value);
        _expectOpened(h, entry.key);
      });
    }

    testWidgets('older archived row "$contractEchoLabel" opens '
        '$contractEchoId', (tester) async {
      final h = await openFolder(tester);
      await tester.tap(find.textContaining('Show archived'));
      await _settle(tester);
      expect(find.text(contractEchoLabel), findsNothing);
      await tester.tap(find.textContaining('Show older archived'));
      await _settle(tester);
      await _tapText(tester, contractEchoLabel);
      _expectOpened(h, contractEchoId);
    });
  });

  group('unread focus view', () {
    testWidgets('needs-attention card opens the tapped id', (tester) async {
      final h = await _pumpList(tester, viewStyle: 'unread_focus');
      // Alpha is thinking → pulsing status → Needs Attention section.
      await _tapText(tester, contractAlphaLabel);
      _expectOpened(h, contractAlphaId);
    });

    testWidgets('all-others row opens the tapped id', (tester) async {
      final h = await _pumpList(tester, viewStyle: 'unread_focus');
      await _tapText(tester, contractCharlieLabel);
      _expectOpened(h, contractCharlieId);
    });
  });

  group('mission control', () {
    testWidgets('focus-queue row (live lane) opens the tapped id', (
      tester,
    ) async {
      final h = await _pumpList(tester, viewStyle: 'mission_control');
      await _tapText(tester, contractAlphaLabel);
      _expectOpened(h, contractAlphaId);
    });

    testWidgets('focus-queue row (blocked lane) opens the tapped id', (
      tester,
    ) async {
      final h = await _pumpList(tester, viewStyle: 'mission_control');
      await _tapText(tester, contractBravoLabel);
      _expectOpened(h, contractBravoId);
    });

    testWidgets('peek sheet "Open chat" opens the peeked id', (tester) async {
      final h = await _pumpList(tester, viewStyle: 'mission_control');
      // Triage menu of the Bravo row → Quick look → Open chat.
      final menu = find.descendant(
        of: find.byKey(const ValueKey('mission-action-$contractBravoId')),
        matching: find.byIcon(Icons.more_vert_rounded),
      );
      expect(menu, findsOneWidget);
      await tester.tap(menu);
      await _settle(tester);
      await tester.tap(find.text('Quick look'));
      await _settle(tester);
      expect(find.byType(SessionPeekSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SessionPeekSheet),
          matching: find.text(contractBravoLabel),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Open chat'));
      await _settle(tester);
      _expectOpened(h, contractBravoId);
    });

    testWidgets('live wire row opens the session that joined', (tester) async {
      final h = await _pumpList(tester, viewStyle: 'mission_control');
      // The first real update after mounting must produce a joined row.
      const golfId = 'c0ffee0007';
      const golfLabel = 'Golf review';
      h.sessions.replace(
        contractSession(
          id: golfId,
          label: golfLabel,
          presence: 'online',
          age: const Duration(seconds: 30),
        ),
      );
      await _settle(tester);
      final wireRow = find.descendant(
        of: find.byType(StreamWallSection),
        matching: find.textContaining(golfLabel, findRichText: true),
      );
      expect(wireRow, findsOneWidget);
      await tester.tap(wireRow);
      await _settle(tester);
      _expectOpened(h, golfId);
    });

    testWidgets('live wire long-press peek opens the peeked id', (
      tester,
    ) async {
      final h = await _pumpList(tester, viewStyle: 'mission_control');
      const golfId = 'c0ffee0007';
      const golfLabel = 'Golf review';
      h.sessions.replace(
        contractSession(
          id: golfId,
          label: golfLabel,
          presence: 'online',
          age: const Duration(seconds: 30),
        ),
      );
      await _settle(tester);
      final wireRow = find.descendant(
        of: find.byType(StreamWallSection),
        matching: find.textContaining(golfLabel, findRichText: true),
      );
      await tester.longPress(wireRow);
      await _settle(tester);
      expect(find.byType(SessionPeekSheet), findsOneWidget);
      await tester.tap(find.text('Open chat'));
      await _settle(tester);
      _expectOpened(h, golfId);
    });

    testWidgets('workspace drill-in reaches an archived row by id', (
      tester,
    ) async {
      final h = await _pumpList(tester, viewStyle: 'mission_control');
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
      await _tapText(tester, contractFoxtrotLabel);
      _expectOpened(h, contractFoxtrotId);
    });

    testWidgets('workspace drill-in active row opens the tapped id', (
      tester,
    ) async {
      final h = await _pumpList(tester, viewStyle: 'mission_control');
      final workspace = find.descendant(
        of: find.byType(MissionWorkspaceList),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(workspace);
      await tester.tap(workspace);
      await _settle(tester);
      // Charlie is quiet, so it was never in the focus queue above.
      await _tapText(tester, contractCharlieLabel);
      _expectOpened(h, contractCharlieId);
    });
  });
}
