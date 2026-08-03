// Regression coverage for the send-stall watchdog.
//
// The watchdog used to relabel an optimistic row 'pending'
// ("Retry queued") after a flat 5 s, while the send path only hands the
// message to the outbox at its own (12 s) deadline. Between those two
// points the UI — and VoiceOver — claimed a retry was queued for a send
// that was simply slow and about to succeed.
//
// The escalation is now gated on the outbox genuinely owning the
// message, so these tests pin both halves: silent while in flight,
// escalating once the outbox takes over.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/outgoing_image.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/chat_action_notifier.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:happy_flutter/features/chat/widgets/chat_input_buttons.dart';
import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

import '../../helpers/fake_mmkv_platform.dart';

const _localId = 'local-stall';
const _sessionId = 'session_1';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings();

  @override
  Future<void> updateSetting<T>(String key, T value) async {}
}

/// Never resolves: mirrors a send whose POST is still in flight.
class _HangingChatActionNotifier extends ChatActionNotifier {
  final Completer<String> _never = Completer<String>();

  @override
  String createLocalMessageId() => _localId;

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
  }) {
    return _never.future;
  }
}

Session _makeSession() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Session(
    id: _sessionId,
    seq: 1,
    createdAt: now - 10000,
    updatedAt: now - 5000,
    active: true,
    activeAt: now - 5000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'online',
  );
}

Widget _buildApp() {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(_StorageFreeSettingsNotifier.new),
      chatActionNotifierProvider.overrideWith(_HangingChatActionNotifier.new),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ChatScreen(sessionId: _sessionId),
    ),
  );
}

class _FakeMMKVStorage extends MMKVStorage {
  _FakeMMKVStorage() : super.testConstructor();

  String? _outbox;

  @override
  Future<String?> getOutboxEntries() async => _outbox;

  @override
  Future<void> saveOutboxEntries(String json) async {
    _outbox = json;
  }
}

Future<void> _typeAndSend(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'stalling message');
  await tester.pump();
  await tester.tap(find.byType(SendButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  // Sanity: the composer cleared, so the send really started and the
  // remaining 'stalling message' text is the optimistic bubble.
  expect(
    find.widgetWithText(TextField, 'stalling message'),
    findsNothing,
    reason: 'the composer must clear once the send starts',
  );
  expect(find.text('stalling message'), findsWidgets);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MMKVPluginPlatform? originalMMKVPlatform;

  setUpAll(() {
    originalMMKVPlatform = MMKVPluginPlatform.instance;
    MMKVPluginPlatform.instance = FakeMmkvPlatform();
  });

  tearDownAll(() async {
    MMKVPluginPlatform.instance = originalMMKVPlatform;
    await TtsService().dispose();
  });

  setUp(() {
    sync.isInitialized = true;
    sync.messagesSync[_sessionId] = InvalidateSync(() async {});
    sync.testSessions[_sessionId] = _makeSession();
    sync.testSetSessionMessages(_sessionId, const []);
    messageOutbox.dispose();
    messageOutbox.testStorage = _FakeMMKVStorage();
    messageOutbox.configure(
      deliver: (_) async => OutboxDeliveryFailure.permanent,
    );
  });

  tearDown(() async {
    messageOutbox.dispose();
    messageOutbox.testStorage = MMKVStorage.testConstructor();
    sync.testClearSessionMessageState(_sessionId);
    sync.testSessions.remove(_sessionId);
    sync.messagesSync.remove(_sessionId);
    sync.isInitialized = false;
    await TtsService().dispose();
  });

  testWidgets(
    'does NOT show "Retry queued" while the send is still in flight',
    (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await _typeAndSend(tester);

      // Well past the old flat 5 s stall threshold, and past the send
      // deadline too — but the outbox never took the message, so no
      // retry is queued and the UI must not claim otherwise.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 6));

      expect(
        find.text('Retry queued'),
        findsNothing,
        reason:
            'The watchdog must not announce a retry the outbox never took.',
      );

      // Let the watchdog retire so no timer outlives the test: hand the
      // message over and pump one more interval.
      messageOutbox.testInsertPending(
        OutboxEntry(
          localId: _localId,
          sessionId: _sessionId,
          text: 'stalling message',
          encryptedContent: 'enc',
          rawRecord: const {},
          queuedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets(
    'shows "Retry queued" once the outbox actually owns the message',
    (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await _typeAndSend(tester);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Retry queued'), findsNothing);

      // The send path hands the message over.
      messageOutbox.testInsertPending(
        OutboxEntry(
          localId: _localId,
          sessionId: _sessionId,
          text: 'stalling message',
          encryptedContent: 'enc',
          rawRecord: const {},
          queuedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      await tester.pump(const Duration(seconds: 6));
      expect(
        find.text('Retry queued'),
        findsWidgets,
        reason: 'Once the outbox owns the row the label is truthful.',
      );
    },
  );
}
