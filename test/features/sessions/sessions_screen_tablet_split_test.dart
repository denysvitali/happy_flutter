// Wiring coverage for the tablet branch of `SessionsScreen`.
//
// The split-view component itself is covered in
// `test/core/components/tablet/resizable_split_view_test.dart` with a
// synthetic harness; this file pins the actual screen wiring: the sessions
// tab renders `ResizableSplitView` with the persisted pane id, and the empty
// detail pane is a `NoSessionSelectedView` whose call to action opens the
// new-session dialog.

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/components/components.dart'
    show AppSidebar, NoSessionSelectedView, ResizableSplitView;
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/models/machine.dart' show GitStatus, Machine;
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/models/provider_usage.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/core/ui/tab_bar/tab_bar.dart' show AppTab;
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:happy_flutter/features/sessions/sessions_screen.dart';
import 'package:happy_flutter/features/sessions/widgets/new_session_dialog.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_list_content.dart';

class _StubAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated;
}

class _StubSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings();
  @override
  Future<void> updateSetting<T>(String key, T value) async {}
}

class _StubSessionsNotifier extends SessionsNotifier {
  _StubSessionsNotifier([this._initial = const {}]);

  final Map<String, Session> _initial;

  @override
  Map<String, Session> build() => SessionCollectionSnapshot(_initial);

  void publish(Map<String, Session> sessions) {
    state = SessionCollectionSnapshot(sessions);
  }
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}
}

class _StubMachinesNotifier extends MachinesNotifier {
  @override
  Map<String, Machine> build() => const {};
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync() async {}
}

class _StubConnectionNotifier extends ConnectionNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.connected;
}

class _StubNetworkNotifier extends NetworkNotifier {
  @override
  bool build() => true;
}

class _StubProfileNotifier extends ProfileNotifier {
  @override
  Profile? build() => Profile(id: 'user-1', firstName: 'Alex');
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync() async {}
}

class _StubCurrentSessionNotifier extends CurrentSessionNotifier {
  @override
  Session? build() => null;
}

class _StubSessionGitStatusNotifier extends SessionGitStatusNotifier {
  @override
  Map<String, GitStatus> build() => const {};
}

class _StubLoopsNotifier extends LoopsNotifier {
  @override
  Map<String, List<Loop>> build() => const <String, List<Loop>>{};

  @override
  bool hydrateFromCache() => false;

  @override
  Future<void> refreshFromSync() async {}
}

class _StubProviderUsageNotifier extends ProviderUsageNotifier {
  @override
  ProviderUsageSummary build() => const ProviderUsageSummary();

  @override
  Future<void> loadAccounts() async {}

  @override
  Future<void> refreshUsage() async {}
}

Session _session(String id, {required int activeAt, bool archived = false}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: activeAt,
    updatedAt: activeAt,
    active: !archived,
    activeAt: activeAt,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    archived: archived,
    presence: 'offline',
    metadata: const Metadata(
      path: '/home/dev/app',
      machineId: 'm1',
      host: 'm1-host',
      homeDir: '/home/dev',
    ),
  );
}

Widget _app({Map<String, Session> sessions = const {}}) {
  // SessionsScreen resolves GoRouter.of(context) in its new-session flow,
  // so the harness must sit under a router like production does.
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const SessionsScreen())],
  );
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(_StubAuthNotifier.new),
      settingsNotifierProvider.overrideWith(_StubSettingsNotifier.new),
      sessionsNotifierProvider.overrideWith(
        () => _StubSessionsNotifier(sessions),
      ),
      machinesNotifierProvider.overrideWith(_StubMachinesNotifier.new),
      connectionNotifierProvider.overrideWith(_StubConnectionNotifier.new),
      networkNotifierProvider.overrideWith(_StubNetworkNotifier.new),
      profileNotifierProvider.overrideWith(_StubProfileNotifier.new),
      currentSessionNotifierProvider.overrideWith(
        _StubCurrentSessionNotifier.new,
      ),
      sessionGitStatusNotifierProvider.overrideWith(
        _StubSessionGitStatusNotifier.new,
      ),
      loopsNotifierProvider.overrideWith(_StubLoopsNotifier.new),
      providerUsageNotifierProvider.overrideWith(
        _StubProviderUsageNotifier.new,
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  const ttsChannel = MethodChannel('flutter_tts');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async => 1);
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    await TtsService().dispose();
  });

  void setTabletLandscape(WidgetTester tester) {
    tester.view.physicalSize = const Size(1024 * 2, 768 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    Map<String, Session> sessions = const {},
  }) async {
    await tester.pumpWidget(_app(sessions: sessions));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('tablet sessions tab renders the persisted split view', (
    tester,
  ) async {
    setTabletLandscape(tester);
    await pumpScreen(tester);

    final splitView = tester.widget<ResizableSplitView>(
      find.byType(ResizableSplitView),
    );
    expect(splitView.paneId, sessionsPaneId);
    expect(splitView.dividerSemanticsLabel, isNotNull);
    expect(find.byType(AppSidebar), findsOneWidget);
  });

  testWidgets('tablet rail keeps every top-level destination reachable', (
    tester,
  ) async {
    setTabletLandscape(tester);
    await pumpScreen(tester);

    final sidebar = tester.widget<AppSidebar>(find.byType(AppSidebar));
    expect(sidebar.isCollapsed, isFalse);
    expect(sidebar.showCollapseToggle, isTrue);

    sidebar.onTabPress(AppTab.loops);
    await tester.pump();
    expect(find.text('Loops'), findsWidgets);

    sidebar.onTabPress(AppTab.providers);
    await tester.pump();
    expect(find.text('Providers'), findsWidgets);

    sidebar.onTabPress(AppTab.settings);
    await tester.pump();
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('compact tablet uses rail with intentional single-pane layout', (
    tester,
  ) async {
    setSize(tester, const Size(620, 900));
    await pumpScreen(tester);

    final sidebar = tester.widget<AppSidebar>(find.byType(AppSidebar));
    expect(sidebar.isCollapsed, isTrue);
    expect(sidebar.showCollapseToggle, isFalse);
    expect(find.byType(ResizableSplitView), findsNothing);
    expect(find.text('Sessions'), findsOneWidget);
  });

  testWidgets('empty detail pane offers the new-session call to action', (
    tester,
  ) async {
    setTabletLandscape(tester);
    await pumpScreen(tester);

    expect(find.byType(NoSessionSelectedView), findsOneWidget);
    final view = tester.widget<NoSessionSelectedView>(
      find.byType(NoSessionSelectedView),
    );
    expect(view.onCreateSession, isNotNull);

    await tester.tap(
      find.descendant(
        of: find.byType(NoSessionSelectedView),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NewSessionDialog), findsOneWidget);

    // Dismiss so the dialog's async work does not outlive the test.
    // Bounded pumps only: the AppEmptyState behind the dialog runs a
    // repeating breathe animation, so pumpAndSettle never settles.
    Navigator.of(tester.element(find.byType(NewSessionDialog))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('phone width keeps the single-pane layout', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await pumpScreen(tester);

    expect(find.byType(ResizableSplitView), findsNothing);
    expect(find.byType(NoSessionSelectedView), findsNothing);
    expect(find.byType(AppSidebar), findsNothing);
  });

  group('master-detail selection', () {
    final live = _session('live', activeAt: 2000);
    final archived = _session('archived', activeAt: 1000, archived: true);

    testWidgets('auto-selects the most recent live session on entry', (
      tester,
    ) async {
      setTabletLandscape(tester);
      await pumpScreen(tester, sessions: {live.id: live, archived.id: archived});

      final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(chat.sessionId, 'live');
    });

    testWidgets('tapping an archived session opens that session, not the '
        'most recent live one', (tester) async {
      setTabletLandscape(tester);
      await pumpScreen(tester, sessions: {live.id: live, archived.id: archived});

      final list = tester.widget<SessionsListContent>(
        find.byType(SessionsListContent),
      );
      list.onSessionTap!('archived');
      // Several frames: the auto-selection guard runs in a post-frame
      // callback, so a regression only shows up one frame later.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(chat.sessionId, 'archived');
      expect(chat.key, const ValueKey<String>('archived'));
    });

    testWidgets('a selection that leaves the collection falls back to the '
        'most recent live session', (tester) async {
      setTabletLandscape(tester);
      await pumpScreen(tester, sessions: {live.id: live, archived.id: archived});
      final list = tester.widget<SessionsListContent>(
        find.byType(SessionsListContent),
      );
      list.onSessionTap!('archived');
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).sessionId,
        'archived',
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SessionsScreen)),
      );
      final notifier =
          container.read(sessionsNotifierProvider.notifier)
              as _StubSessionsNotifier;
      notifier.publish({live.id: live});
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).sessionId,
        'live',
      );
    });
  });

  test('TabletSessionSelectionProjection knows archived sessions', () {
    final projection = TabletSessionSelectionProjection.fromSessions({
      'live': _session('live', activeAt: 2000),
      'archived': _session('archived', activeAt: 1000, archived: true),
    });
    expect(projection.sessionIds, ['live']);
    expect(projection.contains('live'), isTrue);
    expect(projection.contains('archived'), isTrue);
    expect(projection.contains('gone'), isFalse);
  });
}
