import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/message_cache_service.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

void main() {
  late Sync sync;
  late _BlockedCacheStorage storage;
  const sessionId = 'lazy-cache-runtime';

  Map<String, dynamic> row(String id, int seq) => {
    'id': id,
    'seq': seq,
    'createdAt': seq * 1000,
    'kind': 'text',
    'role': 'user',
    'content': 'continue',
    'localId': id,
  };

  setUp(() {
    sync = createTestSync();
    resetTestSync(sync);
    sync.testIsInitialized = true;
    sync.messagesSync[sessionId] = InvalidateSync(() async {});
    sync.testSetSessionSpawnedProfile(sessionId, null);
    sync.testFetchMessagesOverride = (_, _, _) async => {
      'messages': <Map<String, dynamic>>[],
      'hasMore': false,
    };
    storage = _BlockedCacheStorage();
    MessageCacheService().debugSetStorage = storage;
  });

  tearDown(() async {
    await sync.onSessionInvisible(sessionId);
    sync.testFetchMessagesOverride = null;
    resetTestSync(sync);
    sync.testResetDataChangeDebounce();
    sync.testIsInitialized = false;
    MessageCacheService().debugResetStorage();
  });

  test(
    'initial visibility yield cannot resume in a replacement runtime',
    () async {
      final work = sync.onSessionVisible(sessionId);
      sync.testAdvanceRuntimeGeneration();
      sync.testSetSessionMessages(sessionId, [row('replacement', 7)]);
      await work;
      expect(storage.started.isCompleted, isFalse);
      expect(sync.messagesForSession(sessionId).single['id'], 'replacement');
    },
  );

  test('lazy cache read cannot replace live or optimistic rows', () async {
    final work = sync.onSessionVisible(sessionId);
    await storage.started.future;
    sync.testSetSessionMessages(sessionId, [
      row('live', 9),
      row('optimistic-retry', 0),
    ]);
    sync.testSetSessionLastSeq(sessionId, 9);
    storage.release.complete([row('cached', 3)]);
    await work;
    expect(sync.messagesForSession(sessionId).map((m) => m['id']), [
      'live',
      'optimistic-retry',
    ]);
    expect(sync.testGetSessionLastSeq(sessionId), 9);
    expect(sync.testSessionsNeedingTailRefresh(), isNot(contains(sessionId)));
  });

  for (final fails in [false, true]) {
    test(
      'lazy cache ${fails ? 'failure' : 'completion'} ignores reset',
      () async {
        final work = sync.onSessionVisible(sessionId);
        await storage.started.future;
        sync.testAdvanceRuntimeGeneration();
        sync.testClearAllSessionMessageState();
        sync.testSetSessionMessages(sessionId, [row('replacement', 7)]);
        sync.testSetSessionLastSeq(sessionId, 7);
        if (fails) {
          storage.release.completeError(StateError('old cache failed'));
        } else {
          storage.release.complete([row('cached', 3)]);
        }
        await work;
        expect(sync.messagesForSession(sessionId).single['id'], 'replacement');
        expect(sync.testGetSessionLastSeq(sessionId), 7);
        expect(sync.testHasPendingSaveTimer(sessionId), isFalse);
        expect(
          sync.testSessionsNeedingTailRefresh(),
          isNot(contains(sessionId)),
        );
      },
    );
  }

  test('cache completion ignores a chat that is no longer visible', () async {
    final work = sync.onSessionVisible(sessionId);
    await storage.started.future;
    sync.testSetVisibleSessionId('another-chat');
    storage.release.complete([row('cached', 3)]);
    await work;
    expect(sync.messagesForSession(sessionId), isEmpty);
    expect(sync.testHasPendingSaveTimer(sessionId), isFalse);
  });
}

class _BlockedCacheStorage extends MMKVStorage {
  _BlockedCacheStorage() : super.testConstructor();
  final started = Completer<void>();
  final release = Completer<List<Map<String, dynamic>>>();

  @override
  Future<String?> getSessionMessagesEncodedAsync(String sessionId) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>> getSessionMessagesAsync(String sessionId) {
    started.complete();
    return release.future;
  }

  @override
  bool saveSessionMessagesEncoded(String sessionId, String encoded) => true;
}
