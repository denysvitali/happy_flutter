// Wiring coverage for the tablet branch of `SessionsScreen`.
//
// The split-view component itself is covered in
// `test/core/components/tablet/resizable_split_view_test.dart` with a
// synthetic harness; this file pins the actual screen wiring: the sessions
// tab renders `ResizableSplitView` with the persisted pane id, and the empty
// detail pane is a `NoSessionSelectedView` whose call to action opens the
// new-session dialog.

import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/api/sessions_api.dart';
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
import 'package:happy_flutter/core/widgets/app_linear_progress_indicator.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:happy_flutter/features/sessions/sessions_screen.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_action_tile.dart';
import 'package:happy_flutter/features/sessions/widgets/new_session_dialog.dart';
import 'package:happy_flutter/features/sessions/widgets/session_collection_app_bar.dart';
import 'package:happy_flutter/features/sessions/widgets/session_list_helpers.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_list_content.dart';

part 'sessions_batch_actions_cases.dart';

class _StubAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated;
}

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this.viewStyle, {this.hideInactive});
  final String viewStyle;
  final bool? hideInactive;
  @override
  Settings build() {
    final settings = Settings()..sessionsViewStyle = viewStyle;
    if (hideInactive case final value?) settings.hideInactiveSessions = value;
    return settings;
  }

  @override
  Future<void> updateSetting<T>(String key, T value) async {}
}

class _StubSessionsNotifier extends SessionsNotifier {
  _StubSessionsNotifier([this._initial = const {}, this.onBatchDelete]);

  final Map<String, Session> _initial;
  final Future<int> Function(List<String>)? onBatchDelete;
  final archivedIds = <String>[];
  int refreshCount = 0;

  @override
  Map<String, Session> build() => SessionCollectionSnapshot(_initial);

  void publish(Map<String, Session> sessions) {
    state = SessionCollectionSnapshot(sessions);
  }

  @override
  void loadFromSync() => refreshCount++;
  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}

  @override
  Future<int> optimisticBatchDelete(List<String> ids) =>
      onBatchDelete?.call(ids) ?? Future<int>.value(0);

  @override
  Future<void> markSessionArchived(String id, bool archived) async {
    if (archived) archivedIds.add(id);
  }
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

Widget _app({
  Map<String, Session> sessions = const {},
  TextScaler textScaler = TextScaler.noScaling,
  String viewStyle = 'mission_control',
  bool? hideInactive,
  Future<int> Function(List<String>)? onBatchDelete,
  SessionsApi? sessionsApi,
}) {
  // SessionsScreen resolves GoRouter.of(context) in its new-session flow,
  // so the harness must sit under a router like production does.
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => SessionsScreen(sessionsApi: sessionsApi),
      ),
      GoRoute(
        path: '/link',
        name: 'link',
        builder: (_, _) => const Scaffold(body: Text('Connect computer')),
      ),
      GoRoute(
        path: '/machines',
        name: 'machines',
        builder: (_, _) => const Scaffold(body: Text('View computers')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(_StubAuthNotifier.new),
      settingsNotifierProvider.overrideWith(
        () => _StubSettingsNotifier(viewStyle, hideInactive: hideInactive),
      ),
      sessionsNotifierProvider.overrideWith(
        () => _StubSessionsNotifier(sessions, onBatchDelete),
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _registerBatchActionTests();
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

  testWidgets('session header fits narrow screens with large text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      setSize(tester, const Size(320, 900));
      final now = DateTime.now().millisecondsSinceEpoch;
      await tester.pumpWidget(
        _app(
          sessions: {'one': _session('one', activeAt: now)},
          textScaler: const TextScaler.linear(2),
          viewStyle: 'status',
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.widget<AppBar>(find.byType(AppBar)).bottom, isNull);
      expect(find.byTooltip('View: Inbox'), findsOneWidget);
      expect(
        tester.getSemantics(find.byTooltip('View: Inbox')),
        containsSemantics(isButton: true, hasTapAction: true),
      );
      await tester.tap(find.byTooltip('View: Inbox'));
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('app'));
      await tester.pump();
      expect(find.text('1 selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('quiet sessions occupy the phone instead of redundant controls', (
    tester,
  ) async {
    setSize(tester, const Size(360, 800));
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _app(
        viewStyle: 'status',
        sessions: {
          for (var i = 0; i < 7; i++)
            'quiet-$i': _session('quiet-$i', activeAt: now - i * 60000)
                .copyWith(
                  metadata: Metadata(
                    path: '/home/dev/app',
                    host: '(none)',
                    flavor: 'codex',
                    summary: Summary(text: 'Recent session $i', updatedAt: now),
                  ),
                ),
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getTopLeft(find.text('Recent session 0')).dy, lessThan(180));
    expect(find.text('Recent session 6'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Recent session 6')).dy,
      lessThan(720),
    );
    expect(find.text('All clear'), findsNothing);
    expect(find.text('Show 2 more'), findsNothing);
    expect(find.text('(none)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search-scoped Select all includes only matching conversations', (
    tester,
  ) async {
    setSize(tester, const Size(390, 844));
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _app(
        viewStyle: 'unread_focus',
        sessions: {
          for (final name in ['Alpha one', 'Alpha two', 'Beta'])
            name: _session(name, activeAt: now).copyWith(
              metadata: Metadata(
                path: '/home/dev/app',
                summary: Summary(text: name, updatedAt: now),
              ),
            ),
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Beta'), findsNothing);
    await tester.longPress(find.text('Alpha one'));
    await tester.pump();
    await tester.tap(find.text('Select All'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('3 selected'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large-text search fits, clears and closes with Escape', (
    tester,
  ) async {
    setSize(tester, const Size(320, 900));
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _app(
        viewStyle: 'status',
        textScaler: const TextScaler.linear(2),
        sessions: {'one': _session('one', activeAt: now)},
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    final editable = tester.getRect(find.byType(EditableText));
    final input = tester.getRect(field);
    expect(editable.top, greaterThanOrEqualTo(input.top));
    expect(editable.bottom, lessThanOrEqualTo(input.bottom));
    await tester.enterText(field, 'missing project');
    await tester.pump();
    expect(find.byTooltip('Clear'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('View: Inbox'), findsOneWidget);
    expect(find.text('app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection excludes conversations hidden by a sync update', (
    tester,
  ) async {
    setSize(tester, const Size(390, 844));
    final now = DateTime.now().millisecondsSinceEpoch;
    final sessions = {
      for (final name in ['Alpha one', 'Alpha two'])
        name: _session(name, activeAt: now).copyWith(
          metadata: Metadata(
            path: '/home/dev/app',
            summary: Summary(text: name, updatedAt: now),
          ),
        ),
    };
    await tester.pumpWidget(
      _app(sessions: sessions, viewStyle: 'unread_focus', hideInactive: true),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.longPress(find.text('Alpha one'));
    await tester.pump();
    expect(find.text('Select All'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SessionsScreen)),
    );
    final notifier =
        container.read(sessionsNotifierProvider.notifier)
            as _StubSessionsNotifier;
    notifier.publish({
      ...sessions,
      'Alpha two': sessions['Alpha two']!.copyWith(
        active: false,
        archived: true,
        presence: 'offline',
      ),
    });
    await tester.pump();
    await tester.pump();
    expect(find.text('Alpha two'), findsNothing);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Select All'), findsNothing);
    expect(find.text('Deselect All'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('empty detail pane sends first-time users to computer setup', (
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

    expect(find.text('Connect computer'), findsOneWidget);
    expect(find.byType(NewSessionDialog), findsNothing);
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

    testWidgets(
      'list toggle keeps selected chat mounted on desktop and tablet',
      (tester) async {
        setTabletLandscape(tester);
        await pumpScreen(tester, sessions: {live.id: live});
        final chatState = tester.state(find.byType(ChatScreen));
        final listState = tester.state(find.byType(SessionsListContent));
        final split = tester.widget<ResizableSplitView>(
          find.byType(ResizableSplitView),
        );
        expect(split.collapseBreakpoint, 736);
        await tester.tap(find.widgetWithText(TextButton, 'Hide sessions'));
        await tester.pump();
        expect(find.byType(SessionsListContent), findsNothing);
        expect(tester.state(find.byType(ChatScreen)), same(chatState));
        tester.view.physicalSize = const Size(800 * 2, 768 * 2);
        await tester.pump();
        await tester.tap(find.widgetWithText(TextButton, 'Show sessions'));
        await tester.pump();
        expect(tester.state(find.byType(SessionsListContent)), same(listState));
        expect(tester.state(find.byType(ChatScreen)), same(chatState));
        expect(
          tester.widget<ChatScreen>(find.byType(ChatScreen)).sessionId,
          'live',
        );

        // Phone navigation owns the conversation below the split breakpoint;
        // returning to a wide layout retains the shell's selected session.
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        await tester.pump();
        expect(find.byType(ResizableSplitView), findsNothing);
        expect(find.widgetWithText(TextButton, 'Hide sessions'), findsNothing);
        tester.view.physicalSize = const Size(1024 * 2, 768 * 2);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          tester.widget<ChatScreen>(find.byType(ChatScreen)).sessionId,
          'live',
        );
      },
    );

    testWidgets('auto-selects the most recent live session on entry', (
      tester,
    ) async {
      setTabletLandscape(tester);
      await pumpScreen(
        tester,
        sessions: {live.id: live, archived.id: archived},
      );

      final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(chat.sessionId, 'live');
    });

    testWidgets('tapping an archived session opens that session, not the '
        'most recent live one', (tester) async {
      setTabletLandscape(tester);
      await pumpScreen(
        tester,
        sessions: {live.id: live, archived.id: archived},
      );

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
      await pumpScreen(
        tester,
        sessions: {live.id: live, archived.id: archived},
      );
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
