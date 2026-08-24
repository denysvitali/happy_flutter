// Pins that the 'chat' route always renders the session named in the URL.
//
// go_router derives `state.pageKey` from the *route pattern*
// (`/chat/:sessionId`), not from the resolved location, so `go('/chat/B')`
// while `/chat/A` is the current location produces a page with the same key.
// The Navigator then keeps A's route and swaps the page child in place; a
// keyless `ChatScreen` would keep A's `State` (messages, visibility, sync
// subscriptions) while `widget.sessionId` reads B — the user "opens" B but
// sees and acts on A. Every imperative `goNamed('chat')` caller (command
// palette, notification tap, send redirect, new-session dialog) hits this.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/routing/app_router.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';

class _StubAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated;
}

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings();

  @override
  Future<void> updateSetting<T>(String key, T value) async {
    final json = state.toJson();
    json[key] = value;
    state = Settings.fromJson(json);
  }
}

Session _makeSession(String id) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Session(
    id: id,
    seq: 1,
    createdAt: now - 10000,
    updatedAt: now - 5000,
    active: true,
    activeAt: now - 5000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'offline',
  );
}

void _seedSession(String id, String text) {
  sync.messagesSync[id] = InvalidateSync(() async {});
  sync.testSetSessionMessages(id, [
    {'id': 'msg_$id', 'role': 'user', 'content': text},
  ]);
  sync.testSessions[id] = _makeSession(id);
}

Widget _app(GoRouter router) {
  return ProviderScope(
    overrides: [
      authStateNotifierProvider.overrideWith(_StubAuthNotifier.new),
      settingsNotifierProvider.overrideWith(_StorageFreeSettingsNotifier.new),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

String _visibleChatSessionId(WidgetTester tester) {
  return tester.widget<ChatScreen>(find.byType(ChatScreen)).sessionId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ttsChannel = MethodChannel('flutter_tts');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async => 1);
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    await TtsService().dispose();
  });

  setUp(() {
    sync.isInitialized = true;
    _seedSession('session_a', 'Hello from A');
    _seedSession('session_b', 'Hello from B');
  });

  tearDown(() async {
    for (final id in ['session_a', 'session_b']) {
      sync.testClearSessionMessageState(id);
      sync.testSessions.remove(id);
      sync.messagesSync.remove(id);
    }
    sync.isInitialized = false;
    await TtsService().dispose();
  });

  group('chat route session identity', () {
    testWidgets('go(/chat/B) over /chat/A renders B, not A\'s stale state', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/chat/session_a',
        routes: shellRoutes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await _settle(tester);

      expect(_visibleChatSessionId(tester), 'session_a');
      expect(find.text('Hello from A'), findsOneWidget);

      router.go('/chat/session_b');
      await _settle(tester);

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(_visibleChatSessionId(tester), 'session_b');
      expect(find.text('Hello from B'), findsOneWidget);
      expect(find.text('Hello from A'), findsNothing);
    });

    testWidgets('push(/chat/B) over /chat/A shows B; pop returns to A', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/chat/session_a',
        routes: shellRoutes,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router));
      await _settle(tester);

      unawaited(router.push('/chat/session_b'));
      await _settle(tester);

      expect(_visibleChatSessionId(tester), 'session_b');
      expect(find.text('Hello from B'), findsOneWidget);

      router.pop();
      await _settle(tester);

      expect(_visibleChatSessionId(tester), 'session_a');
      expect(find.text('Hello from A'), findsOneWidget);
      expect(find.text('Hello from B'), findsNothing);
    });
  });
}
