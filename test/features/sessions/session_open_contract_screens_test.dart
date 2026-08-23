// Contract: every non-list entry point that opens a chat opens the session
// whose label was tapped (or whose id was delivered).
//
// Companion to `session_open_contract_test.dart` (list/folder/Mission
// Control) and `session_open_contract_guards_test.dart` (debounce, archive
// rebuild, selection mode). Covered here:
//
// * tablet master-detail — `SessionsScreen` ≥ `AppBreakpoint.masterDetail`
//   selects the tapped id and mounts a `ChatScreen` keyed by that id;
// * command palette — the session item for the tapped label `go`es to
//   `/chat/<id>`, both for visible and search-only (older) sessions;
// * notification tap — `NotificationService` routes the payload's
//   `sessionId` through the injected `GoRouter` (`goNamed('chat')`);
// * artifact detail — the "source session" row pushes the chat for its id.
import 'dart:convert';

import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/models/artifact.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/models/machine.dart' show GitStatus;
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/models/provider_usage.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/notification_service.dart';
import 'package:happy_flutter/core/services/performance_context_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/features/artifacts/artifact_detail_screen.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:happy_flutter/features/command_palette/command_palette.dart';
import 'package:happy_flutter/features/command_palette/command_palette_overlay.dart';
import 'package:happy_flutter/features/sessions/sessions_screen.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_list_content.dart';

import '../../helpers/session_open_harness.dart';

// ─── SessionsScreen (tablet) stubs ───────────────────────────────────────────

class _StubAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated;
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

class _StubArtifactsNotifier extends ArtifactsNotifier {
  _StubArtifactsNotifier(this._artifact);

  final DecryptedArtifact _artifact;

  @override
  Map<String, DecryptedArtifact> build() => {_artifact.id: _artifact};
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync() async {}
}

List<Override> _screenOverrides() => [
  ...contractListOverrides(
    settings: () => Settings()..sessionsViewStyle = 'list',
  ),
  authStateNotifierProvider.overrideWith(_StubAuthNotifier.new),
  connectionNotifierProvider.overrideWith(_StubConnectionNotifier.new),
  networkNotifierProvider.overrideWith(_StubNetworkNotifier.new),
  profileNotifierProvider.overrideWith(_StubProfileNotifier.new),
  currentSessionNotifierProvider.overrideWith(_StubCurrentSessionNotifier.new),
  sessionGitStatusNotifierProvider.overrideWith(
    _StubSessionGitStatusNotifier.new,
  ),
  loopsNotifierProvider.overrideWith(_StubLoopsNotifier.new),
  providerUsageNotifierProvider.overrideWith(_StubProviderUsageNotifier.new),
];

/// Bounded pumps; never `pumpAndSettle` (chat + sessions own tickers).
Future<void> _settle(WidgetTester tester, {int frames = 8}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Session items sit under the last palette category; scroll the lazy
/// results list until the tapped row is built.
Future<void> _scrollPaletteTo(WidgetTester tester, Finder item) async {
  await tester.scrollUntilVisible(
    item,
    120,
    scrollable: find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pump();
}

void _setViewport(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  const ttsChannel = MethodChannel('flutter_tts');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(recordChannel, (call) async => null)
      ..setMockMethodCallHandler(ttsChannel, (call) async => 1);
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(recordChannel, null)
      ..setMockMethodCallHandler(ttsChannel, null);
    await TtsService().dispose();
  });

  group('tablet master-detail', () {
    Future<ProviderContainer> pumpTablet(WidgetTester tester) async {
      // 1280 ≥ AppBreakpoint.masterDetail (736): split view with a detail
      // ChatScreen instead of a pushed route. (Wide enough that the
      // ~0.38-fraction master pane lays cards out without overflow.)
      expect(1280, greaterThanOrEqualTo(AppBreakpoint.masterDetail));
      _setViewport(tester, const Size(1280, 1400));
      final performanceContext = PerformanceContextService()
        ..setCurrentRoute('sessions');
      addTearDown(performanceContext.resetForTesting);
      final container = ProviderContainer(overrides: _screenOverrides());
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const SessionsScreen())],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        buildSessionOpenApp(container: container, router: router),
      );
      await _settle(tester);
      return container;
    }

    ChatScreen detailChat(WidgetTester tester) =>
        tester.widget<ChatScreen>(find.byType(ChatScreen));

    testWidgets('master list taps route through onSessionTap, not a push', (
      tester,
    ) async {
      await pumpTablet(tester);
      final list = tester.widget<SessionsListContent>(
        find.byType(SessionsListContent),
      );
      expect(list.onSessionTap, isNotNull);
    });

    for (final entry in const {
      contractCharlieId: contractCharlieLabel,
      contractBravoId: contractBravoLabel,
      contractDeltaId: contractDeltaLabel,
    }.entries) {
      testWidgets('tapping "${entry.value}" mounts ChatScreen(${entry.key})', (
        tester,
      ) async {
        await pumpTablet(tester);
        addTearDown(() => cancelContractChatSwitchMetrics());
        // Auto-selection already mounted a detail chat for the most
        // recently active session; the tap must replace it by id.
        final finder = find.text(entry.value);
        expect(finder, findsOneWidget);
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await _settle(tester);

        final chat = detailChat(tester);
        // Known failure for the archived Delta row: the tap frame mounts
        // ChatScreen(Delta), but `_ensureTabletSelection` only accepts
        // non-archived candidates and snaps the detail back to the newest
        // active session on the next frame (sessions_screen.dart
        // `_ensureTabletSelection` + `TabletSessionSelectionProjection`).
        expect(chat.sessionId, entry.key);
        expect(chat.key, ValueKey<String>(entry.key));
        expect(find.byType(ChatScreen), findsOneWidget);
      });
    }

    testWidgets('tapping a second session swaps the detail by id', (
      tester,
    ) async {
      await pumpTablet(tester);
      addTearDown(() => cancelContractChatSwitchMetrics());
      await tester.tap(find.text(contractCharlieLabel));
      await _settle(tester);
      expect(detailChat(tester).sessionId, contractCharlieId);

      await tester.tap(find.text(contractBravoLabel));
      await _settle(tester);
      expect(detailChat(tester).sessionId, contractBravoId);
      expect(detailChat(tester).key, const ValueKey<String>(contractBravoId));
    });
  });

  group('command palette', () {
    Future<SessionOpenRecorder> pumpPalette(
      WidgetTester tester, {
      required ProviderContainer container,
    }) async {
      _setViewport(tester, const Size(480, 1400));
      final recorder = SessionOpenRecorder();
      late GoRouter router;
      router = buildSessionOpenRouter(
        recorder: recorder,
        home: (context) {
          final commands = container
              .read(commandPaletteControllerProvider)
              .buildCommands(context, appRouter: router);
          return Scaffold(
            body: CommandPaletteOverlay(commands: commands, onClose: () {}),
          );
        },
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        buildSessionOpenApp(container: container, router: router),
      );
      await _settle(tester);
      return recorder;
    }

    for (final entry in const {
      contractAlphaId: contractAlphaLabel,
      contractCharlieId: contractCharlieLabel,
      contractDeltaId: contractDeltaLabel,
    }.entries) {
      testWidgets('session item "${entry.value}" goes to /chat/${entry.key}', (
        tester,
      ) async {
        final container = ProviderContainer(
          overrides: contractListOverrides(settings: Settings.new),
        );
        addTearDown(container.dispose);
        final recorder = await pumpPalette(tester, container: container);
        final item = find.text(entry.value);
        await _scrollPaletteTo(tester, item);
        expect(item, findsOneWidget);
        await tester.tap(item);
        await _settle(tester);
        expect(recorder.opened, [entry.key]);
        expect(find.text('chat:${entry.key}'), findsOneWidget);
      });
    }

    testWidgets('search-only (older) session item goes to its own id', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: contractListOverrides(settings: Settings.new),
      );
      addTearDown(container.dispose);
      final recorder = await pumpPalette(tester, container: container);
      // Only the five most recent sessions are listed without a query;
      // Echo (ten days old) is search-only.
      expect(find.text(contractEchoLabel), findsNothing);
      await tester.enterText(find.byType(TextField), 'Echo');
      // Fuzzy filter is debounced 100 ms.
      await _settle(tester, frames: 3);
      final item = find.text(contractEchoLabel);
      await _scrollPaletteTo(tester, item);
      expect(item, findsOneWidget);
      await tester.tap(item);
      await _settle(tester);
      expect(recorder.opened, [contractEchoId]);
    });
  });

  group('notification tap', () {
    Future<SessionOpenRecorder> pumpRouter(WidgetTester tester) async {
      final recorder = SessionOpenRecorder();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = buildSessionOpenRouter(
        recorder: recorder,
        home: (_) => const Scaffold(body: Text('home')),
      );
      addTearDown(router.dispose);
      NotificationService.instance.updateRouter(router);
      await tester.pumpWidget(
        buildSessionOpenApp(container: container, router: router),
      );
      await tester.pump();
      return recorder;
    }

    NotificationResponse bodyTap(Map<String, Object?> payload) =>
        NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: jsonEncode(payload),
        );

    for (final id in const [contractBravoId, contractEchoId]) {
      testWidgets('plain payload for $id opens $id', (tester) async {
        final recorder = await pumpRouter(tester);
        NotificationService.instance.debugHandleNotificationResponse(
          bodyTap({'sessionId': id, 'type': 'activity'}),
        );
        await _settle(tester, frames: 5);
        expect(recorder.opened, [id]);
        expect(find.text('chat:$id'), findsOneWidget);
      });
    }

    testWidgets('permission body tap opens the payload session', (
      tester,
    ) async {
      final recorder = await pumpRouter(tester);
      NotificationService.instance.debugHandleNotificationResponse(
        bodyTap({
          'type': 'permission',
          'sessionId': contractDeltaId,
          'permissionId': 'perm-9',
        }),
      );
      await _settle(tester, frames: 5);
      expect(recorder.opened, [contractDeltaId]);
    });

    testWidgets('stuck body tap opens the payload session', (tester) async {
      final recorder = await pumpRouter(tester);
      NotificationService.instance.debugHandleNotificationResponse(
        bodyTap({'type': 'stuck', 'sessionId': contractAlphaId}),
      );
      await _settle(tester, frames: 5);
      expect(recorder.opened, [contractAlphaId]);
    });

    testWidgets('payload without a sessionId opens nothing', (tester) async {
      final recorder = await pumpRouter(tester);
      NotificationService.instance.debugHandleNotificationResponse(
        bodyTap({'type': 'activity'}),
      );
      await _settle(tester, frames: 5);
      expect(recorder.opened, isEmpty);
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('artifact detail', () {
    const artifactId = 'artifact-1';

    Future<SessionOpenRecorder> pumpArtifact(
      WidgetTester tester, {
      required List<String> sessionIds,
    }) async {
      _setViewport(tester, const Size(480, 1400));
      final now = DateTime.now().millisecondsSinceEpoch;
      final artifact = DecryptedArtifact(
        id: artifactId,
        headerVersion: 1,
        seq: 1,
        createdAt: now - 60000,
        updatedAt: now,
        title: 'Review notes',
        body: 'body',
        sessions: sessionIds,
      );
      final recorder = SessionOpenRecorder();
      final container = ProviderContainer(
        overrides: [
          ...contractListOverrides(settings: Settings.new),
          artifactsNotifierProvider.overrideWith(
            () => _StubArtifactsNotifier(artifact),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = buildSessionOpenRouter(
        recorder: recorder,
        home: (_) => const ArtifactDetailScreen(artifactId: artifactId),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        buildSessionOpenApp(container: container, router: router),
      );
      await _settle(tester);
      return recorder;
    }

    for (final entry in const {
      contractAlphaId: contractAlphaLabel,
      contractEchoId: contractEchoLabel,
    }.entries) {
      testWidgets('source session row "${entry.value}" opens ${entry.key}', (
        tester,
      ) async {
        final recorder = await pumpArtifact(
          tester,
          sessionIds: const [
            contractAlphaId,
            contractBravoId,
            contractCharlieId,
            contractDeltaId,
            contractEchoId,
          ],
        );
        final row = find.text(entry.value);
        expect(row, findsOneWidget);
        await tester.ensureVisible(row);
        await tester.tap(row);
        await _settle(tester);
        expect(recorder.opened, [entry.key]);
        expect(find.text('chat:${entry.key}'), findsOneWidget);
      });
    }
  });
}
