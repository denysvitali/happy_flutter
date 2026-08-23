// Pins "tapping an archived session opens that session" at the
// sessions-list layer.
//
// Every archived row is tapped by its rendered name and the session id the
// list hands to navigation (phone: the `chat` route; tablet: `onSessionTap`)
// must be the id of the session whose name was tapped. The list is then
// mutated underneath the rows (archive, reorder, search, grouping toggles)
// and tapped again, so stale closures, cache-signature collisions, and
// label/id misalignment would all surface here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/chat_switch_metrics.dart';
import 'package:happy_flutter/core/services/performance_context_service.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/session_headers.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_list_content.dart';

const _alphaPath = '/home/dev/alpha';
const _betaPath = '/home/dev/beta';

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._viewStyle);
  final String _viewStyle;
  @override
  Settings build() => Settings()..sessionsViewStyle = _viewStyle;
}

class _StubSessionsNotifier extends SessionsNotifier {
  _StubSessionsNotifier(this._initial);
  final Map<String, Session> _initial;

  @override
  Map<String, Session> build() => _initial;

  void replaceAll(Map<String, Session> sessions) {
    state = sessions;
  }
}

class _StubMachinesNotifier extends MachinesNotifier {
  @override
  Map<String, Machine> build() => const {};
}

class _StubSessionUiStateNotifier extends SessionUiStateNotifier {
  _StubSessionUiStateNotifier(this._initial);
  final SessionUiState _initial;

  @override
  SessionUiState build() => _initial;

  void replaceWith(SessionUiState next) {
    state = next;
  }
}

int _minutesAgo(int minutes) =>
    DateTime.now().subtract(Duration(minutes: minutes)).millisecondsSinceEpoch;

int _daysAgo(int days) =>
    DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

Session _session({
  required String id,
  required String name,
  required String path,
  required bool archived,
  required int at,
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: at - 1000,
    updatedAt: at,
    active: !archived,
    activeAt: archived ? at : _minutesAgo(1),
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    archived: archived,
    presence: archived ? 'offline' : 'online',
    metadata: Metadata(
      host: 'devbox',
      machineId: 'm1',
      path: path,
      summary: Summary(text: name, updatedAt: at),
    ),
  );
}

/// Two active and three archived sessions per path. Archived ages span the
/// seven-day "recent vs older" boundary used by the folder detail view and
/// the Today/Yesterday/This week/Older buckets used by date grouping.
Map<String, Session> _seedSessions() {
  final sessions = <Session>[
    _session(
      id: 'alpha-active-1',
      name: 'Alpha live one',
      path: _alphaPath,
      archived: false,
      at: _minutesAgo(2),
    ),
    _session(
      id: 'alpha-active-2',
      name: 'Alpha live two',
      path: _alphaPath,
      archived: false,
      at: _minutesAgo(5),
    ),
    _session(
      id: 'alpha-arch-1',
      name: 'Alpha archived one',
      path: _alphaPath,
      archived: true,
      at: _minutesAgo(30),
    ),
    _session(
      id: 'alpha-arch-2',
      name: 'Alpha archived two',
      path: _alphaPath,
      archived: true,
      at: _daysAgo(2),
    ),
    _session(
      id: 'alpha-arch-3',
      name: 'Alpha archived three',
      path: _alphaPath,
      archived: true,
      at: _daysAgo(40),
    ),
    _session(
      id: 'beta-active-1',
      name: 'Beta live one',
      path: _betaPath,
      archived: false,
      at: _minutesAgo(3),
    ),
    _session(
      id: 'beta-arch-1',
      name: 'Beta archived one',
      path: _betaPath,
      archived: true,
      at: _minutesAgo(45),
    ),
    _session(
      id: 'beta-arch-2',
      name: 'Beta archived two',
      path: _betaPath,
      archived: true,
      at: _daysAgo(3),
    ),
    _session(
      id: 'beta-arch-3',
      name: 'Beta archived three',
      path: _betaPath,
      archived: true,
      at: _daysAgo(60),
    ),
  ];
  return {for (final session in sessions) session.id: session};
}

SessionUiState _uiStateFor(Map<String, Session> sessions) {
  return SessionUiState(
    bySessionId: {
      for (final session in sessions.values)
        session.id: SessionUiEntry(
          lastMessageTimestamp: session.updatedAt,
          lastMessagePreview: 'preview of ${session.id}',
          lastMessageRole: 'assistant',
        ),
    },
  );
}

class _Harness {
  _Harness({
    required this.container,
    required this.selection,
    required this.folder,
    required this.router,
    required this.recordedChatIds,
    required this.tabletTapIds,
  });

  final ProviderContainer container;
  final ValueNotifier<SelectionState> selection;
  final ValueNotifier<SessionFolderHeader?> folder;
  final GoRouter router;
  final List<String> recordedChatIds;
  final List<String> tabletTapIds;

  _StubSessionsNotifier get sessions =>
      container.read(sessionsNotifierProvider.notifier)
          as _StubSessionsNotifier;

  _StubSessionUiStateNotifier get uiState =>
      container.read(sessionUiStateNotifierProvider.notifier)
          as _StubSessionUiStateNotifier;
}

Future<_Harness> _pumpHarness(
  WidgetTester tester, {
  required String viewStyle,
  required bool tablet,
  Map<String, Session>? sessions,
  String searchQuery = '',
}) async {
  final performanceContext = PerformanceContextService()
    ..setCurrentRoute('sessions');
  addTearDown(performanceContext.resetForTesting);
  tester.view.physicalSize = const Size(500, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final seeded = sessions ?? _seedSessions();
  final container = ProviderContainer(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StubSettingsNotifier(viewStyle),
      ),
      sessionsNotifierProvider.overrideWith(
        () => _StubSessionsNotifier(seeded),
      ),
      machinesNotifierProvider.overrideWith(_StubMachinesNotifier.new),
      sessionUiStateNotifierProvider.overrideWith(
        () => _StubSessionUiStateNotifier(_uiStateFor(seeded)),
      ),
    ],
  );
  final selection = ValueNotifier<SelectionState>(const SelectionState());
  final folder = ValueNotifier<SessionFolderHeader?>(null);
  final recordedChatIds = <String>[];
  final tabletTapIds = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SessionsListContent(
            selectionNotifier: selection,
            folderNotifier: folder,
            searchQuery: searchQuery,
            onSessionTap: tablet ? tabletTapIds.add : null,
          ),
        ),
      ),
      GoRoute(
        path: '/chat/:sessionId',
        name: 'chat',
        builder: (_, state) {
          final id = state.pathParameters['sessionId']!;
          recordedChatIds.add(id);
          return Scaffold(body: Text('chat:$id'));
        },
      ),
    ],
  );
  addTearDown(() {
    router.dispose();
    selection.dispose();
    folder.dispose();
    container.dispose();
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return _Harness(
    container: container,
    selection: selection,
    folder: folder,
    router: router,
    recordedChatIds: recordedChatIds,
    tabletTapIds: tabletTapIds,
  );
}

/// Taps the row rendering [name] and returns the session id the list
/// navigated to. On phone the chat route is popped again so the list is
/// back on screen for the next tap; the 400 ms navigation debounce is
/// waited out explicitly.
Future<String> _tapRow(
  WidgetTester tester,
  _Harness harness,
  String name, {
  required bool tablet,
}) async {
  final finder = find.text(name);
  expect(finder, findsOneWidget, reason: 'row "$name" must be rendered once');
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  if (tablet) {
    expect(harness.tabletTapIds, isNotEmpty, reason: 'tap on "$name" ignored');
    final id = harness.tabletTapIds.last;
    harness.tabletTapIds.clear();
    ChatSwitchMetrics().cancel(id);
    return id;
  }
  await tester.pump(const Duration(milliseconds: 400));
  expect(
    harness.recordedChatIds,
    isNotEmpty,
    reason: 'tap on "$name" did not open a chat route',
  );
  final id = harness.recordedChatIds.last;
  harness.recordedChatIds.clear();
  ChatSwitchMetrics().cancel(id);
  harness.router.pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return id;
}

Future<void> _openFolder(WidgetTester tester, String label) async {
  final finder = find.text(label);
  expect(finder, findsOneWidget);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final finder = find.text(label);
  expect(finder, findsOneWidget, reason: 'button "$label"');
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _expectArchivedRowsRoute(
  WidgetTester tester,
  _Harness harness,
  Map<String, Session> sessions, {
  required bool tablet,
  required Iterable<String> ids,
}) async {
  for (final id in ids) {
    final name = sessions[id]!.metadata!.summary!.text;
    final opened = await _tapRow(tester, harness, name, tablet: tablet);
    expect(opened, id, reason: 'tapping "$name" must open $id');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The debounce compares wall-clock time, which widget tests do not
    // fake; taps in this file are intentionally back to back.
    SessionsListContent.navDebounceMs = 0;
  });
  tearDown(() {
    SessionsListContent.navDebounceMs = 400;
  });

  for (final tablet in [false, true]) {
    final mode = tablet ? 'tablet callback' : 'phone route';

    group('folder detail archived rows ($mode)', () {
      testWidgets('every archived row opens the session it names', (
        tester,
      ) async {
        final harness = await _pumpHarness(
          tester,
          viewStyle: 'folder',
          tablet: tablet,
        );
        await _openFolder(tester, 'alpha');
        await _tapButton(tester, 'Show archived (3)');
        // Recent bucket (< 7 days): archived one + two. Older bucket is
        // collapsed behind its own button.
        expect(find.text('Alpha archived three'), findsNothing);
        await _expectArchivedRowsRoute(
          tester,
          harness,
          _seedSessions(),
          tablet: tablet,
          ids: ['alpha-arch-1', 'alpha-arch-2'],
        );
        await _tapButton(tester, 'Show older archived (1)');
        await _expectArchivedRowsRoute(
          tester,
          harness,
          _seedSessions(),
          tablet: tablet,
          ids: ['alpha-arch-3', 'alpha-arch-2', 'alpha-arch-1'],
        );
      });

      testWidgets('rows stay correct after archive, reorder and search', (
        tester,
      ) async {
        final sessions = Map<String, Session>.from(_seedSessions());
        final harness = await _pumpHarness(
          tester,
          viewStyle: 'folder',
          tablet: tablet,
        );
        await _openFolder(tester, 'beta');
        await _tapButton(tester, 'Show archived (3)');
        await _tapButton(tester, 'Show older archived (1)');
        await _expectArchivedRowsRoute(
          tester,
          harness,
          sessions,
          tablet: tablet,
          ids: ['beta-arch-1', 'beta-arch-2', 'beta-arch-3'],
        );

        // Archive the live beta session: it moves from the active group
        // into the archived group, shifting every archived row down by one.
        final archivedLive = sessions['beta-active-1']!.copyWith(
          archived: true,
          active: false,
          presence: 'offline',
          updatedAt: _minutesAgo(10),
        );
        sessions['beta-active-1'] = archivedLive;
        harness.sessions.replaceAll(Map<String, Session>.from(sessions));
        harness.uiState.replaceWith(_uiStateFor(sessions));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Hide archived'), findsOneWidget);
        await _expectArchivedRowsRoute(
          tester,
          harness,
          sessions,
          tablet: tablet,
          ids: ['beta-active-1', 'beta-arch-1', 'beta-arch-2', 'beta-arch-3'],
        );

        // Reorder by bumping the oldest archived session's last message so
        // it jumps to the top of the recent bucket.
        final bumped = _uiStateFor(sessions);
        final entries = Map<String, SessionUiEntry>.from(bumped.bySessionId);
        entries['beta-arch-3'] = SessionUiEntry(
          lastMessageTimestamp: _minutesAgo(1),
          lastMessagePreview: 'bumped',
          lastMessageRole: 'user',
        );
        harness.uiState.replaceWith(SessionUiState(bySessionId: entries));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await _expectArchivedRowsRoute(
          tester,
          harness,
          sessions,
          tablet: tablet,
          ids: ['beta-arch-3', 'beta-active-1', 'beta-arch-1', 'beta-arch-2'],
        );
      });
    });

    group('mission control workspace archived rows ($mode)', () {
      testWidgets('archived rows inside a workspace open the named session', (
        tester,
      ) async {
        final harness = await _pumpHarness(
          tester,
          viewStyle: 'mission_control',
          tablet: tablet,
        );
        await _openFolder(tester, 'dev/alpha');
        await _tapButton(tester, 'Show archived (3)');
        await _tapButton(tester, 'Show older archived (1)');
        await _expectArchivedRowsRoute(
          tester,
          harness,
          _seedSessions(),
          tablet: tablet,
          ids: ['alpha-arch-2', 'alpha-arch-3', 'alpha-arch-1'],
        );
      });
    });

    group('legacy list archived section ($mode)', () {
      testWidgets('date-grouped archived cards open the named session', (
        tester,
      ) async {
        final harness = await _pumpHarness(
          tester,
          viewStyle: 'list',
          tablet: tablet,
        );
        expect(find.text('History'), findsOneWidget);
        await _expectArchivedRowsRoute(
          tester,
          harness,
          _seedSessions(),
          tablet: tablet,
          ids: [
            'alpha-arch-1',
            'beta-arch-1',
            'alpha-arch-2',
            'beta-arch-2',
            'alpha-arch-3',
            'beta-arch-3',
          ],
        );
      });

      testWidgets('folder-grouped archived cards open the named session', (
        tester,
      ) async {
        final harness = await _pumpHarness(
          tester,
          viewStyle: 'list',
          tablet: tablet,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(ArchiveSectionHeader),
            matching: find.byIcon(Icons.folder_outlined),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await _expectArchivedRowsRoute(
          tester,
          harness,
          _seedSessions(),
          tablet: tablet,
          ids: [
            'beta-arch-3',
            'alpha-arch-1',
            'beta-arch-1',
            'alpha-arch-3',
            'beta-arch-2',
            'alpha-arch-2',
          ],
        );
      });

      testWidgets('archived cards survive a search query and an archive', (
        tester,
      ) async {
        final sessions = Map<String, Session>.from(_seedSessions());
        final harness = await _pumpHarness(
          tester,
          viewStyle: 'list',
          tablet: tablet,
          searchQuery: 'Beta',
        );
        expect(find.text('Alpha archived one'), findsNothing);
        await _expectArchivedRowsRoute(
          tester,
          harness,
          sessions,
          tablet: tablet,
          ids: ['beta-arch-1', 'beta-arch-2', 'beta-arch-3'],
        );

        final archivedLive = sessions['beta-active-1']!.copyWith(
          archived: true,
          active: false,
          presence: 'offline',
          updatedAt: _minutesAgo(10),
        );
        sessions['beta-active-1'] = archivedLive;
        harness.sessions.replaceAll(Map<String, Session>.from(sessions));
        harness.uiState.replaceWith(_uiStateFor(sessions));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await _expectArchivedRowsRoute(
          tester,
          harness,
          sessions,
          tablet: tablet,
          ids: ['beta-active-1', 'beta-arch-1', 'beta-arch-2', 'beta-arch-3'],
        );
      });
    });
  }

  for (final tablet in [false, true]) {
    final mode = tablet ? 'tablet callback' : 'phone route';

    testWidgets('a press in flight while the folder rows shift never opens '
        'a different session ($mode)', (tester) async {
      final sessions = Map<String, Session>.from(_seedSessions());
      final harness = await _pumpHarness(
        tester,
        viewStyle: 'folder',
        tablet: tablet,
      );
      await _openFolder(tester, 'alpha');
      await _tapButton(tester, 'Show archived (3)');
      await _tapButton(tester, 'Show older archived (1)');

      // Finger down on "archived two", then the row above it disappears
      // before the finger lifts. Either the press resolves to the pressed
      // session or it is dropped — it must never resolve to the row that
      // slid into that slot.
      final pressed = find.text('Alpha archived two');
      await tester.ensureVisible(pressed);
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(pressed));
      await tester.pump(const Duration(milliseconds: 50));
      sessions.remove('alpha-arch-1');
      harness.sessions.replaceAll(Map<String, Session>.from(sessions));
      harness.uiState.replaceWith(_uiStateFor(sessions));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final opened = tablet ? harness.tabletTapIds : harness.recordedChatIds;
      expect(
        opened,
        anyOf(isEmpty, equals(['alpha-arch-2'])),
        reason: 'a shifted row must not hijack an in-flight press',
      );
      for (final id in opened) {
        ChatSwitchMetrics().cancel(id);
      }
      if (!tablet && opened.isNotEmpty) {
        harness.router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
      harness.tabletTapIds.clear();
      harness.recordedChatIds.clear();

      // Whatever happened to the in-flight press, fresh taps must be exact.
      await _expectArchivedRowsRoute(
        tester,
        harness,
        sessions,
        tablet: tablet,
        ids: ['alpha-arch-2', 'alpha-arch-3'],
      );
    });

    testWidgets('a press in flight while the list shifts never opens a '
        'different session ($mode)', (tester) async {
      final sessions = Map<String, Session>.from(_seedSessions());
      final harness = await _pumpHarness(
        tester,
        viewStyle: 'list',
        tablet: tablet,
      );
      final pressed = find.text('Beta archived one');
      await tester.ensureVisible(pressed);
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(pressed));
      await tester.pump(const Duration(milliseconds: 50));
      sessions.remove('alpha-arch-1');
      harness.sessions.replaceAll(Map<String, Session>.from(sessions));
      harness.uiState.replaceWith(_uiStateFor(sessions));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final opened = tablet ? harness.tabletTapIds : harness.recordedChatIds;
      expect(opened, anyOf(isEmpty, equals(['beta-arch-1'])));
      for (final id in opened) {
        ChatSwitchMetrics().cancel(id);
      }
      if (!tablet && opened.isNotEmpty) {
        harness.router.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
      harness.tabletTapIds.clear();
      harness.recordedChatIds.clear();
      await _expectArchivedRowsRoute(
        tester,
        harness,
        sessions,
        tablet: tablet,
        ids: ['beta-arch-1', 'alpha-arch-2', 'beta-arch-3'],
      );
    });

    testWidgets('collapsing and re-expanding archived groups keeps every '
        'row on its own session ($mode)', (tester) async {
      final harness = await _pumpHarness(
        tester,
        viewStyle: 'list',
        tablet: tablet,
      );
      // Collapse "Today" (holds alpha/beta archived one), tap the rows that
      // are left, expand it again, then tap the ones that came back.
      await _tapButton(tester, 'Today');
      expect(find.text('Alpha archived one'), findsNothing);
      await _expectArchivedRowsRoute(
        tester,
        harness,
        _seedSessions(),
        tablet: tablet,
        ids: ['alpha-arch-2', 'beta-arch-3'],
      );
      await _tapButton(tester, 'Today');
      await _expectArchivedRowsRoute(
        tester,
        harness,
        _seedSessions(),
        tablet: tablet,
        ids: ['beta-arch-1', 'alpha-arch-1', 'beta-arch-2'],
      );

      // Switch the archived grouping to folders and back to dates; the
      // list-item cache must be rebuilt for each layout.
      await tester.tap(
        find.descendant(
          of: find.byType(ArchiveSectionHeader),
          matching: find.byIcon(Icons.folder_outlined),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _expectArchivedRowsRoute(
        tester,
        harness,
        _seedSessions(),
        tablet: tablet,
        ids: ['alpha-arch-3', 'beta-arch-2'],
      );
      await tester.tap(
        find.descendant(
          of: find.byType(ArchiveSectionHeader),
          matching: find.byIcon(Icons.calendar_today_outlined),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _expectArchivedRowsRoute(
        tester,
        harness,
        _seedSessions(),
        tablet: tablet,
        ids: ['beta-arch-3', 'alpha-arch-1'],
      );
    });

    testWidgets('hiding and re-showing folder archived rows keeps every row '
        'on its own session ($mode)', (tester) async {
      final harness = await _pumpHarness(
        tester,
        viewStyle: 'folder',
        tablet: tablet,
      );
      await _openFolder(tester, 'beta');
      await _tapButton(tester, 'Show archived (3)');
      await _tapButton(tester, 'Show older archived (1)');
      await _tapButton(tester, 'Hide archived');
      expect(find.text('Beta archived one'), findsNothing);
      await _tapButton(tester, 'Show archived (3)');
      // The older bucket collapses again with the whole section.
      expect(find.text('Beta archived three'), findsNothing);
      await _expectArchivedRowsRoute(
        tester,
        harness,
        _seedSessions(),
        tablet: tablet,
        ids: ['beta-arch-2', 'beta-arch-1'],
      );
      await _tapButton(tester, 'Show older archived (1)');
      await _expectArchivedRowsRoute(
        tester,
        harness,
        _seedSessions(),
        tablet: tablet,
        ids: ['beta-arch-3', 'beta-arch-1'],
      );
    });
  }

  testWidgets('the phone navigation debounce drops a rapid second tap '
      'instead of replaying the first session', (tester) async {
    SessionsListContent.navDebounceMs = 400;
    final harness = await _pumpHarness(
      tester,
      viewStyle: 'folder',
      tablet: false,
    );
    await _openFolder(tester, 'alpha');
    await _tapButton(tester, 'Show archived (3)');

    await tester.tap(find.text('Alpha archived one'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(harness.recordedChatIds, ['alpha-arch-1']);
    ChatSwitchMetrics().cancel('alpha-arch-1');
    harness.recordedChatIds.clear();
    harness.router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Pumped time is fake; wall-clock time since the first tap is well
    // under the debounce window on any reasonable runner, so this tap is
    // dropped. On a starved runner it may land — either way it must never
    // reopen the previously tapped session.
    await tester.tap(find.text('Alpha archived two'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(harness.recordedChatIds, anyOf(isEmpty, equals(['alpha-arch-2'])));
    for (final id in harness.recordedChatIds) {
      ChatSwitchMetrics().cancel(id);
    }
  });

  testWidgets('archived row label and id stay aligned when another row is '
      'removed above it', (tester) async {
    final sessions = Map<String, Session>.from(_seedSessions());
    final harness = await _pumpHarness(
      tester,
      viewStyle: 'folder',
      tablet: true,
    );
    await _openFolder(tester, 'alpha');
    await _tapButton(tester, 'Show archived (3)');
    await _tapButton(tester, 'Show older archived (1)');

    // Delete the first archived row; the remaining rows must still route
    // to themselves rather than to the removed neighbour's slot.
    sessions.remove('alpha-arch-1');
    harness.sessions.replaceAll(Map<String, Session>.from(sessions));
    harness.uiState.replaceWith(_uiStateFor(sessions));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Alpha archived one'), findsNothing);
    await _expectArchivedRowsRoute(
      tester,
      harness,
      sessions,
      tablet: true,
      ids: ['alpha-arch-2', 'alpha-arch-3'],
    );
    expect(getSessionName(sessions['alpha-arch-2']!), 'Alpha archived two');
  });
}
