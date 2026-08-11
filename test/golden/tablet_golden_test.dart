// ignore_for_file: depend_on_referenced_packages
//
// Tablet golden screenshots — separate from `golden_test.dart` (phone-only)
// to keep viewport setup, mock fixtures, and PNGs visually grouped.
//
// Phone goldens use 390 x 844 @ 2x (iPhone-class). This file targets:
//   * iPad portrait — 768 x 1024 @ 2x
//   * iPad landscape — 1024 x 768 @ 2x
//
// `SessionsScreen` already exposes a master-detail layout above the
// `AppBreakpoint.tablet` (>=600px) breakpoint, so the two seeded baseline
// tests below exercise that real UI. The remaining `skip: true` stubs are
// placeholders that Phase-2 agents will fill in for chat, artifacts, zen,
// inbox, profiles, sftp, and session pickers.

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/models/machine.dart' show GitStatus, Machine;
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:happy_flutter/features/sessions/sessions_screen.dart';

import '../helpers/golden_chat_screen_fixture.dart';

// ─── Stub Notifiers (mirror those in golden_test.dart) ───────────────────────

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
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}
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
  Map<String, GitStatus> build() => {};
}

// ─── Test themes (real app themes — fonts loaded via flutter_test_config) ────

ThemeData _testLightTheme() => ThemeHelper.buildLightTheme();

ThemeData _testDarkTheme() => ThemeHelper.buildDarkTheme();

// ─── Helpers ─────────────────────────────────────────────────────────────────

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
  authStateNotifierProvider.overrideWith(
    () => _StubAuthNotifier(AuthState.authenticated),
  ),
  settingsNotifierProvider.overrideWith(() => _StubSettingsNotifier()),
  sessionsNotifierProvider.overrideWith(() => _StubSessionsNotifier(sessions)),
  machinesNotifierProvider.overrideWith(() => _StubMachinesNotifier()),
  connectionNotifierProvider.overrideWith(() => _StubConnectionNotifier()),
  networkNotifierProvider.overrideWith(() => _StubNetworkNotifier()),
  profileNotifierProvider.overrideWith(() => _StubProfileNotifier()),
  currentSessionNotifierProvider.overrideWith(
    () => _StubCurrentSessionNotifier(),
  ),
  sessionGitStatusNotifierProvider.overrideWith(
    () => _StubSessionGitStatusNotifier(),
  ),
];

Widget _buildApp(
  Widget child, {
  bool dark = false,
  Map<String, Session> sessions = const {},
}) {
  return ProviderScope(
    overrides: _commonOverrides(sessions),
    child: TickerMode(
      enabled: false,
      child: MaterialApp(
        theme: _testLightTheme(),
        darkTheme: _testDarkTheme(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    ),
  );
}

// ─── Mock data ───────────────────────────────────────────────────────────────

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

// ─── Viewport helpers ────────────────────────────────────────────────────────

/// iPad portrait — 768 logical px wide, 1024 tall, @ 2x.
void _setTabletPortraitSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(768 * 2, 1024 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

/// iPad landscape — 1024 logical px wide, 768 tall, @ 2x.
void _setTabletLandscapeSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1024 * 2, 768 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (call) async => null);
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  // ── Sessions Screen — tablet master-detail layout ─────────────────────────
  //
  // Skipped until baselines are generated locally with
  // `flutter test test/golden/tablet_golden_test.dart --update-goldens`.
  // The CI golden job runs all tests under `test/golden/`, so leaving these
  // unskipped without baselines would fail the pipeline.

  group('Sessions Screen (tablet)', () {
    testWidgets('landscape light - master-detail with sessions', (
      tester,
    ) async {
      _setTabletLandscapeSize(tester);

      await tester.pumpWidget(
        _buildApp(const SessionsScreen(), sessions: _mockSessions),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tablet_sessions_landscape_light.png'),
      );
    });

    testWidgets('portrait light - master-detail still rendered at 768', (
      tester,
    ) async {
      _setTabletPortraitSize(tester);

      await tester.pumpWidget(
        _buildApp(const SessionsScreen(), sessions: _mockSessions),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tablet_sessions_portrait_light.png'),
      );
    });
  });

  // ── Stubs — to be filled in by Phase-2 agents ─────────────────────────────
  //
  // Each stub is `skip: true` so the file passes today. The owning agent
  // should remove the skip flag and replace the empty body with a real test
  // that produces `goldens/<name>.png` via `--update-goldens`.

  group('Tablet stubs (Phase 2)', () {
    testWidgets('tablet_chat_landscape_light', (tester) async {
      _setTabletLandscapeSize(tester);
      seedGoldenChatScreen();
      addTearDown(clearGoldenChatScreen);

      await tester.pumpWidget(
        _buildApp(
          const ChatScreen(sessionId: goldenChatSessionId),
          sessions: {goldenChatSessionId: goldenChatSession()},
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tablet_chat_landscape_light.png'),
      );
    });

    testWidgets('tablet_artifacts_landscape_light', (tester) async {
      // TODO: filled in by artifacts agent (F4).
    }, skip: true);

    testWidgets('tablet_zen_landscape_light', (tester) async {
      // TODO: filled in by zen agent (F5).
    }, skip: true);

    testWidgets('tablet_inbox_landscape_light', (tester) async {
      // TODO: filled in by inbox agent (F6).
    }, skip: true);

    testWidgets('tablet_profiles_landscape_light', (tester) async {
      // TODO: filled in by profiles agent (F7).
    }, skip: true);

    testWidgets('tablet_sftp_landscape_light', (tester) async {
      // TODO: filled in by sftp agent (F8).
    }, skip: true);

    testWidgets('tablet_session_pickers_landscape_light', (tester) async {
      // TODO: filled in by session pickers agent (F9).
    }, skip: true);
  });
}
