// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/websocket_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart' show GitStatus, Machine;
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
// ThemeHelper uses google_fonts which requires bundled assets in tests.
// We build equivalent themes without google_fonts for golden rendering.
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/sessions/sessions_screen.dart';
import 'package:happy_flutter/features/settings/settings_screen.dart';

// ─── Stub Notifiers ───────────────────────────────────────────────────────────

class _StubAuthNotifier extends AuthStateNotifier {
  _StubAuthNotifier(this._state);
  final AuthState _state;
  @override
  AuthState build() => _state;
}

class _StubSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings();
  @override
  Future<void> updateSetting<T>(String key, T value) async {}
}

class _StubSessionsNotifier extends SessionsNotifier {
  _StubSessionsNotifier(this._sessions);
  final Map<String, Session> _sessions;
  @override
  Map<String, Session> build() => _sessions;
  @override
  void loadFromSync() {} // keep stub state
  @override
  Future<void> refreshFromSync() async {} // keep stub state
}

class _StubMachinesNotifier extends MachinesNotifier {
  @override
  Map<String, Machine> build() => {};
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync() async {}
}

class _StubConnectionNotifier extends ConnectionNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.disconnected;
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
  Map<String, GitStatus> build() => {};
}

class _StubFriendsNotifier extends FriendsNotifier {
  @override
  FriendsState build() => FriendsState();
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync() async {}
}

class _StubFeedNotifier extends FeedNotifier {
  @override
  FeedState build() => FeedState();
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync() async {}
}

class _StubTodoStateNotifier extends TodoStateNotifier {
  @override
  TodoListState build() => TodoListState();
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync() async {}
}

// ─── Test themes (no google_fonts — uses system fonts) ───────────────────────

ThemeData _testLightTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF2563EB),
      scaffoldBackgroundColor: const Color(0xFFF8FAFF),
    );

ThemeData _testDarkTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF2563EB),
      scaffoldBackgroundColor: const Color(0xFF0F1117),
    );

// ─── Helpers ──────────────────────────────────────────────────────────────────

Session _makeSession({
  required String id,
  String host = 'macbook-pro.local',
  String path = '/Users/user/project',
  String? name,
  bool active = false,
  bool thinking = false,
  String presence = 'offline',
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1700000000000,
    updatedAt: 1700050000000,
    active: active,
    activeAt: 1700050000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: presence,
    metadata: Metadata(host: host, path: path, name: name),
  );
}

// ignore: type_annotate_public_apis
_commonOverrides(Map<String, Session> sessions) => [
      authStateNotifierProvider
          .overrideWith(() => _StubAuthNotifier(AuthState.authenticated)),
      settingsNotifierProvider.overrideWith(() => _StubSettingsNotifier()),
      sessionsNotifierProvider
          .overrideWith(() => _StubSessionsNotifier(sessions)),
      machinesNotifierProvider.overrideWith(() => _StubMachinesNotifier()),
      connectionNotifierProvider.overrideWith(() => _StubConnectionNotifier()),
      profileNotifierProvider.overrideWith(() => _StubProfileNotifier()),
      currentSessionNotifierProvider
          .overrideWith(() => _StubCurrentSessionNotifier()),
      sessionGitStatusProvider
          .overrideWith(() => _StubSessionGitStatusNotifier()),
      friendsNotifierProvider.overrideWith(() => _StubFriendsNotifier()),
      feedNotifierProvider.overrideWith(() => _StubFeedNotifier()),
      todoStateNotifierProvider.overrideWith(() => _StubTodoStateNotifier()),
    ];

Widget _buildApp(
  Widget child, {
  bool dark = false,
  Map<String, Session> sessions = const {},
}) {
  return ProviderScope(
    overrides: _commonOverrides(sessions),
    child: MaterialApp(
      theme: _testLightTheme(),
      darkTheme: _testDarkTheme(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [AppLocalizationsDelegate()],
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

// ─── Mock data ────────────────────────────────────────────────────────────────

final _mockSessions = {
  's1': _makeSession(
    id: 's1',
    host: 'mbp-work.local',
    path: '/Users/alex/work/backend-api',
    active: true,
    presence: 'online',
  ),
  's2': _makeSession(
    id: 's2',
    host: 'mbp-work.local',
    path: '/Users/alex/work/frontend',
    thinking: true,
  ),
  's3': _makeSession(
    id: 's3',
    host: 'ubuntu-server',
    path: '/home/alex/infra/terraform',
  ),
  's4': _makeSession(
    id: 's4',
    host: 'ubuntu-server',
    path: '/home/alex/scripts/deploy',
  ),
  's5': _makeSession(
    id: 's5',
    host: 'macbook-air.local',
    path: '/Users/alex/personal/side-project',
  ),
};

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {});

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  // ── Sessions Screen ─────────────────────────────────────────────────────────

  group('Sessions Screen', () {
    testWidgets('light mode - with sessions', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(
        _buildApp(const SessionsScreen(), sessions: _mockSessions),
      );
      // Pump in increments so Future.delayed stagger timers fire and
      // animations fully settle before capturing the golden screenshot.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sessions_light.png'),
      );
    });

    testWidgets('dark mode - with sessions', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(
        _buildApp(
          const SessionsScreen(),
          sessions: _mockSessions,
          dark: true,
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sessions_dark.png'),
      );
    });
  });

  // ── Settings Screen ─────────────────────────────────────────────────────────

  group('Settings Screen', () {
    testWidgets('light mode', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(_buildApp(const SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_light.png'),
      );
    });

    testWidgets('dark mode', (tester) async {
      setPhoneSize(tester);

      await tester.pumpWidget(_buildApp(const SettingsScreen(), dark: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/settings_dark.png'),
      );
    });
  });

  // ── Tool View ───────────────────────────────────────────────────────────────

  group('Tool View', () {
    Widget _toolApp(Map<String, dynamic> tool, {bool dark = false}) {
      return MaterialApp(
        theme: _testLightTheme(),
        darkTheme: _testDarkTheme(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ToolView(tool: tool, sessionId: 's1'),
            ),
          ),
        ),
      );
    }

    testWidgets('bash completed - light', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 500 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp({
          'name': 'Bash',
          'input': {'command': 'ls -la /home/user/project'},
          'result':
              'total 48\ndrwxr-xr-x  8 user user 4096 Nov 14 .\ndrwxr-xr-x 24 user user 4096 Nov 14 ..\n-rw-r--r--  1 user user  220 Nov 14 .env\ndrwxr-xr-x  2 user user 4096 Nov 14 src\ndrwxr-xr-x  3 user user 4096 Nov 14 lib',
          'state': 'completed',
        }),
      );
      await tester.pump();
      // Tap header to expand (completed tools start collapsed).
      await tester.tap(find.byType(ToolView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_bash_completed_light.png'),
      );
    });

    testWidgets('bash running - light', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 300 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp({
          'name': 'Bash',
          'input': {'command': 'npm run build --production'},
          'state': 'running',
        }),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_bash_running_light.png'),
      );
    });

    testWidgets('bash error - dark', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 400 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp(
          {
            'name': 'Bash',
            'input': {'command': 'npm run build'},
            'result':
                "npm ERR! Missing script: \"build\"\nnpm ERR! \nnpm ERR! Did you mean one of these?\nnpm ERR!   npm run start",
            'state': 'error',
          },
          dark: true,
        ),
      );
      await tester.pump();
      // Tap header to expand (error tools start collapsed).
      await tester.tap(find.byType(ToolView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_bash_error_dark.png'),
      );
    });

    testWidgets('read file - light', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 500 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _toolApp({
          'name': 'Read',
          'input': {'file_path': '/home/user/project/lib/main.dart'},
          'result':
              "import 'package:flutter/material.dart';\n\nvoid main() {\n  runApp(const MyApp());\n}\n\nclass MyApp extends StatelessWidget {\n  const MyApp({super.key});\n\n  @override\n  Widget build(BuildContext context) {\n    return MaterialApp(\n      title: 'Flutter Demo',\n      home: const MyHomePage(),\n    );\n  }\n}",
          'state': 'completed',
        }),
      );
      await tester.pump();
      // Tap header to expand (completed tools start collapsed).
      await tester.tap(find.byType(ToolView));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tool_read_completed_light.png'),
      );
    });
  });
}
