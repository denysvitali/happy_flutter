part of 'sessions_list_archived_tap_test.dart';

const _alphaPath = '/home/dev/alpha';
const _betaPath = '/home/dev/beta';

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._viewStyle, {this.hideInactive});
  final String _viewStyle;
  final bool? hideInactive;
  @override
  Settings build() {
    final settings = Settings()..sessionsViewStyle = _viewStyle;
    if (hideInactive case final value?) settings.hideInactiveSessions = value;
    return settings;
  }
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
  bool? hideInactive,
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
        () => _StubSettingsNotifier(viewStyle, hideInactive: hideInactive),
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
