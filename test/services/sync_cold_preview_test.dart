import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/message_cache_service.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

Session _session(
  String id, {
  bool active = true,
  bool archived = false,
  int? lastMessageAt,
}) => Session(
  id: id,
  seq: 1,
  createdAt: 1000,
  updatedAt: 1000,
  active: active,
  activeAt: 1000,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: false,
  presence: 'online',
  archived: archived,
  lastMessageAt: lastMessageAt,
);

Map<String, dynamic> _row(String id, int seq, String text) => {
  'id': id,
  'seq': seq,
  'createdAt': seq * 1000,
  'kind': 'text',
  'role': 'agent',
  'content': text,
};

void main() {
  late Sync sync;
  late _CacheStorage storage;

  setUp(() {
    sync = createTestSync();
    resetTestSync(sync);
    sync.testIsInitialized = true;
    storage = _CacheStorage();
    MessageCacheService().debugSetStorage = storage;
  });

  tearDown(() {
    resetTestSync(sync);
    sync.testResetDataChangeDebounce();
    sync.testIsInitialized = false;
    MessageCacheService().debugResetStorage();
  });

  test('an open session gets its cached update without a transcript', () async {
    sync.testSessions['open'] = _session('open', lastMessageAt: 5000);
    storage.rows['open'] = [_row('m1', 4, 'older'), _row('m2', 5, 'All done')];

    await sync.testWarmColdPreviews();

    expect(sync.getLastMessagePreview('open'), 'All done');
    expect(sync.getLastMessageRole('open'), 'agent');
    // Ordering, age and the error lane keep following the server catalog.
    expect(sync.getLastMessageTimestamp('open'), isNull);
    expect(sync.getLastMessageIsError('open'), isFalse);
    // Nothing became resident: no rows, no retained transcript.
    expect(sync.messagesForSession('open'), isEmpty);
  });

  test(
    'a preview older than the server\'s last message is not shown',
    () async {
      sync.testSessions['stale'] = _session('stale', lastMessageAt: 60000);
      storage.rows['stale'] = [_row('m1', 5, 'Old news')];

      await sync.testWarmColdPreviews();

      expect(sync.getLastMessagePreview('stale'), isNull);
    },
  );

  test('archived and resident sessions are left alone', () async {
    sync.testSessions['archived'] = _session('archived', archived: true);
    sync.testSessions['inactive'] = _session('inactive', active: false);
    sync.testSessions['resident'] = _session('resident');
    storage.rows['archived'] = [_row('a', 1, 'archived text')];
    storage.rows['inactive'] = [_row('i', 1, 'inactive text')];
    storage.rows['resident'] = [_row('c', 1, 'cached text')];
    sync.testSetSessionMessages('resident', [_row('live', 2, 'live text')]);

    await sync.testWarmColdPreviews();

    expect(storage.reads, isEmpty);
    expect(sync.getLastMessagePreview('archived'), isNull);
    expect(sync.getLastMessagePreview('inactive'), isNull);
    expect(sync.getLastMessagePreview('resident'), 'live text');
  });

  test('resident messages replace the cached preview', () async {
    sync.testSessions['open'] = _session('open');
    storage.rows['open'] = [_row('m1', 1, 'cached text')];
    await sync.testWarmColdPreviews();
    expect(sync.getLastMessagePreview('open'), 'cached text');

    sync.testSetSessionMessages('open', [_row('m2', 2, 'fresh text')]);
    expect(sync.getLastMessagePreview('open'), 'fresh text');
    expect(sync.getLastMessageTimestamp('open'), 2000);
  });

  test('a runtime reset during the read publishes nothing', () async {
    sync.testSessions['open'] = _session('open');
    storage.rows['open'] = [_row('m1', 1, 'old runtime')];
    storage.onRead = sync.testAdvanceRuntimeGeneration;

    await sync.testWarmColdPreviews();

    expect(sync.getLastMessagePreview('open'), isNull);
  });
}

class _CacheStorage extends MMKVStorage {
  _CacheStorage() : super.testConstructor();

  final Map<String, List<Map<String, dynamic>>> rows = {};
  final List<String> reads = [];
  void Function()? onRead;

  @override
  Future<String?> getSessionMessagesEncodedAsync(String sessionId) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>> getSessionMessagesAsync(
    String sessionId,
  ) async {
    reads.add(sessionId);
    onRead?.call();
    return rows[sessionId] ?? const [];
  }

  @override
  bool saveSessionMessagesEncoded(String sessionId, String encoded) => true;
}
