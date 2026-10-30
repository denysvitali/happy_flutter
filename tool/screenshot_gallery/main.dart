// Screenshot gallery: boots Happy's real screens with fixture data and no
// backend, one scene per page load.
//
//   build/web/index.html?scene=sessions-list&theme=dark
//
// Query parameters:
//   scene  — key of [scenes] (default: sessions-list)
//   theme  — dark | light (default: dark)
//   view   — optional sessionsViewStyle override (mission_control, status,
//            machines, folder, repository, unread_focus)
//
// When the scene has painted and settled the entrypoint sets
// `window.__sceneReady = true` (or `window.__sceneError = '<msg>'`), which
// `capture.mjs` waits for before taking the screenshot.
//
// Test-only hooks on `Sync` (`testSessions`, `testSetSessionMessages`, ...)
// are the seams the widget tests use; the gallery reuses them deliberately.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/services/draft_storage.dart';
import 'package:happy_flutter/core/services/storage_service.dart' as storage;
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';
import 'package:happy_flutter/core/theme/app_scroll_behavior.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:happy_flutter/features/sessions/sessions_screen.dart';
import 'package:happy_flutter/features/sessions/widgets/new_session_dialog.dart';

import 'fixtures.dart';
import 'overrides.dart';
import 'roster_scenes.dart';

/// One capturable screen.
class Scene {
  const Scene({
    required this.description,
    required this.build,
    this.noSessions = false,
    this.noMachines = false,
    this.afterFirstFrame,
  });

  final String description;

  /// Root widget rendered at `/`.
  final WidgetBuilder build;

  /// Seed no sessions (empty states).
  final bool noSessions;

  /// Seed no machines either (first-run onboarding).
  final bool noMachines;

  /// Optional interaction run once the scene has painted (open a dialog,
  /// focus a field). Receives the root navigator context.
  final Future<void> Function(BuildContext context)? afterFirstFrame;
}

const _composerDraft =
    'Also make the tray scroll horizontally once it has more than '
    'four images. Keep the send button pinned to the right.';

/// Scene registry. Add a scene here; `capture.mjs` (no --scenes) reads the
/// keys from the `?scene=__list__` page and captures them all.
final Map<String, Scene> scenes = {
  'sessions-list': Scene(
    description: 'Sessions home (Mission Control) with mixed agents/states',
    build: (_) => const SessionsScreen(),
  ),
  'sessions-status': Scene(
    description: 'Sessions home, status-board layout',
    build: (_) => const SessionsScreen(),
  ),
  'empty-sessions': Scene(
    description: 'Sessions home: machines linked, no sessions yet',
    noSessions: true,
    build: (_) => const SessionsScreen(),
  ),
  'onboarding': Scene(
    description: 'Sessions home: first run, no machine linked',
    noSessions: true,
    noMachines: true,
    build: (_) => const SessionsScreen(),
  ),
  'chat-working': Scene(
    description: 'Claude mid-turn: markdown, code block, tool calls',
    build: (_) => const ChatScreen(
      key: ValueKey('chat:$workingSessionId'),
      sessionId: workingSessionId,
    ),
  ),
  'chat-working-grouped': Scene(
    description: 'Claude mid-turn with tool calls collapsed into summaries',
    build: (_) => const ChatScreen(
      key: ValueKey('chat:$workingSessionId'),
      sessionId: workingSessionId,
    ),
  ),
  'chat-permission': Scene(
    description: 'Pending Bash permission request',
    build: (_) => const ChatScreen(
      key: ValueKey('chat:$permissionSessionId'),
      sessionId: permissionSessionId,
    ),
  ),
  'chat-signin': Scene(
    description: 'Claude sign-in prompt, pasted code, signed-in reply',
    build: (_) => const ChatScreen(
      key: ValueKey('chat:$signinSessionId'),
      sessionId: signinSessionId,
    ),
  ),
  'composer': Scene(
    description: 'Chat composer focused with a draft',
    build: (_) => const ChatScreen(
      key: ValueKey('chat:$signinSessionId'),
      sessionId: signinSessionId,
    ),
    afterFirstFrame: (_) async => _focusComposer(_composerDraft),
  ),
  'new-session': Scene(
    description: 'New-session dialog with the laptop selected',
    build: (_) => const SessionsScreen(),
    afterFirstFrame: (context) async {
      unawaited(
        showNewSessionDialog(
          context,
          initialMachineId: laptopMachineId,
          initialPath: '/Users/denys/git/happy_flutter',
          initialAgent: 'claude',
        ),
      );
    },
  ),
  'roster-avatars': Scene(
    description: 'Roster: all six agent shapes, avatars and row state dots',
    build: (_) => const RosterAvatarSheet(),
  ),
  'settings': Scene(
    description: 'Settings home tab',
    build: (_) => const SessionsScreen(initialTab: 'settings'),
  ),
};

/// Puts [text] into the first editable field and focuses it.
void _focusComposer(String text) {
  EditableText? found;
  void visit(Element element) {
    if (found != null) return;
    final widget = element.widget;
    if (widget is EditableText) {
      found = widget;
      return;
    }
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  final field = found;
  if (field == null) return;
  field.controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  field.focusNode.requestFocus();
}

void _setFlag(String name, JSAny value) {
  globalContext.setProperty(name.toJS, value);
}

final _navigatorKey = GlobalKey<NavigatorState>();

void _seedSync(Scene scene) {
  final noop = InvalidateSync(() async {});
  sync
    ..isInitialized = true
    ..testIsReady = true
    ..testEncryptionInitialized = true
    ..testSocketConnectedOverride = true
    ..sessionsSync = noop
    ..settingsSync = noop
    ..profileSync = noop
    ..purchasesSync = noop
    ..machinesSync = noop
    ..pushTokenSync = noop
    ..nativeUpdateSync = noop
    ..artifactsSync = noop
    ..sessionGitStatusSync = noop;
  if (!scene.noMachines) sync.testMachines.addAll(fixtureMachines());
  if (scene.noSessions) return;
  final messages = fixtureMessages();
  for (final session in fixtureSessions().values) {
    sync.testSessions[session.id] = session;
    sync.messagesSync[session.id] = InvalidateSync(() async {});
    sync.testSetSessionMessages(session.id, messages[session.id] ?? []);
    // Online sessions need a fresh keep-alive to count as reachable.
    if (session.isPresenceOnline) {
      sync.testSetLastEphemeralAt(session.id, fixtureNow);
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final params = Uri.base.queryParameters;
  final sceneKey = params['scene'] ?? 'sessions-list';
  final dark = (params['theme'] ?? 'dark') != 'light';

  if (sceneKey == '__list__') {
    _setFlag('__scenes', scenes.keys.join(',').toJS);
    _setFlag('__sceneReady', true.toJS);
    runApp(const SizedBox.shrink());
    return;
  }

  final scene = scenes[sceneKey];
  if (scene == null) {
    _setFlag('__sceneError', 'unknown scene $sceneKey'.toJS);
    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text('Unknown scene: $sceneKey')),
      ),
    );
    return;
  }

  await storage.Storage().initializeEssential();
  await DraftStorage().removeDraft(signinSessionId);
  _seedSync(scene);

  final settings = Settings()
    ..themeMode = dark ? 'dark' : 'light'
    ..sessionsViewStyle =
        params['view'] ??
        (sceneKey == 'sessions-status' ? 'status' : 'mission_control')
    // Conversation lane: the grouped scene shows the collapsed work summary.
    ..hideToolCalls = sceneKey == 'chat-working-grouped';

  final router = GoRouter(
    navigatorKey: _navigatorKey,
    routes: [
      GoRoute(path: '/', builder: (context, _) => scene.build(context)),
      GoRoute(
        path: '/chat/:sessionId',
        name: 'chat',
        builder: (_, state) => ChatScreen(
          key: ValueKey('chat:${state.pathParameters['sessionId']}'),
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
    ],
    errorBuilder: (_, state) =>
        Scaffold(body: Center(child: Text('Not in gallery: ${state.uri}'))),
  );

  runApp(
    ProviderScope(
      overrides: galleryOverrides(
        settings: settings,
        sessions: scene.noSessions ? const {} : fixtureSessions(),
        machines: scene.noMachines ? const {} : fixtureMachines(),
      ),
      child: MaterialApp.router(
        title: 'Happy gallery',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const AppScrollBehavior(),
        theme: ThemeHelper.buildLightTheme(),
        darkTheme: ThemeHelper.buildDarkTheme(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      // Let microtask-driven loads (loadFromSync, draft restore) land.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final context = _navigatorKey.currentContext;
      if (scene.afterFirstFrame case final action? when context != null) {
        if (!context.mounted) return;
        await action(context);
      }
      // Allow dialog/route transitions and entrance animations to settle.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await WidgetsBinding.instance.endOfFrame;
      _setFlag('__sceneReady', true.toJS);
    } catch (error) {
      _setFlag('__sceneError', '$error'.toJS);
    }
  });
}
