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
    show NoSessionSelectedView, ResizableSplitView;
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/models/machine.dart' show GitStatus, Machine;
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/sessions/sessions_screen.dart';
import 'package:happy_flutter/features/sessions/widgets/new_session_dialog.dart';

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
  @override
  Map<String, Session> build() => const {};
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

Widget _app() {
  // SessionsScreen resolves GoRouter.of(context) in its new-session flow,
  // so the harness must sit under a router like production does.
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SessionsScreen()),
    ],
  );
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(_StubAuthNotifier.new),
      settingsNotifierProvider.overrideWith(_StubSettingsNotifier.new),
      sessionsNotifierProvider.overrideWith(_StubSessionsNotifier.new),
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

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async => null);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  void setTabletLandscape(WidgetTester tester) {
    tester.view.physicalSize = const Size(1024 * 2, 768 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(_app());
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
  });
}
