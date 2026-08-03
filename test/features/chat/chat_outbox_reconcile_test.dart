// Regression coverage for outbox-state reconciliation on chat open.
//
// The outbox republishes dead-letter statuses once, at startup, through
// `onStatusChanged` — which drops everything for sessions whose messages
// are not loaded yet (i.e. almost every session at cold start). A row
// restored from the MMKV cache with its last persisted 'sending' status
// therefore spun forever, and since the retry affordance only renders
// for 'failed', the preserved dead-letter payload was unreachable.
//
// Opening the chat must now reconcile the row against the outbox.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';
import 'package:happy_flutter/features/chat/chat_screen.dart';
import 'package:mmkv_platform_interface/mmkv_platform_interface.dart';

import '../../helpers/fake_mmkv_platform.dart';

const _sessionId = 'session_1';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings();

  @override
  Future<void> updateSetting<T>(String key, T value) async {}
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
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ChatScreen(sessionId: _sessionId),
    ),
  );
}

OutboxEntry _entry(String localId) => OutboxEntry(
  localId: localId,
  sessionId: _sessionId,
  text: 'stranded message',
  encryptedContent: 'enc',
  rawRecord: const {},
  queuedAt: DateTime.now().millisecondsSinceEpoch,
);

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
    messageOutbox.dispose();
    messageOutbox.testStorage = MMKVStorage.testConstructor();
    messageOutbox.configure(
      deliver: (_) async => OutboxDeliveryFailure.permanent,
    );
  });

  tearDown(() async {
    messageOutbox.dispose();
    sync.testClearSessionMessageState(_sessionId);
    sync.testSessions.remove(_sessionId);
    sync.messagesSync.remove(_sessionId);
    sync.isInitialized = false;
    await TtsService().dispose();
  });

  test('reconcileOutboxStatuses maps outbox buckets onto rows', () {
    sync.testSetSessionMessages(_sessionId, [
      {
        'id': 'dead-1',
        'localId': 'dead-1',
        'role': 'user',
        'content': 'stranded message',
        'sendStatus': 'sending',
      },
      {
        'id': 'live-1',
        'localId': 'live-1',
        'role': 'user',
        'content': 'queued message',
        'sendStatus': 'sending',
      },
      {
        'id': 'other',
        'localId': 'other',
        'role': 'user',
        'content': 'untouched',
        'sendStatus': 'sending',
      },
    ]);
    messageOutbox.testInsertDead(_entry('dead-1'));
    messageOutbox.testInsertPending(_entry('live-1'));

    expect(sync.reconcileOutboxStatuses(_sessionId), 2);

    final rows = sync.testGetSessionMessages(_sessionId)!;
    expect(rows[0]['sendStatus'], 'failed');
    expect(rows[1]['sendStatus'], 'pending');
    expect(
      rows[2]['sendStatus'],
      'sending',
      reason: 'rows the outbox knows nothing about must be left alone',
    );
  });

  testWidgets(
    'opening a chat marks a dead-lettered row failed so it is retryable',
    (tester) async {
      // Cache-restored row: last persisted status was 'sending'.
      sync.testSetSessionMessages(_sessionId, [
        {
          'id': 'dead-1',
          'localId': 'dead-1',
          'role': 'user',
          'content': 'stranded message',
          'sendStatus': 'sending',
        },
      ]);
      messageOutbox.testInsertDead(_entry('dead-1'));

      await tester.pumpWidget(_buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        sync.testGetSessionMessages(_sessionId)!.single['sendStatus'],
        'failed',
        reason:
            'a dead-lettered message must not keep spinning: only the '
            "'failed' row renders the retry affordance.",
      );
      expect(find.text('Failed — tap to retry'), findsWidgets);

      // Drain the debounced message-save timer the notification schedules.
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
