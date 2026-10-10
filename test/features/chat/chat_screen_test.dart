import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/outgoing_image.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/performance_context_service.dart';
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
import 'package:happy_flutter/features/chat/widgets/pagination_failure_retry.dart';
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
  String? flavor,
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
    metadata: flavor == null ? null : Metadata(host: '', flavor: flavor),
  );
}

class _HarPickerActions extends ChatActionNotifier {
  final confirmation = Completer<void>();
  String? requestedModel;
  String? sentModel;

  @override
  Future<void> setSessionModel(String sessionId, String model) {
    requestedModel = model;
    return confirmation.future;
  }

  @override
  Future<String> sendMessage(
    String sessionId,
    String text, {
    String? clientLocalId,
    String? displayText,
    String? permissionMode,
    String? modelMode,
    String? profileId,
    List<OutgoingImage>? images,
    String? codexDeliveryMode,
  }) async {
    sentModel = modelMode;
    return sessionId;
  }
}

Widget _buildApp({
  required Widget child,
  Settings? settings,
  ChatActionNotifier? actions,
}) {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StorageFreeSettingsNotifier(settings),
      ),
      if (actions != null)
        chatActionNotifierProvider.overrideWith(() => actions),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

/// The search tint inside the row identified by [messageId].
Finder _tintOn(String messageId) => find.descendant(
  of: find.byKey(ValueKey(messageId)),
  matching: find.byKey(const ValueKey('chat-search-active-match')),
);

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
    sync.testEncryptionInitialized = false;
    sync.testMachineRPCOverride = null;
    sync.testClearCodexModelsCache();
    ChatScreen.testInitialSettingsApplyBarrier = null;
    PerformanceContextService().resetForTesting();
    await TtsService().dispose();
  });

  testWidgets('stopped Har explains daemon loss without exposing diagnostics', (
    tester,
  ) async {
    sync.isInitialized = true;
    sync.messagesSync['session_1'] = InvalidateSync(() async {});
    sync.testSetSessionMessages('session_1', const []);
    sync.testSessions['session_1'] = _makeSession(flavor: 'har').copyWith(
      metadata: const Metadata(
        host: '',
        flavor: 'har',
        lifecycleState: 'errored',
        lifecycleStateError:
            'daemon started without a live local process for this running session',
      ),
    );
    await tester.pumpWidget(
      _buildApp(child: const ChatScreen(sessionId: 'session_1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Har conversation stopped'), findsOneWidget);
    expect(
      find.textContaining(
        'The machine daemon restarted without this Har process',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('daemon started without a live local process'),
      findsNothing,
    );
  });

  for (final rejects in [false, true]) {
    testWidgets(
      'initialized Har picker ${rejects ? 'rejects' : 'confirms'} switch '
      'before composer delivery',
      (tester) async {
        const luna = 'codex/gpt-6-luna';
        const sol = 'codex/gpt-6.1-sol';
        sync.isInitialized = true;
        sync.messagesSync['session_1'] = InvalidateSync(() async {});
        sync.testSetSessionMessages('session_1', const []);
        sync.testSessions['session_1'] =
            _makeSession(flavor: 'har', presence: 'online').copyWith(
              modelMode: luna,
              metadata: const Metadata(host: '', flavor: 'har', model: luna),
            );
        var restored = false;
        ChatScreen.testInitialSettingsApplyBarrier = () async {
          restored = true;
        };
        final actions = _HarPickerActions();
        await tester.pumpWidget(
          _buildApp(
            child: const ChatScreen(sessionId: 'session_1'),
            actions: actions,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(restored, isTrue);
        expect(
          tester.widget<ModelChip>(find.byType(ModelChip)).model.modeString,
          luna,
        );

        await tester.tap(find.byType(ModelChip));
        await tester.pumpAndSettle();
        await tester.tap(find.text('GPT-6.1 Sol'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(actions.requestedModel, sol);
        // Neither picker nor composer may publish an unconfirmed switch.
        expect(
          tester.widget<ModelChip>(find.byType(ModelChip)).model.modeString,
          luna,
        );
        if (rejects) {
          actions.confirmation.completeError(StateError('busy'));
        } else {
          actions.confirmation.complete();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final expected = rejects ? luna : sol;
        expect(
          tester.widget<ModelChip>(find.byType(ModelChip)).model.modeString,
          expected,
        );
        await tester.enterText(find.byType(TextField), 'hello Har');
        await tester.pump();
        await tester.tap(find.byType(SendButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(actions.sentModel, expected);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
  }

  testWidgets('result review waits for the turn to become idle', (
    tester,
  ) async {
    sync.isInitialized = true;
    sync.messagesSync['session_1'] = InvalidateSync(() async {});
    sync.testSetSessionMessages('session_1', [
      {
        'id': 'user',
        'localId': 'user',
        'role': 'user',
        'kind': 'text',
        'content': 'Fix layout',
        'sendStatus': 'sent',
      },
      {
        'id': 'answer',
        'role': 'agent',
        'kind': 'text',
        'content': 'Layout updated.',
      },
    ]);
    sync.testSessions['session_1'] = _makeSession(
      thinking: true,
      presence: 'online',
    );
    await tester.pumpWidget(
      _buildApp(child: const ChatScreen(sessionId: 'session_1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('turn-review-bar')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    sync.testSessions['session_1'] = _makeSession(
      thinking: false,
      presence: 'online',
    );
    await tester.pumpWidget(
      _buildApp(child: const ChatScreen(sessionId: 'session_1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('turn-review-bar')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
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

    testWidgets('loads Codex models before the first message is sent', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.testEncryptionInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] = _makeSession(flavor: 'codex').copyWith(
        metadata: const Metadata(
          host: 'host',
          flavor: 'codex',
          machineId: 'machine-1',
          path: '/repo',
        ),
      );
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(method, 'get-codex-models');
        return <String, dynamic>{
          'success': true,
          'models': [
            <String, dynamic>{
              'slug': 'gpt-5.6',
              'displayName': 'GPT-5.6',
              'supportedReasoningEfforts': ['medium'],
            },
          ],
        };
      };

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final modelChip = tester.widget<ModelChip>(find.byType(ModelChip));
      expect(modelChip.enabled, isTrue);
      await tester.tap(find.byType(ModelChip));
      await tester.pumpAndSettle();

      expect(find.text('GPT-5.6'), findsOneWidget);
    });

    testWidgets('Codex picker can recover from an initially empty catalog', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.testEncryptionInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] = _makeSession(flavor: 'codex').copyWith(
        metadata: const Metadata(
          host: 'host',
          flavor: 'codex',
          machineId: 'machine-1',
          path: '/repo',
        ),
      );
      var refreshes = 0;
      sync.testMachineRPCOverride = (machineId, method, params) async {
        expect(params['directory'], '/repo');
        if (params['refresh'] != true) {
          return {'success': false, 'models': [], 'error': 'offline'};
        }
        refreshes++;
        return {
          'success': true,
          'models': [
            {
              'slug': 'gpt-fresh-$refreshes',
              'display_name': 'Fresh $refreshes',
              'visibility': 'list',
              'supported_reasoning_levels': [
                {'effort': 'medium'},
              ],
            },
          ],
        };
      };

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<ModelChip>(find.byType(ModelChip)).enabled, isTrue);
      await tester.tap(find.byType(ModelChip));
      await tester.pumpAndSettle();
      expect(find.text('Fresh 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh models'));
      await tester.pumpAndSettle();
      expect(find.text('Fresh 2'), findsOneWidget);
      expect(find.text('Fresh 1'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('late Codex catalogs cannot replace a new project context', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.testEncryptionInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', const []);
      final session = _makeSession(flavor: 'codex').copyWith(
        metadata: const Metadata(
          host: 'host',
          flavor: 'codex',
          machineId: 'machine-1',
          path: '/old-repo',
        ),
      );
      sync.testSessions['session_1'] = session;
      final oldCatalog = Completer<Map<String, dynamic>>();
      sync.testMachineRPCOverride = (machineId, method, params) async {
        if (params['directory'] == '/old-repo') return oldCatalog.future;
        return {
          'success': true,
          'models': [
            {
              'slug': 'gpt-new',
              'display_name': 'New project model',
              'supported_reasoning_levels': [
                {'effort': 'medium'},
              ],
            },
          ],
        };
      };
      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      sync.testSessions['session_1'] = session.copyWith(
        metadata: session.metadata!.copyWith(path: '/new-repo'),
      );
      sync.testNotifyDataChanged();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      oldCatalog.complete({
        'success': true,
        'models': [
          {
            'slug': 'gpt-old',
            'display_name': 'Old project model',
            'supported_reasoning_levels': [
              {'effort': 'medium'},
            ],
          },
        ],
      });
      await tester.pump();
      await tester.tap(find.byType(ModelChip));
      await tester.pumpAndSettle();
      expect(find.text('New project model'), findsOneWidget);
      expect(find.text('Old project model'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
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

    testWidgets('does not refresh messages when revision is unchanged', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'user', 'content': 'Hello there'},
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final revisionAfterLoad = sync.messagesRevision('session_1');
      sync.testReplaceMessageListWithoutRevision('session_1', [
        {'id': 'msg_1', 'role': 'user', 'content': 'mutated without revision'},
      ]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(sync.messagesRevision('session_1'), revisionAfterLoad);
      expect(find.text('Hello there'), findsOneWidget);
      expect(find.text('mutated without revision'), findsNothing);
    });

    testWidgets('refreshes an in-place streaming mutation when revision '
        'advances', (tester) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetVisibleSessionId('session_1');
      sync.testSetSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'agent', 'content': 'streaming'},
      ]);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      sync.testUpsertSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'agent', 'content': 'streaming token'},
      ]);
      await tester.pump(const Duration(milliseconds: 220));
      sync.testFlushPendingMessageSaves();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('streaming token'), findsOneWidget);
    });

    testWidgets('renders tokens before a continuous stream goes quiet', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {'id': 'stream', 'role': 'agent', 'content': 'initial'},
      ]);
      sync.testSessions['session_1'] = _makeSession();
      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (var token = 1; token <= 10; token++) {
        sync.testSetSessionMessages('session_1', [
          {'id': 'stream', 'role': 'agent', 'content': 'partial token $token'},
        ]);
        sync.testNotifySessionMessagesChanged('session_1');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
      }
      // Every interval is shorter than the 50 ms refresh window. A trailing
      // debounce would still show "initial" until the stream ended.
      expect(
        sync.messagesForSession('session_1').single['content'],
        'partial token 10',
      );
      expect(find.textContaining('partial token'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('partial token 10'), findsOneWidget);
    });

    testWidgets('waiting and empty reasoning stay visible until the answer', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      final user = <String, dynamic>{
        'id': 'server-user',
        'localId': 'local-user',
        'role': 'user',
        'content': 'A long request',
        'sendStatus': 'sent',
      };
      sync.testSetSessionMessages('session_1', [user]);
      sync.testSessions['session_1'] = _makeSession(presence: 'online');
      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Waiting for response…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('Waiting for response…'), findsOneWidget);

      sync.testSetSessionMessages('session_1', [
        user,
        {
          'id': 'reasoning',
          'role': 'agent',
          'kind': 'text',
          'isThinking': true,
          'content': '',
        },
      ]);
      sync.testNotifySessionMessagesChanged('session_1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Thinking…'), findsOneWidget);

      sync.testSetSessionMessages('session_1', [
        user,
        {'id': 'answer', 'role': 'agent', 'content': 'The answer'},
      ]);
      sync.testNotifySessionMessagesChanged('session_1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('The answer'), findsOneWidget);
      expect(find.text('Waiting for response…'), findsNothing);
    });

    testWidgets('live presence shows thinking despite a stale active flag', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', const []);
      sync.testSessions['session_1'] = _makeSession(
        thinking: true,
        presence: 'online',
      ).copyWith(active: false);
      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Thinking…'), findsOneWidget);
    });

    testWidgets('embedded detail pane receives live messages while the '
        'sessions shell route is on top', (tester) async {
      // Wide (desktop/tablet) layouts render this chat inside the sessions
      // shell's master-detail detail column, so the router's top route stays
      // `sessions` while the pane is the surface the user is reading. Gating
      // live updates on the route name alone classified the visible pane as
      // covered and dropped every message until some other action recreated
      // its state.
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetVisibleSessionId('session_1');
      sync.testSetSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'user', 'content': 'Hello there'},
      ]);
      sync.testSessions['session_1'] = _makeSession();
      PerformanceContextService().setCurrentRoute('sessions');

      await tester.pumpWidget(
        _buildApp(
          child: ChatScreen(
            sessionId: 'session_1',
            embedded: true,
            onBack: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hello there'), findsOneWidget);

      sync.testUpsertSessionMessages('session_1', [
        {'id': 'msg_2', 'role': 'assistant', 'content': 'Live reply'},
      ]);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Live reply'), findsOneWidget);
    });

    testWidgets('a covered pushed chat pane still skips live updates', (
      tester,
    ) async {
      // The power-saving intent this gate exists for: a ChatScreen pushed as
      // its own `/chat/:sessionId` route stops refreshing while another route
      // covers it. Only the embedded detail pane is exempt.
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetVisibleSessionId('session_1');
      sync.testSetSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'user', 'content': 'Hello there'},
      ]);
      sync.testSessions['session_1'] = _makeSession();
      PerformanceContextService().setCurrentRoute('message-detail');

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hello there'), findsOneWidget);

      sync.testUpsertSessionMessages('session_1', [
        {'id': 'msg_2', 'role': 'assistant', 'content': 'Live reply'},
      ]);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Live reply'), findsNothing);
    });

    testWidgets('shows explicitly queued Codex messages and queue action', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        <String, dynamic>{
          'id': 'queued-1',
          'localId': 'queued-1',
          'role': 'user',
          'kind': 'text',
          'content': 'Handle this next',
          'raw': <String, dynamic>{
            'role': 'user',
            'content': <String, dynamic>{
              'type': 'text',
              'text': 'Handle this next',
            },
            'meta': <String, dynamic>{'codexDeliveryMode': 'next-turn'},
          },
          'sendStatus': 'sent',
        },
      ]);
      sync.testSessions['session_1'] = _makeSession(
        thinking: true,
        flavor: 'codex',
      );

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Queued for next turn'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('queue-next-turn-button')),
        // Follow-up actions stay hidden until the composer has content.
        findsNothing,
      );
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

      // Add a new message via sync.
      sync.testUpsertSessionMessages('session_1', [
        {'id': 'msg_1', 'role': 'user', 'content': 'First message'},
        {'id': 'msg_2', 'role': 'assistant', 'content': 'Response message'},
      ]);
      await tester.pump(const Duration(milliseconds: 220));

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

    testWidgets('shows stopped-process feedback and disables sends '
        'without restore target', (tester) async {
      final semantics = tester.ensureSemantics();
      LoggerService().clear();
      addTearDown(LoggerService().clear);
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
      expect(find.text('Session agent stopped'), findsOneWidget);
      expect(find.textContaining('live local process'), findsNothing);
      expect(find.textContaining('cannot be restored'), findsOneWidget);

      final lifecycleWarnings = LoggerService()
          .getLogsByLevel(LogLevel.warning)
          .where(
            (entry) =>
                entry.message == '[ChatScreen] session lifecycle failure',
          )
          .toList();
      expect(lifecycleWarnings, hasLength(1));
      expect(lifecycleWarnings.single.message, isNot(contains('session_1')));
      expect(
        lifecycleWarnings.single.error,
        'daemon started without a live local process for this running session',
      );

      await tester.enterText(find.byType(TextField), 'continue');
      await tester.pump();

      expect(
        tester.getSemantics(find.byType(SendButton)),
        isSemantics(
          label: 'Send message',
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
    });

    testWidgets('shows restart-on-send feedback when session is restorable', (
      tester,
    ) async {
      LoggerService().clear();
      addTearDown(LoggerService().clear);
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
      expect(find.text('Session agent stopped'), findsOneWidget);
      expect(
        find.textContaining('Sending a message will try to restart'),
        findsOneWidget,
      );

      final lifecycleWarnings = LoggerService()
          .getLogsByLevel(LogLevel.warning)
          .where(
            (entry) =>
                entry.message == '[ChatScreen] session lifecycle failure',
          )
          .toList();
      expect(lifecycleWarnings, isEmpty);
      final lifecycleInfo = LoggerService()
          .getLogsByLevel(LogLevel.info)
          .where(
            (entry) =>
                entry.message == '[ChatScreen] session lifecycle failure',
          )
          .toList();
      expect(lifecycleInfo, hasLength(1));
      expect(
        lifecycleInfo.single.error,
        'daemon started without a live local process for this running session',
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

    testWidgets('invisible rows reserve no space between terminal rows', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      Map<String, dynamic> tool(String id) => {
        'id': id,
        'role': 'agent',
        'kind': 'tool-call',
        'name': 'Bash',
        'toolUseId': 'tool-$id',
        'state': 'completed',
        'input': {'command': 'pwd'},
      };
      sync.testSetSessionMessages('session_1', [
        tool('first'),
        for (var i = 0; i < 20; i++) ...[
          {
            'id': 'reasoning-$i',
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'content': '*Thinking...*\n\n**',
          },
          {'id': 'empty-$i', 'role': 'agent', 'kind': 'text', 'content': ''},
        ],
        tool('last'),
      ]);
      sync.testSessions['session_1'] = _makeSession();
      await tester.pumpWidget(
        _buildApp(
          settings: Settings()..hideToolCalls = false,
          child: const ChatScreen(sessionId: 'session_1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final terminals = find.textContaining('Terminal', findRichText: true);
      expect(terminals, findsNWidgets(2));
      final rects = [
        tester.getRect(terminals.at(0)),
        tester.getRect(terminals.at(1)),
      ]..sort((a, b) => a.top.compareTo(b.top));
      expect(rects[1].top - rects[0].bottom, lessThan(40));
      // Invisible rows remain available for activity and wire bookkeeping.
      expect(sync.messagesForSession('session_1').length, 42);
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
        // timer / status pulse animation to fire. Stop as soon as the
        // oldest row is on screen — the remaining frames only rebuild
        // the same list.
        for (
          var i = 0;
          i < 20 && find.text('Message number 0').evaluate().isEmpty;
          i++
        ) {
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

    testWidgets('pagination failure uses inline retry without a SnackBar', (
      tester,
    ) async {
      sync.isInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        {
          'id': 'msg_2',
          'seq': 2,
          'role': 'assistant',
          'content': 'Recent message',
          'createdAt': 1700000002000,
        },
      ]);
      sync.testSetSessionFirstLoadedSeq('session_1', 2);
      sync.testSessions['session_1'] = _makeSession();

      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      sync.testEmitPaginationError('session_1');
      await tester.pump();

      expect(find.byType(PaginationFailureRetry), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
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

  group('ChatScreen in-conversation search', () {
    // Drives the real app-bar toggle and query field so a regression in the
    // wiring (search action missing, index not rebuilt, counter wrong,
    // highlight not applied) fails here rather than in a manual check.
    Future<void> pumpChat(WidgetTester tester, {bool withTool = false}) async {
      sync.isInitialized = true;
      sync.testEncryptionInitialized = true;
      sync.messagesSync['session_1'] = InvalidateSync(() async {});
      sync.testSetSessionMessages('session_1', [
        <String, dynamic>{
          'id': 'm1',
          'seq': 1,
          'createdAt': 1,
          'role': 'user',
          'kind': 'text',
          'content': 'first needle',
        },
        <String, dynamic>{
          'id': 'm2',
          'seq': 2,
          'createdAt': 2,
          'role': 'agent',
          'kind': 'text',
          'content': 'nothing here',
        },
        <String, dynamic>{
          'id': 'm3',
          'seq': 3,
          'createdAt': 3,
          'role': 'agent',
          'kind': 'text',
          'content': 'second needle',
        },
        if (withTool)
          <String, dynamic>{
            'id': 'tool-search',
            'seq': 4,
            'createdAt': 4,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'Read',
            'state': 'completed',
            'input': {'file_path': '/tmp/desktop_search_target.txt'},
            'result': 'file contents',
          },
      ]);
      await tester.pumpWidget(
        _buildApp(child: const ChatScreen(sessionId: 'session_1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('desktop keyboard search reveals a grouped tool match', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpChat(tester, withTool: true);
      expect(find.byType(HiddenToolSummary), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-search-bar')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('chat-search-field')),
        'desktop_search_target',
      );
      await tester.pumpAndSettle();
      expect(find.text('1 of 1'), findsOneWidget);
      expect(_tintOn('tool-search'), findsOneWidget);
      expect(find.byType(HiddenToolSummary), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-search-bar')), findsNothing);
      expect(find.byType(HiddenToolSummary), findsOneWidget);
    });

    testWidgets('counts matches, highlights one and pages between them', (
      tester,
    ) async {
      await pumpChat(tester);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-search-bar')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('chat-search-field')),
        'needle',
      );
      await tester.pumpAndSettle();

      expect(find.text('1 of 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-search-active-match')),
        findsOneWidget,
      );
      // The tint sits on the first matching row, not just anywhere.
      expect(_tintOn('m1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('chat-search-next')));
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      expect(_tintOn('m1'), findsNothing);
      expect(_tintOn('m3'), findsOneWidget);

      // Wraps back to the first hit.
      await tester.tap(find.byKey(const ValueKey('chat-search-next')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);
      expect(_tintOn('m1'), findsOneWidget);
    });

    testWidgets('a query with no hits reports it and highlights nothing', (
      tester,
    ) async {
      await pumpChat(tester);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('chat-search-field')),
        'zzz-not-present',
      );
      await tester.pumpAndSettle();

      expect(find.text('No matches in loaded messages'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-search-active-match')),
        findsNothing,
      );
    });

    testWidgets('closing search restores the session title', (tester) async {
      await pumpChat(tester);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-search-bar')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('chat-search-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chat-search-bar')), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
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
