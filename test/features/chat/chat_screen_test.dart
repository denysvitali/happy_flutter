import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';
import 'package:happy_flutter/features/chat/chat_input.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:happy_flutter/features/chat/widgets/chat_input_buttons.dart';
import 'package:happy_flutter/features/chat/widgets/chat_loading_shimmer.dart';
import 'package:happy_flutter/features/chat/widgets/hidden_tool_summary.dart';
import 'package:happy_flutter/features/chat/widgets/input_toolbar.dart'
    show ModelChip;
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';
import 'package:happy_flutter/features/chat/widgets/permission_mode_selector.dart';
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
    sync.testFetchOlderMessagesOverride = null;
    sync.testClearSessionMessageState('session_1');
    sync.testSessions.remove('session_1');
    sync.isInitialized = false;
    ChatScreen.testInitialSettingsApplyBarrier = null;
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

    testWidgets('renders unknown agent-event types as fallback rows', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_evt',
          'role': 'agent',
          'kind': 'agent-event',
          'event': <String, dynamic>{
            'type': 'legacy-status',
            'message': 'Legacy status update',
          },
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Legacy status update'), findsOneWidget);
    });

    testWidgets('renders malformed agent-event payload as fallback row', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_evt',
          'role': 'agent',
          'kind': 'agent-event',
          'event': <String, dynamic>{'unexpected': 'value'},
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Unsupported agent event'), findsOneWidget);
    });

    testWidgets('skips telemetry-only agent events in chat list', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_evt',
          'role': 'agent',
          'kind': 'agent-event',
          'event': <String, dynamic>{'type': 'usage_report', 'cost': 3},
        },
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('usage_report'), findsNothing);
      expect(find.byKey(const ValueKey('header-beginning')), findsOneWidget);
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

    testWidgets('input suggests /goal and inserts it without double slash', (
      tester,
    ) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: ChatInput(
              sessionId: 'session_1',
              controller: controller,
              onSend: () {},
              availableSlashCommands: const ['/goal'],
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '/g');
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('goal'), findsOneWidget);
      expect(find.text('Set or update the current goal'), findsOneWidget);

      await tester.tap(find.text('goal'));
      await tester.pump();

      expect(controller.text, '/goal ');
    });

    testWidgets('input suggests slash commands advertised by the session', (
      tester,
    ) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        _buildApp(
          child: Scaffold(
            body: ChatInput(
              sessionId: 'session_1',
              controller: controller,
              onSend: () {},
              availableSlashCommands: const ['team-onboarding'],
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '/team');
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('team-onboarding'), findsOneWidget);

      await tester.tap(find.text('team-onboarding'));
      await tester.pump();

      expect(controller.text, '/team-onboarding ');
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
      'shows stopped-process feedback and disables sends '
      'without restore target',
      (tester) async {
        final semantics = tester.ensureSemantics();
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
        expect(find.text('Session agent failed'), findsOneWidget);
        expect(
          find.textContaining('No live local process is attached'),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField), 'continue');
        await tester.pump();

        expect(
          tester.getSemantics(find.byType(SendButton)),
          isSemantics(
            label: 'Send',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pump();

        expect(sync.messagesForSession('session_1'), isEmpty);
        expect(find.text('continue'), findsOneWidget);
        semantics.dispose();
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
      expect(find.text('Session agent failed'), findsOneWidget);
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

      expect(
        find.textContaining('Read File', findRichText: true),
        findsOneWidget,
      );
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

      expect(
        find.textContaining('Terminal', findRichText: true),
        findsOneWidget,
      );
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

      expect(
        find.textContaining('Terminal', findRichText: true),
        findsOneWidget,
      );
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

      expect(
        find.textContaining('Terminal', findRichText: true),
        findsOneWidget,
      );
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

      expect(
        find.textContaining('Read File', findRichText: true),
        findsOneWidget,
      );

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

      for (
        var attempt = 0;
        attempt < 4 && find.text('Message number 0').evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView), const Offset(0, 5000));
        // The drag triggers a fling; pump a few short frames to let
        // it settle without waiting for the thinking-pill 1 s
        // timer / status pulse animation to fire.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      expect(find.text('Message number 0'), findsOneWidget);
    });

    testWidgets('scrollback continues fetching server pages while at top', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.encryption = _FakeEncryption();
      sync.sessionsSync = InvalidateSync(() async {});
      sync.messagesSync['session_1'] = InvalidateSync(() async {});

      final messages = List.generate(50, (i) {
        final seq = 201 + i;
        return {
          'id': 'msg_$seq',
          'seq': seq,
          'role': i.isEven ? 'user' : 'assistant',
          'content': 'Message number $seq',
          'createdAt': 1700000000000 + seq * 1000,
        };
      });
      sync.testSetSessionMessages('session_1', messages);
      sync.testSetSessionFirstLoadedSeq('session_1', 201);
      sync.testSessions['session_1'] = _makeSession();

      final requestedAfterSeqs = <int>[];
      sync.testFetchOlderMessagesOverride = (sessionId, afterSeq, limit) async {
        requestedAfterSeqs.add(afterSeq);
        final start = afterSeq + 1;
        final end = afterSeq == 0 ? 100 : 200;
        return {
          'messages': [
            for (var seq = start; seq <= end; seq++)
              _makeEncryptedMessage(
                'msg_$seq',
                seq: seq,
                content: 'Message number $seq',
              ),
          ],
          'hasMore': afterSeq != 0,
        };
      };

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Message number 250'), findsOneWidget);
      expect(find.text('Message number 1'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, 5000));
      for (var i = 0; i < 30 && requestedAfterSeqs.length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 250));

      expect(requestedAfterSeqs, <int>[100, 0]);
      expect(sync.hasOlderMessages('session_1'), isFalse);
      expect(sync.testSessionFirstLoadedSeq('session_1'), 0);
      expect(
        sync.testSessionMessages('session_1')?.any((m) => m['seq'] == 1),
        isTrue,
      );
      sync.testFlushPendingMessageSaves();
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

  // Regression coverage for the model/permission-mode restore race: a user
  // interacts with a picker (model, profile, or permission mode) while
  // `_loadInitialSettings`'s async `DraftStorage` read is still in flight.
  // These tests mount the *real* `ChatScreen` / `_ChatScreenState` and drive
  // the actual picker UI, using `ChatScreen.testInitialSettingsApplyBarrier`
  // to deterministically pause the async restore mid-flight — unlike
  // `model_override_guard_test.dart`'s hand-copied mirror, a regression in
  // the real `_loadInitialSettings` guard (e.g. reverting to the dead
  // `_effectiveModelModeString == null` check, or dropping the permission-
  // mode guard) will fail these tests.
  group('ChatScreen initial-settings restore race (real widget)', () {
    testWidgets(
      'interactive permission-mode pick survives a still-in-flight restore',
      (tester) async {
        sync.isInitialized = true;
        sync.messagesSync['session_1'] = InvalidateSync(() async {});
        sync.testSetSessionMessages('session_1', [
          {'id': 'msg_1', 'role': 'user', 'content': 'hi'},
        ]);
        // No saved draft (the fake MMKV platform always reads null), so
        // the resolver falls back to the session's permission mode —
        // distinct from the mode the user is about to pick interactively.
        sync.testSessions['session_1'] = _makeSession().copyWith(
          permissionMode: 'acceptEdits',
        );

        final barrier = Completer<void>();
        ChatScreen.testInitialSettingsApplyBarrier = () => barrier.future;

        await tester.pumpWidget(
          _buildApp(child: const ChatScreen(sessionId: 'session_1')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The async restore is parked on the barrier. Interact with the
        // permission-mode picker before it resolves.
        await tester.tap(find.byType(PermissionModeSelector));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Plan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          tester
              .widget<PermissionModeSelector>(
                find.byType(PermissionModeSelector),
              )
              .selectedMode,
          PermissionMode.plan,
        );

        // Release the in-flight restore. Its stale session-derived
        // resolution (acceptEdits) must not clobber the user's pick.
        barrier.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          tester
              .widget<PermissionModeSelector>(
                find.byType(PermissionModeSelector),
              )
              .selectedMode,
          PermissionMode.plan,
        );

        // Flush MMKVStorage's debounced persist timer (500ms) so the test
        // binding doesn't flag a pending timer on teardown.
        await tester.pump(const Duration(milliseconds: 600));
      },
    );

    testWidgets(
      'interactive model-mode pick survives a still-in-flight restore',
      (tester) async {
        sync.isInitialized = true;
        sync.messagesSync['session_1'] = InvalidateSync(() async {});
        sync.testSetSessionMessages('session_1', [
          {'id': 'msg_1', 'role': 'user', 'content': 'hi'},
        ]);
        // No saved draft, so the resolver falls back to the session's
        // model mode (sonnet) — distinct from the model the user is
        // about to pick interactively (opus).
        sync.testSessions['session_1'] = _makeSession().copyWith(
          modelMode: 'sonnet',
        );

        final barrier = Completer<void>();
        ChatScreen.testInitialSettingsApplyBarrier = () => barrier.future;

        await tester.pumpWidget(
          _buildApp(child: const ChatScreen(sessionId: 'session_1')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The async restore is parked on the barrier. Interact with the
        // model picker before it resolves.
        await tester.tap(find.byType(ModelChip));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Opus'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          tester.widget<ModelChip>(find.byType(ModelChip)).model,
          ChatModelMode.opus,
        );

        // Release the in-flight restore. Its stale session-derived
        // resolution (sonnet) must not clobber the user's pick.
        barrier.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          tester.widget<ModelChip>(find.byType(ModelChip)).model,
          ChatModelMode.opus,
        );

        // Flush MMKVStorage's debounced persist timer (500ms) so the test
        // binding doesn't flag a pending timer on teardown.
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
  });
}

class _FakeEncryption implements Encryption {
  final Map<String, _FakeSessionEncryption> _sessions = {};
  var _nextId = 0;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => _FakeSessionEncryption(sessionId: sessionId),
    );
  }

  @override
  String generateId() => 'test-local-id-${_nextId++}';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionEncryption extends SessionEncryption {
  _FakeSessionEncryption({required String sessionId})
    : super(
        sessionId: sessionId,
        encryptor: _FakeEncryptor(),
        decryptor: _FakeEncryptor(),
        cache: EncryptionCache(),
      );
}

class _FakeEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    return data.map((item) {
      final json = jsonEncode(item);
      final bytes = utf8.encode(json);
      final output = Uint8List(bytes.length + 1);
      output[0] = 0x01;
      output.setRange(1, output.length, bytes);
      return output;
    }).toList();
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    return data.map((item) {
      if (item.isEmpty) return null;
      try {
        return item[0] == 0x01
            ? jsonDecode(utf8.decode(item.sublist(1)))
            : utf8.decode(item);
      } catch (_) {
        return null;
      }
    }).toList();
  }
}

Map<String, dynamic> _makeEncryptedMessage(
  String id, {
  required int seq,
  required String content,
}) {
  final innerContent = {
    'role': 'agent',
    'content': {
      'type': 'output',
      'data': {'type': 'assistant', 'message': content},
    },
  };
  final json = jsonEncode(innerContent);
  final bytes = utf8.encode(json);
  final output = Uint8List(bytes.length + 1);
  output[0] = 0x01;
  output.setRange(1, output.length, bytes);
  return {
    'id': id,
    'seq': seq,
    'role': 'agent',
    'content': {'t': 'encrypted', 'c': base64Encode(output)},
    'createdAt': 1700000000000 + seq * 1000,
  };
}
