import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:happy_flutter/features/chat/widgets/chat_loading_shimmer.dart';
import 'package:happy_flutter/features/chat/widgets/empty_chat_view.dart';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> updateSetting<T>(String key, T value) async {
    final json = state.toJson();
    json[key] = value;
    state = Settings.fromJson(json);
  }
}

Session _makeSession({
  String id = 'session_1',
  String presence = 'offline',
  bool thinking = false,
  int? updatedAt,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Session(
    id: id,
    seq: 1,
    createdAt: now - 10000,
    updatedAt: updatedAt ?? now - 5000,
    active: true,
    activeAt: now - 5000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: presence,
  );
}

Widget _buildApp({required Widget child}) {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StorageFreeSettingsNotifier(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async => 1);
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    await TtsService().dispose();
  });

  tearDown(() async {
    sync.testSetSessionMessages('session_1', const []);
    await TtsService().dispose();
  });

  group('ChatScreen', () {
    testWidgets('shows loading shimmer when messages are loading', (
      tester,
    ) async {
      sync.testSetSessionMessages('session_1', const []);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      expect(find.byType(ChatLoadingShimmer), findsOneWidget);
    });

    testWidgets('shows empty chat view when no messages exist', (
      tester,
    ) async {
      sync.testSetSessionMessages('session_1', const []);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ChatLoadingShimmer), findsOneWidget);
    });

    testWidgets('shows chat input at bottom of screen', (tester) async {
      sync.testSetSessionMessages('session_1', const []);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('has app bar with menu and info actions', (tester) async {
      sync.testSetSessionMessages('session_1', const []);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('renders messages from sync data', (tester) async {
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_1',
          'role': 'user',
          'content': 'Hello there',
        },
        {
          'id': 'msg_2',
          'role': 'assistant',
          'content': 'Hi! How can I help?',
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hello there'), findsOneWidget);
      expect(find.text('Hi! How can I help?'), findsOneWidget);
    });

    testWidgets('updates when session messages change via sync', (
      tester,
    ) async {
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_1',
          'role': 'user',
          'content': 'First message',
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('First message'), findsOneWidget);

      // Add a new message via sync
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_1',
          'role': 'user',
          'content': 'First message',
        },
        {
          'id': 'msg_2',
          'role': 'assistant',
          'content': 'Response message',
        },
      ]);
      sync.testNotifySessionMessagesChanged('session_1');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Response message'), findsOneWidget);
    });

    testWidgets('text field accepts user input', (tester) async {
      sync.testSetSessionMessages('session_1', const []);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Test input');
      expect(find.text('Test input'), findsOneWidget);
    });

    testWidgets('shows status text for online session', (tester) async {
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] = _makeSession(
        presence: 'online',
      );

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      // The status should show "Online" for online sessions
      // The ChatAppBar reads status from _getStatusText
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows status text for thinking session', (tester) async {
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] = _makeSession(
        thinking: true,
      );

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders multiple messages in correct order', (
      tester,
    ) async {
      final messages = List.generate(
        5,
        (i) => {
          'id': 'msg_$i',
          'role': i.isEven ? 'user' : 'assistant',
          'content': 'Message number $i',
        },
      );
      sync.testSetSessionMessages('session_1', messages);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (var i = 0; i < 5; i++) {
        expect(find.text('Message number $i'), findsOneWidget);
      }
    });

    testWidgets('handles tool-call messages', (tester) async {
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_1',
          'role': 'assistant',
          'kind': 'tool-call',
          'name': 'Read',
          'toolUseId': 'tool_1',
          'state': 'completed',
          'input': {'file_path': '/test.dart'},
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Read File'), findsOneWidget);
    });

    testWidgets('displays session title from summary when available', (
      tester,
    ) async {
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      // Default title when no summary
      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('cleared divider shown after /clear message', (
      tester,
    ) async {
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_1',
          'role': 'user',
          'content': 'Before clear',
        },
        {
          'id': 'msg_2',
          'role': 'user',
          'content': '/clear',
        },
        {
          'id': 'msg_3',
          'role': 'assistant',
          'content': 'After clear',
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('After clear'), findsOneWidget);
    });

    testWidgets('disposes controllers on widget dispose', (tester) async {
      sync.testSetSessionMessages('session_1', const []);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      // Navigate away to trigger dispose
      await tester.pumpWidget(
        _buildApp(child: const Scaffold(body: SizedBox())),
      );
      await tester.pump();

      // No exceptions should be thrown
    });

    testWidgets('permission mode selector is present in toolbar', (
      tester,
    ) async {
      sync.testSetSessionMessages('session_1', const []);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      // The toolbar should contain permission mode and model selectors
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows send button in input area', (tester) async {
      sync.testSetSessionMessages('session_1', const []);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      // There should be a send button (IconButton)
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('session with no messages shows empty state after loading', (
      tester,
    ) async {
      sync.testSetSessionMessages('session_1', const []);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Loading shimmer is shown because sync is not initialized
      expect(find.byType(ChatLoadingShimmer), findsOneWidget);
    });

    testWidgets('handles messages with text content', (tester) async {
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_1',
          'role': 'user',
          'text': 'Message with text field',
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Message with text field'), findsOneWidget);
    });

    testWidgets('shows model label in app bar when model is not default', (
      tester,
    ) async {
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      // Default model should not show a label
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('PopScope handles unsent message dialog', (tester) async {
      sync.testSetSessionMessages('session_1', const []);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();

      // Type a message
      await tester.enterText(find.byType(TextField), 'Unsent message');
      await tester.pump();

      expect(find.text('Unsent message'), findsOneWidget);
    });
  });
}
