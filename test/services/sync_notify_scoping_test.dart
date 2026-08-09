// Contract tests for the perf P0 "sync notify storm" fix.
//
// Pins two invariants:
//   1. Domain-scoped emits reach onDomainChanged subscribers but NOT
//      the global onDataChanged firehose. The firehose is reserved
//      for the truly-everything (domains == null) case.
//   2. dataChangeCounter still ticks for scoped emits so any
//      counter-based dedup paths see progress.
//
// See: lib/core/services/_sync_socket.dart `_notifyDataChanged`,
//      `_flushDataChanged`.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/message_cache_service.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

class _CountingMMKVStorage extends MMKVStorage {
  _CountingMMKVStorage() : super.testConstructor();

  int saveCount = 0;
  final Map<String, List<Map<String, dynamic>>> _last = {};

  @override
  bool saveSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    saveCount++;
    _last[sessionId] = [for (final m in messages) Map<String, dynamic>.from(m)];
    return true;
  }

  @override
  bool saveSessionMessagesEncoded(String sessionId, String encodedMessages) {
    final decoded = (jsonDecode(encodedMessages) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return saveSessionMessages(sessionId, decoded);
  }

  @override
  List<Map<String, dynamic>> getSessionMessages(String sessionId) =>
      _last[sessionId] ?? const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getSessionMessagesAsync(
    String sessionId,
  ) async => getSessionMessages(sessionId);

  @override
  void clearSessionMessages(String sessionId) {
    _last.remove(sessionId);
  }

  @override
  List<String> getCachedSessionIds() => _last.keys.toList();
}

void main() {
  group('Sync notify scoping (perf P0)', () {
    late Sync instance;

    setUp(() {
      instance = createTestSync();
    });

    Session makeSession(String id) {
      const now = 1700000000000;
      return Session(
        id: id,
        seq: 1,
        createdAt: now,
        updatedAt: now,
        active: true,
        activeAt: now,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: 'offline',
        lastSeq: 0,
      );
    }

    test('null (truly-everything) notify wakes BOTH global and domain '
        'streams', () async {
      var globalEmits = 0;
      final domains = <SyncDomain>{};
      final globalSub = instance.onDataChanged.listen((_) => globalEmits++);
      final domainSub = instance.onDomainChanged.listen(domains.add);

      instance.testNotifyDataChanged(); // passes null
      // Broadcast streams deliver on microtasks; let the queue drain.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(
        globalEmits,
        greaterThanOrEqualTo(1),
        reason: 'truly-everything notifications must wake the firehose',
      );
      expect(
        domains,
        containsAll(SyncDomain.values),
        reason: 'truly-everything notifications must wake every domain',
      );

      await globalSub.cancel();
      await domainSub.cancel();
    });

    test('domain-scoped emit reaches onDomainChanged but NOT '
        'global onDataChanged', () async {
      const sessionId = 'sess-scoped';
      instance.testSessions[sessionId] = makeSession(sessionId);

      var globalEmits = 0;
      var sessionsDomainEmits = 0;
      final globalSub = instance.onDataChanged.listen((_) => globalEmits++);
      final domainSub = instance.onDomainChanged
          .where((d) => d == SyncDomain.sessions)
          .listen((_) => sessionsDomainEmits++);

      // Triggers _notifyDataChanged({SyncDomain.sessions}).
      instance.handleEphemeralUpdate({
        't': 'activity',
        'id': sessionId,
        'thinking': true,
        'active': true,
      });

      // Drain beyond any debounce window.
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(
        sessionsDomainEmits,
        greaterThanOrEqualTo(1),
        reason: 'onDomainChanged(sessions) must fire',
      );
      expect(
        globalEmits,
        0,
        reason:
            'scoped emit must NOT wake the global onDataChanged firehose '
            '— that would defeat domain scoping',
      );

      await globalSub.cancel();
      await domainSub.cancel();
    });

    test('dataChangeCounter ticks for scoped emits even though the '
        'global stream stays silent', () async {
      const sessionId = 'sess-counter';
      instance.testSessions[sessionId] = makeSession(sessionId);

      final before = instance.dataChangeCounter;

      instance.handleEphemeralUpdate({
        't': 'activity',
        'id': sessionId,
        'thinking': true,
        'active': true,
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        instance.dataChangeCounter,
        greaterThan(before),
        reason:
            'counter-based dedup paths (loadFromSync skip logic) must '
            'still see progress on scoped emits',
      );
    });

    test('_scheduleSaveMessages enforces a max-delay ceiling regardless '
        'of UI notify frequency', () async {
      const sessionId = 'sess-save-cap';
      final storage = _CountingMMKVStorage();
      MessageCacheService().debugSetStorage = storage;
      addTearDown(MessageCacheService().debugResetStorage);

      instance.testSetSessionMessages(sessionId, [
        {'id': 'm-1', 'seq': 1, 'role': 'user', 'content': 'hi'},
      ]);

      // Continuously reschedule the save every 100ms — well below
      // the 2000ms debounce.  Without the max-delay ceiling, the
      // 2s timer would reset on every call and the save would
      // never fire while we keep tapping it.
      instance.testScheduleSaveMessages(sessionId);
      expect(instance.testHasPendingSaveTimer(sessionId), isTrue);

      for (var i = 0; i < 165; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        // Append a message each tick to simulate streaming tokens.
        instance.testSetSessionMessages(sessionId, [
          for (var k = 0; k <= i; k++)
            {'id': 'm-$k', 'seq': k + 1, 'role': 'user', 'content': 't$k'},
        ]);
        instance.testScheduleSaveMessages(sessionId);
      }

      // After ~16.5s of constant rescheduling the cache MUST have been
      // flushed at least once because of the 15s ceiling.
      expect(
        storage.saveCount,
        greaterThanOrEqualTo(1),
        reason:
            '_scheduleSaveMessages must fire under sustained streaming '
            'thanks to the max-delay ceiling; otherwise the MMKV cache '
            'would never persist during long agent runs',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test(
      '_flushPendingMessageSaves clears pending state for backgrounding',
      () async {
        const sessionId = 'sess-flush';
        final storage = _CountingMMKVStorage();
        MessageCacheService().debugSetStorage = storage;
        addTearDown(MessageCacheService().debugResetStorage);

        instance.testSetSessionMessages(sessionId, [
          {'id': 'm-1', 'seq': 1, 'role': 'user', 'content': 'flush'},
        ]);
        instance.testScheduleSaveMessages(sessionId);
        expect(instance.testHasPendingSaveTimer(sessionId), isTrue);

        instance.testFlushPendingMessageSaves();

        expect(instance.testHasPendingSaveTimer(sessionId), isFalse);
        expect(
          storage.saveCount,
          greaterThanOrEqualTo(1),
          reason: 'flush must persist before clearing the timer',
        );
      },
    );

    test(
      'suspend() flushes pending message saves instead of dropping them',
      () async {
        // Regression: suspend() cancelled and CLEARED
        // _saveMsgsDebounceTimers before calling
        // _flushPendingMessageSaves(), which iterates exactly that map.
        // The flush therefore early-returned on an empty map and every
        // un-persisted message tail was silently lost on background.
        const sessionId = 'sess-suspend-flush';
        final storage = _CountingMMKVStorage();
        MessageCacheService().debugSetStorage = storage;
        addTearDown(MessageCacheService().debugResetStorage);
        addTearDown(() => MessageCacheService().clearMessages(sessionId));
        addTearDown(() => InvalidateSync.isBackgrounded = false);

        // suspend() returns immediately unless the engine is initialized, and
        // createTestSync() leaves the flag false. Without this the whole
        // lifecycle path is skipped and the test passes or fails for reasons
        // that have nothing to do with the flush it is pinning.
        instance.isInitialized = true;
        addTearDown(() => instance.isInitialized = false);

        instance.testSetSessionMessages(sessionId, [
          {'id': 'm-1', 'seq': 1, 'role': 'user', 'content': 'suspend me'},
        ]);
        instance.testScheduleSaveMessages(sessionId);
        expect(instance.testHasPendingSaveTimer(sessionId), isTrue);

        instance.suspend();

        expect(
          storage.saveCount,
          greaterThanOrEqualTo(1),
          reason:
              'suspend() must persist the pending cache window before the '
              'OS can kill the backgrounded process',
        );
        expect(
          MessageCacheService().getMessages(sessionId).single['content'],
          'suspend me',
        );
        expect(instance.testHasPendingSaveTimer(sessionId), isFalse);
      },
    );

    test('domain-scoped emits across multiple sessions only wake the '
        'sessions domain subscriber', () async {
      var sessionsDomainEmits = 0;
      var messagesDomainEmits = 0;
      var globalEmits = 0;
      final globalSub = instance.onDataChanged.listen((_) => globalEmits++);
      final sessionsSub = instance.onDomainChanged
          .where((d) => d == SyncDomain.sessions)
          .listen((_) => sessionsDomainEmits++);
      final messagesSub = instance.onDomainChanged
          .where((d) => d == SyncDomain.messages)
          .listen((_) => messagesDomainEmits++);

      for (var i = 0; i < 5; i++) {
        final id = 'sess-multi-$i';
        instance.testSessions[id] = makeSession(id);
        instance.handleEphemeralUpdate({
          't': 'activity',
          'id': id,
          'thinking': i.isEven,
          'active': true,
        });
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(sessionsDomainEmits, greaterThanOrEqualTo(1));
      expect(
        messagesDomainEmits,
        0,
        reason:
            'a sessions-only update must not wake messages-domain '
            'subscribers',
      );
      expect(
        globalEmits,
        0,
        reason:
            '5 scoped emits must produce 0 firehose wakeups; this is '
            'the core perf win',
      );

      await globalSub.cancel();
      await sessionsSub.cancel();
      await messagesSub.cancel();
    });
  });
}
