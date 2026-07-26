import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';

// ---------------------------------------------------------------------------
// Fake MMKVStorage for testing
// ---------------------------------------------------------------------------

class _FakeMMKVStorage extends MMKVStorage {
  _FakeMMKVStorage() : super.testConstructor();

  String? _outboxData;

  @override
  Future<String?> getOutboxEntries() async => _outboxData;

  @override
  Future<void> saveOutboxEntries(String json) async {
    _outboxData = json;
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

OutboxEntry _makeEntry({
  String localId = 'local-1',
  String sessionId = 'session-a',
  String text = 'hello',
  String encryptedContent = 'enc-abc',
  int retryCount = 0,
}) {
  return OutboxEntry(
    localId: localId,
    sessionId: sessionId,
    text: text,
    encryptedContent: encryptedContent,
    rawRecord: const {},
    queuedAt: 1000,
    retryCount: retryCount,
  );
}

void main() {
  group('OutboxEntry', () {
    test('toJson / fromJson round-trip', () {
      final entry = _makeEntry(retryCount: 2);
      final json = entry.toJson();
      final restored = OutboxEntry.fromJson(json);

      expect(restored.localId, entry.localId);
      expect(restored.sessionId, entry.sessionId);
      expect(restored.text, entry.text);
      expect(restored.encryptedContent, entry.encryptedContent);
      expect(restored.queuedAt, entry.queuedAt);
      expect(restored.retryCount, entry.retryCount);
    });

    test('copyWith updates retryCount', () {
      final entry = _makeEntry(retryCount: 0);
      final updated = entry.copyWith(retryCount: 3);
      expect(updated.retryCount, 3);
      expect(updated.localId, entry.localId);
    });
  });

  group('MessageOutbox', () {
    late _FakeMMKVStorage storage;
    late MessageOutbox outbox;

    setUp(() {
      storage = _FakeMMKVStorage();
      outbox = MessageOutbox(storage: storage);
    });

    tearDown(() {
      outbox.dispose();
    });

    // ── Basic add / remove ──────────────────────────────────────────────────

    test('add queues an entry and persists it', () async {
      final delivered = <String>[];
      outbox.configure(
        deliver: (e) async {
          delivered.add(e.localId);
          return true;
        },
      );

      final entry = _makeEntry();
      await outbox.add(entry);

      // Wait for debounce (100ms) to fire
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(outbox.contains(entry.localId), isTrue);
      expect(storage._outboxData, isNotNull);

      final saved =
          (jsonDecode(storage._outboxData!) as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(saved.length, 1);
      expect(saved.first['localId'], entry.localId);
    });

    test('remove clears an entry and persists', () async {
      outbox.configure(deliver: (e) async => true);
      final entry = _makeEntry();
      await outbox.add(entry);

      await outbox.remove(entry.localId);

      // Wait for debounce (100ms) to fire
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(outbox.contains(entry.localId), isFalse);
      final saved =
          (jsonDecode(storage._outboxData!) as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(saved, isEmpty);
    });

    // ── Successful delivery ─────────────────────────────────────────────────

    test('successful delivery removes entry and fires sent status', () async {
      final statuses = <String>[];
      outbox.configure(
        deliver: (e) async => true,
        onStatusChanged: (_, __, status) => statuses.add(status),
      );

      final entry = _makeEntry();
      await outbox.add(entry);

      // Wait for the immediate retry (initialDelay = backoff(0) = 1s+jitter).
      // Since we're using fake timers in tests, we pump the timer manually.
      await Future<void>.delayed(const Duration(milliseconds: 1300));

      expect(outbox.contains(entry.localId), isFalse);
      expect(statuses, containsAllInOrder(['pending', 'sent']));
    });

    // ── Failed delivery with retry ─────────────────────────────────────────

    test('failed delivery retries up to maxRetries then marks failed',
        () async {
      var attempts = 0;
      final statuses = <String>[];

      outbox.configure(
        deliver: (e) async {
          attempts++;
          return false; // always fail
        },
        onStatusChanged: (_, __, status) => statuses.add(status),
      );

      final entry = _makeEntry();
      await outbox.add(entry);

      // Drive all retries.  Each backoff is at least 1 s, capped at 30 s.
      // With maxRetries=3 and fake timers we pump enough time.
      // We use a real delay just under the max so this test is quick.
      //
      // attempt 1: after ~1 s (backoff(0))
      // attempt 2: after ~2 s (backoff(1))
      // attempt 3: after ~4 s (backoff(2))
      // Then marked failed.
      await Future<void>.delayed(const Duration(milliseconds: 8000));

      expect(attempts, greaterThanOrEqualTo(3));
      expect(outbox.contains(entry.localId), isFalse);
      expect(statuses.last, 'failed');
    }, timeout: const Timeout(Duration(seconds: 15)));

    // ── Dead-letter ─────────────────────────────────────────────────────────

    test('exhausted entry is dead-lettered, not destroyed', () async {
      final statuses = <String>[];
      outbox.configure(
        deliver: (e) async => false, // always fail
        onStatusChanged: (_, __, status) => statuses.add(status),
      );

      await outbox.add(_makeEntry(localId: 'doomed'));
      await Future<void>.delayed(const Duration(milliseconds: 8000));

      expect(statuses.last, 'failed');
      expect(outbox.contains('doomed'), isFalse);

      // The encrypted payload survives in the dead-letter bucket.
      final dead = outbox.deadEntry('doomed');
      expect(dead, isNotNull);
      expect(dead!.encryptedContent, 'enc-abc');
      expect(dead.dead, isTrue);

      // …and it is persisted, so a cold start can still recover it.
      final saved =
          (jsonDecode(storage._outboxData!) as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(saved.single['localId'], 'doomed');
      expect(saved.single['dead'], isTrue);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('restoreAndFlush rehydrates dead entries as failed rows', () async {
      final deadEntry = OutboxEntry(
        localId: 'dead-1',
        sessionId: 'session-a',
        text: 'lost message',
        encryptedContent: 'enc-dead',
        rawRecord: const {'role': 'user'},
        queuedAt: 1000,
        retryCount: 3,
        dead: true,
      );
      storage._outboxData = jsonEncode([deadEntry.toJson()]);

      final statuses = <String>[];
      final delivered = <String>[];
      final outbox2 = MessageOutbox(storage: storage);
      outbox2.configure(
        deliver: (e) async {
          delivered.add(e.localId);
          return true;
        },
        onStatusChanged: (_, __, status) => statuses.add(status),
      );

      await outbox2.restoreAndFlush();

      // Republished as 'failed' so the retry affordance renders again.
      expect(statuses, ['failed']);
      expect(outbox2.contains('dead-1'), isFalse);
      expect(outbox2.deadEntry('dead-1')?.encryptedContent, 'enc-dead');
      expect(outbox2.deadEntry('dead-1')?.rawRecord, {'role': 'user'});

      // Dead entries are never auto-retried.
      await Future<void>.delayed(const Duration(milliseconds: 3500));
      expect(delivered, isEmpty);
      outbox2.dispose();
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('reviveDead requeues with a fresh retry budget', () async {
      final deadEntry = OutboxEntry(
        localId: 'dead-2',
        sessionId: 'session-a',
        text: 'lost message',
        encryptedContent: 'enc-dead-2',
        rawRecord: const {},
        queuedAt: 1000,
        retryCount: 3,
        dead: true,
      );
      storage._outboxData = jsonEncode([deadEntry.toJson()]);

      final delivered = <OutboxEntry>[];
      final outbox2 = MessageOutbox(storage: storage);
      outbox2.configure(
        deliver: (e) async {
          delivered.add(e);
          return true;
        },
      );
      await outbox2.restoreAndFlush();

      expect(await outbox2.reviveDead('dead-2'), isTrue);
      expect(outbox2.deadEntry('dead-2'), isNull);
      expect(outbox2.contains('dead-2'), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(delivered.single.localId, 'dead-2');
      expect(delivered.single.retryCount, 0);
      expect(delivered.single.dead, isFalse);
      outbox2.dispose();
    }, timeout: const Timeout(Duration(seconds: 15)));

    // ── Restore ─────────────────────────────────────────────────────────────

    test('restoreAndFlush loads persisted entries and schedules retry',
        () async {
      // Pre-populate storage with one entry.
      final savedEntry = _makeEntry(localId: 'restored-1');
      storage._outboxData = jsonEncode([savedEntry.toJson()]);

      final delivered = <String>[];
      final outbox2 = MessageOutbox(storage: storage);
      outbox2.configure(
        deliver: (e) async {
          delivered.add(e.localId);
          return true;
        },
      );

      await outbox2.restoreAndFlush();

      expect(outbox2.contains('restored-1'), isTrue);

      // Wait for initial flush delay (2 s) plus backoff.
      await Future<void>.delayed(const Duration(milliseconds: 3500));

      expect(delivered, contains('restored-1'));
      outbox2.dispose();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('restoreAndFlush is idempotent', () async {
      outbox.configure(deliver: (e) async => true);
      await outbox.restoreAndFlush();
      await outbox.restoreAndFlush(); // second call should be a no-op
      // No exception thrown.
    });

    test('restoreAndFlush delivers entries in queuedAt order', () async {
      // Pre-populate storage with multiple entries with different queuedAt.
      final entry1 = OutboxEntry(
        localId: 'msg-1',
        sessionId: 'session-a',
        text: 'first',
        encryptedContent: 'enc-1',
        rawRecord: const {},
        queuedAt: 1000,
      );
      final entry2 = OutboxEntry(
        localId: 'msg-2',
        sessionId: 'session-a',
        text: 'second',
        encryptedContent: 'enc-2',
        rawRecord: const {},
        queuedAt: 2000,
      );
      final entry3 = OutboxEntry(
        localId: 'msg-3',
        sessionId: 'session-a',
        text: 'third',
        encryptedContent: 'enc-3',
        rawRecord: const {},
        queuedAt: 1500,
      );
      storage._outboxData = jsonEncode([
        entry1.toJson(),
        entry2.toJson(),
        entry3.toJson(),
      ]);

      final delivered = <String>[];
      final outbox2 = MessageOutbox(storage: storage);
      outbox2.configure(
        deliver: (e) async {
          delivered.add(e.localId);
          return true;
        },
      );

      await outbox2.restoreAndFlush();

      // Wait for initial flush delay (2s) plus backoff for all three.
      await Future<void>.delayed(const Duration(milliseconds: 5000));

      // Entries should be delivered in queuedAt order: msg-1, msg-3, msg-2.
      expect(delivered, ['msg-1', 'msg-3', 'msg-2']);
      outbox2.dispose();
    }, timeout: const Timeout(Duration(seconds: 15)));

    // ── Status callbacks ────────────────────────────────────────────────────

    test('add fires pending status immediately', () async {
      final statuses = <String>[];
      outbox.configure(
        deliver: (e) async => false,
        onStatusChanged: (_, __, status) => statuses.add(status),
      );

      final entry = _makeEntry();
      await outbox.add(entry);

      expect(statuses, contains('pending'));
    });

    // ── Suspend ─────────────────────────────────────────────────────────────

    test('suspendAndFlush persists pending entries before cancelling timers',
        () async {
      outbox.configure(deliver: (e) async => false);

      await outbox.add(_makeEntry(localId: 'flush-me'));
      // The persist is debounced 100ms — nothing on disk yet.
      expect(storage._outboxData, isNull);

      await outbox.suspendAndFlush();

      expect(storage._outboxData, isNotNull);
      final saved =
          (jsonDecode(storage._outboxData!) as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(saved.single['localId'], 'flush-me');
      // Entry survives the suspend so resume() can retry it.
      expect(outbox.contains('flush-me'), isTrue);
    });

    test('suspend() flushes the debounced persist without an await', () async {
      outbox.configure(deliver: (e) async => false);

      await outbox.add(_makeEntry(localId: 'flush-sync'));
      expect(storage._outboxData, isNull);

      outbox.suspend();
      await Future<void>.delayed(Duration.zero);

      expect(storage._outboxData, isNotNull);
      final saved =
          (jsonDecode(storage._outboxData!) as List<dynamic>)
              .cast<Map<String, dynamic>>();
      expect(saved.single['localId'], 'flush-sync');
    });

    // ── Dispose ─────────────────────────────────────────────────────────────

    test('dispose cancels pending timers', () async {
      var attempts = 0;
      outbox.configure(
        deliver: (e) async {
          attempts++;
          return false;
        },
      );

      await outbox.add(_makeEntry());
      outbox.dispose();

      // After dispose no more retries should be scheduled.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(attempts, lessThanOrEqualTo(1)); // at most the initial attempt
    });

    // ── No-op without configure ─────────────────────────────────────────────

    test('add without configure still persists and does not throw', () async {
      // configure() not called.
      final entry = _makeEntry();
      await expectLater(outbox.add(entry), completes);
      expect(outbox.contains(entry.localId), isTrue);
    });
  });
}
