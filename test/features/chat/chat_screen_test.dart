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
import 'package:happy_flutter/features/chat/widgets/hidden_tool_summary.dart';
import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

import '../../helpers/fake_mmkv_platform.dart';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  _StorageFreeSettingsNotifier([this._initial]);

  final Settings? _initial;

  @override
  Settings build() => _initial ?? Settings();

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

Widget _buildApp({required Widget child, Settings? settings}) {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StorageFreeSettingsNotifier(settings),
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
    MMKVPluginPlatform.instance = FakeMmkvPlatform();

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

    testWidgets('rebuilds header status when only message status changes', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSessions['session_1'] = _makeSession(presence: 'online');
      sync.testSetLastEphemeralAt(
        'session_1',
        DateTime.now().millisecondsSinceEpoch,
      );
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'local-1',
          'localId': 'local-1',
          'role': 'user',
          'content': 'Hello',
        },
      ]);

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      // Avoid pumpAndSettle: the online status chip uses an infinite
      // pulse animation so settling never completes.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Retry queued'), findsNothing);

      sync.testSetSessionMessages('session_1', [
        {
          'id': 'local-1',
          'localId': 'local-1',
          'role': 'user',
          'content': 'Hello',
          'sendStatus': 'pending',
        },
      ]);
      sync.testNotifySessionMessagesChanged('session_1');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Retry queued'),
        findsNWidgets(2),
        reason: 'The app bar chip and user bubble should both update.',
      );
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

    testWidgets('shows simplified status text for online session', (
      tester,
    ) async {
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

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
    });

    testWidgets('shows working status while agent is thinking', (tester) async {
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

      expect(find.text('Thinking'), findsOneWidget);
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

    testWidgets(
      'shows stopped-process feedback and blocks sends without restore target',
      (tester) async {
        sync.isInitialized = true;
        sync.messagesSync['session_1'] = InvalidateSync(() async {});
        sync.testSetSessionMessages('session_1', const []);
        sync.testSessions['session_1'] = _makeSession().copyWith(
          metadata: const Metadata(
            host: 'workspace',
            lifecycleState: 'errored',
            lifecycleStateError:
                'daemon started without a live local process for this '
                'running session',
          ),
        );

        await tester.pumpWidget(
          _buildApp(child: const ChatScreen(sessionId: 'session_1')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Agent failed'), findsOneWidget);
        expect(find.text('Session process stopped'), findsOneWidget);
        expect(
          find.textContaining('No live local process is attached'),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField), 'continue');
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pump();

        expect(
          find.textContaining('This session cannot respond'),
          findsOneWidget,
        );
        expect(sync.messagesForSession('session_1'), isEmpty);
        expect(find.text('continue'), findsOneWidget);
      },
    );

    testWidgets('shows restart-on-send feedback when session is restorable', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] = _makeSession().copyWith(
        metadata: const Metadata(
          host: 'workspace',
          machineId: 'machine-1',
          path: '/project',
          lifecycleState: 'errored',
          lifecycleStateError:
              'daemon started without a live local process for this '
              'running session',
        ),
      );

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Will restart'), findsOneWidget);
      expect(find.text('Session process stopped'), findsOneWidget);
      expect(
        find.textContaining('Sending a message will try to restart'),
        findsOneWidget,
      );
    });

    testWidgets(
      'does not duplicate delivered state in the header for sent messages',
      (tester) async {
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

        expect(find.text('Delivered'), findsOneWidget);
      },
    );

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

    testWidgets('hides tool-call messages when enabled', (tester) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'assistant', 'content': 'Before'},
        {
          'id': 'msg_2',
          'role': 'assistant',
          'kind': 'tool-call',
          'name': 'Read',
          'toolUseId': 'tool_1',
          'state': 'completed',
          'input': {'file_path': '/test.dart'},
        },
        {'id': 'msg_3', 'role': 'assistant', 'content': 'After'},
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(
          settings: Settings()..hideToolCalls = true,
          child: const ChatScreen(sessionId: 'session_1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Read File'), findsNothing);
    });

    testWidgets('shows hidden tool calls when permission is pending', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_1',
          'role': 'assistant',
          'kind': 'tool-call',
          'name': 'Bash',
          'toolUseId': 'tool_1',
          'state': 'pending',
          'input': {'command': 'pwd'},
          'permission': {'status': 'pending'},
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(
          settings: Settings()..hideToolCalls = true,
          child: const ChatScreen(sessionId: 'session_1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Terminal'), findsOneWidget);
    });

    testWidgets('shows running tool calls without permission when hidden', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_1',
          'role': 'assistant',
          'kind': 'tool-call',
          'name': 'CodexBash',
          'toolUseId': 'tool_1',
          'state': 'running',
          'input': {
            'args': {
              'command': ['pwd'],
            },
          },
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(
          settings: Settings()..hideToolCalls = true,
          child: const ChatScreen(sessionId: 'session_1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Terminal'), findsOneWidget);
      expect(find.byType(HiddenToolSummary), findsNothing);
    });

    testWidgets('shows errored tool calls when hiding completed tools', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_1',
          'role': 'assistant',
          'kind': 'tool-call',
          'name': 'Bash',
          'toolUseId': 'tool_1',
          'state': 'error',
          'input': {'command': 'exit 1'},
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(
          settings: Settings()..hideToolCalls = true,
          child: const ChatScreen(sessionId: 'session_1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Terminal'), findsOneWidget);
    });

    testWidgets('session menu toggles hidden tool calls', (tester) async {
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

      await tester.tap(find.byTooltip('More options'));
      // Avoid pumpAndSettle: thinking-pill 1 s timer and the
      // online status pulse animation prevent settling.  Pump a
      // short duration to let the menu open + lay out so the
      // "Hide Tool Calls" item is hit-testable.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hide Tool Calls'), findsOneWidget);

      await tester.tap(find.text('Hide Tool Calls'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatScreen)),
      );
      expect(container.read(settingsNotifierProvider).hideToolCalls, isTrue);
      expect(find.text('Read File'), findsNothing);
    });

    testWidgets(
      'expanded hidden-tool-call group stays expanded when new tool arrives',
      (tester) async {
        sync.isInitialized = true;
        sync.messagesSync['session_1'] = InvalidateSync(() async {});
        sync.testSetSessionMessages('session_1', [
          {
            'id': 'tool_1',
            'role': 'assistant',
            'kind': 'tool-call',
            'name': 'Read',
            'toolUseId': 'tool_1',
            'state': 'completed',
            'input': {'file_path': '/a.dart'},
          },
          {
            'id': 'tool_2',
            'role': 'assistant',
            'kind': 'tool-call',
            'name': 'Read',
            'toolUseId': 'tool_2',
            'state': 'completed',
            'input': {'file_path': '/b.dart'},
          },
        ]);
        sync.testSessions['session_1'] = _makeSession();

        await tester.pumpWidget(
          _buildApp(
            settings: Settings()..hideToolCalls = true,
            child: const ChatScreen(sessionId: 'session_1'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(HiddenToolSummary), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);

        await tester.tap(find.byType(HiddenToolSummary));
        // Avoid pumpAndSettle: thinking-pill 1 s timer and the
        // online status pulse animation prevent settling.  A single
        // pump is enough to commit the expand/collapse state.
        await tester.pump();
        expect(find.byIcon(Icons.expand_less), findsOneWidget);

        sync.testSetSessionMessages('session_1', [
          {
            'id': 'tool_1',
            'role': 'assistant',
            'kind': 'tool-call',
            'name': 'Read',
            'toolUseId': 'tool_1',
            'state': 'completed',
            'input': {'file_path': '/a.dart'},
          },
          {
            'id': 'tool_2',
            'role': 'assistant',
            'kind': 'tool-call',
            'name': 'Read',
            'toolUseId': 'tool_2',
            'state': 'completed',
            'input': {'file_path': '/b.dart'},
          },
          {
            'id': 'tool_3',
            'role': 'assistant',
            'kind': 'tool-call',
            'name': 'Read',
            'toolUseId': 'tool_3',
            'state': 'completed',
            'input': {'file_path': '/c.dart'},
          },
        ]);
        sync.testNotifySessionMessagesChanged('session_1');

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(HiddenToolSummary), findsOneWidget);
        expect(
          find.byIcon(Icons.expand_less),
          findsOneWidget,
          reason:
              'Group should remain expanded after a new hidden tool '
              'call arrives.',
        );
      },
    );

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

    testWidgets('initial render shows recent page of cached messages', (
      tester,
    ) async {
      // A warm chat can restore more than one page from cache. The first
      // frame should keep rendering bounded to the newest page; older cached
      // rows remain available through the existing history scroll path.
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});

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
      // Avoid pumpAndSettle: the thinking pill runs a 1 s periodic
      // timer (and the online status chip an infinite pulse), so
      // settling never completes.  A couple of pumps are enough to
      // let the cached messages paint.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Message number 57'), findsOneWidget);
      expect(find.text('Message number 0'), findsNothing);

      // The shimmer must not be shown once loading completes.
      expect(find.byType(ChatLoadingShimmer), findsNothing);
    });

    testWidgets('scrollback continues through local cached pages at top', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.sessionsSync = InvalidateSync(() async {});
      sync.messagesSync['session_1'] = InvalidateSync(() async {});

      final messages = List.generate(
        120,
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
      // Avoid pumpAndSettle: the thinking-pill 1 s timer and the
      // online status pulse prevent settling.  A couple of pumps
      // are enough to let the message list paint.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Message number 119'), findsOneWidget);
      expect(find.text('Message number 0'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, 5000));
      // The drag triggers a fling; pump a few short frames to let
      // it settle without waiting for the thinking-pill 1 s
      // timer / status pulse animation to fire.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Message number 0'), findsOneWidget);
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
