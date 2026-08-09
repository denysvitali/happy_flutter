import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat switching measures tap to first frame and content', () {
    final metrics = File(
      'lib/core/services/chat_switch_metrics.dart',
    ).readAsStringSync();
    final chat = File('lib/features/chat/chat_screen.dart').readAsStringSync();
    final sessions = File(
      'lib/features/sessions/widgets/sessions_list_content.dart',
    ).readAsStringSync();

    expect(metrics, contains("'app.chat.switch.first_frame'"));
    expect(metrics, contains("'app.chat.switch.content_ready'"));
    expect(chat, contains('ChatSwitchMetrics().ensureStarted'));
    expect(chat, contains('markFirstFrame'));
    expect(chat, contains('markContentReady'));
    expect(sessions, contains('ChatSwitchMetrics().begin'));

    expect(
      metrics,
      isNot(contains("'session_id'")),
      reason: 'session ids must stay on traces, not histogram labels',
    );
  });

  test('chat entry never synchronously decodes the persisted cache', () {
    final chat = File('lib/features/chat/chat_screen.dart').readAsStringSync();
    final syncVisibility = File(
      'lib/core/services/_sync_messaging_rpc.dart',
    ).readAsStringSync();
    final cache = File(
      'lib/core/services/message_cache_service.dart',
    ).readAsStringSync();

    expect(
      chat,
      isNot(contains('MessageCacheService().getMessages(')),
      reason: 'chat init must use the in-memory Sync projection only',
    );
    expect(
      chat,
      contains('await WidgetsBinding.instance.endOfFrame;'),
      reason: 'deferred regroup/cache/network work must follow first paint',
    );
    expect(syncVisibility, contains('void prepareSessionVisibility('));
    expect(
      cache,
      contains('compute(_writeMessageCacheJson'),
      reason: 'routine native MMKV writes must not run on the UI isolate',
    );
  });

  test('foreground cursor and sessions-cache saves serialize off-isolate', () {
    final socketSync = File(
      'lib/core/services/_sync_socket.dart',
    ).readAsStringSync();
    final nativeStorage = File(
      'lib/core/services/mmkv_storage_native.dart',
    ).readAsStringSync();
    final sessionsCache = File(
      'lib/core/services/sessions_cache_storage_native.dart',
    ).readAsStringSync();

    expect(socketSync, contains('saveSessionLastSeqAsync'));
    expect(socketSync, contains('saveSessionFirstLoadedSeqAsync'));
    expect(sessionsCache, contains('saveSessionsCacheAsync'));
    expect(
      nativeStorage,
      contains('compute(_encodeJsonForStorage'),
      reason:
          'full cursor/cache maps must not be JSON encoded on the UI '
          'isolate during chat navigation or pagination',
    );
  });
}
