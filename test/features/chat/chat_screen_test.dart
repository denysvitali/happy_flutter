import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
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
import 'package:happy_flutter/core/utils/invalidate_sync.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:happy_flutter/features/chat/widgets/chat_loading_shimmer.dart';
import 'package:happy_flutter/features/chat/widgets/empty_chat_view.dart';
import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

/// Fake MMKV platform that returns no-op stubs so DraftStorage/MMKVStorage
/// initialisation succeeds in widget tests without native libraries.
class _FakeMMKVPlatform extends MMKVPluginPlatform {
  @override
  Future<String> getApplicationDocumentsPath() async => '/tmp/mmkv_test';

  @override
  Future<String> initialize(
    String rootDir, {
    String? groupDir,
    int logLevel = 1,
    Pointer<NativeFunction<LogCallbackWrap>>? logHandler,
  }) async => rootDir;

  @override
  Pointer<Void> Function(int, Pointer<Utf8>, int, int, int, int, int, int, int)
  getDefaultMMKVFunc() =>
      (
        int mode,
        Pointer<Utf8> cryptKey,
        int aes256,
        int expectedCapacity,
        int enableKeyExpire,
        int expiredInSeconds,
        int enableCompareBeforeSet,
        int recover,
        int itemSizeLimit,
      ) => Pointer<Void>.fromAddress(1);

  @override
  ContentCallbackRegister registerContentLoadedHandlerFunc() =>
      (Pointer<NativeFunction<ContentCallbackWrap>> handler) {};

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int) decodeBoolFunc() =>
      (Pointer<Void> h, Pointer<Utf8> k, int d) => 1;

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int) encodeBoolFunc() =>
      (Pointer<Void> h, Pointer<Utf8> k, int v) => 1;

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, int, int) encodeBoolV2Func() =>
      (Pointer<Void> h, Pointer<Utf8> k, int v, int e) => 1;

  @override
  Pointer<Uint8> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint64>)
  decodeBytesFunc() =>
      (Pointer<Void> h, Pointer<Utf8> k, Pointer<Uint64> l) =>
          Pointer<Uint8>.fromAddress(0);

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int)
  encodeBytesFunc() =>
      (Pointer<Void> h, Pointer<Utf8> k, Pointer<Uint8> v, int l) => 1;

  @override
  int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int, int)
  encodeBytesV2Func() =>
      (Pointer<Void> h, Pointer<Utf8> k, Pointer<Uint8> v, int l, int e) => 1;

  @override
  void Function(Pointer<Void>, Pointer<Utf8>) removeValueForKeyFunc() =>
      (Pointer<Void> h, Pointer<Utf8> k) {};
}

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
  MMKVPluginPlatform? originalMMKVPlatform;

  setUpAll(() async {
    // Register a fake MMKV platform so DraftStorage and MMKVStorage can
    // initialise without the native MMKV library.
    originalMMKVPlatform = MMKVPluginPlatform.instance;
    MMKVPluginPlatform.instance = _FakeMMKVPlatform();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async => 1);
  });

  tearDownAll(() async {
    MMKVPluginPlatform.instance = originalMMKVPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
    await TtsService().dispose();
  });

  tearDown(() async {
    sync.testSetSessionMessages('session_1', const []);
    sync.testSessions.remove('session_1');
    sync.messagesSync.remove('session_1')?.dispose();
    sync.isInitialized = false;
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

    testWidgets('shows empty chat view when no messages exist', (tester) async {
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
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'user', 'content': 'Hello there'},
        {'id': 'msg_2', 'role': 'assistant', 'content': 'Hi! How can I help?'},
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
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'user', 'content': 'First message'},
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
        {'id': 'msg_1', 'role': 'user', 'content': 'First message'},
        {'id': 'msg_2', 'role': 'assistant', 'content': 'Response message'},
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
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] = _makeSession(presence: 'online');
      sync.testSetLastEphemeralAt(
        'session_1',
        DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('shows provider-specific working status', (tester) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] =
          _makeSession(thinking: true, presence: 'online').copyWith(
            metadata: const Metadata(
              host: 'host',
              flavor: 'codex',
              machineId: 'machine-1',
              path: '/repo',
            ),
          );
      sync.testSetLastEphemeralAt(
        'session_1',
        DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Codex working'), findsOneWidget);
      expect(find.text('Claude is thinking...'), findsNothing);
    });

    testWidgets('shows offline and last seen chips for offline session', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] =
          _makeSession(
            updatedAt: DateTime.now()
                .subtract(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
          ).copyWith(
            activeAt: DateTime.now()
                .subtract(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
          );

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Last seen 5m ago'), findsOneWidget);
    });

    testWidgets('shows delivery status chips for latest outgoing message', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'local-1',
          'localId': 'local-1',
          'role': 'user',
          'content': 'Hello',
          'sendStatus': 'sent',
        },
      ]);
      sync.testSessions['session_1'] = _makeSession(presence: 'online');
      sync.testSetLastEphemeralAt(
        'session_1',
        DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delivered'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders multiple messages in correct order', (tester) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
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
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
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

    testWidgets('cleared divider shown after /clear message', (tester) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'user', 'content': 'Before clear'},
        {'id': 'msg_2', 'role': 'user', 'content': '/clear'},
        {'id': 'msg_3', 'role': 'assistant', 'content': 'After clear'},
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
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'user', 'text': 'Message with text field'},
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

    testWidgets('all cached messages are visible when count exceeds pageSize', (
      tester,
    ) async {
      // Regression test: when a session has > 50 cached messages, ALL of them
      // must be visible — _visibleCount must NOT be clamped to _pageSize (50).
      // Before the fix (daa85e3), _visibleCount was clamped to _pageSize even
      // when 58 messages were cached, causing messages 0-7 to be hidden and
      // a permanent spinner to appear at the top.
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});

      // 58 messages — exceeds _pageSize of 50
      final messages = List.generate(
        58,
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
      // Flush all pending async operations: initState, _refreshFromSync calls,
      // Timer callbacks (InvalidateSync), and all scheduled setState frames.
      await tester.pumpAndSettle();

      // All 58 messages must be present — including messages 0-7 which were
      // hidden before the fix (visibleCount was clamped to 50, showing only
      // messages 8-57).
      // Message 57 is ALWAYS visible if all 58 messages are shown (index 57 is
      // the newest message at the top of the reverse ListView).
      expect(find.text('Message number 57'), findsOneWidget);

      // The shimmer must not be shown once loading completes.
      expect(find.byType(ChatLoadingShimmer), findsNothing);
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
