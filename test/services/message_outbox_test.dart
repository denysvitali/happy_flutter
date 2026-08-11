import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/at_rest_encryption_service.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/power_diagnostics_service.dart';

// ---------------------------------------------------------------------------
// Fake MMKVStorage for testing
// ---------------------------------------------------------------------------

class _FakeMMKVStorage extends MMKVStorage {
  _FakeMMKVStorage() : super.testConstructor();

  String? _outboxData;

  /// How many times the whole blob was re-encoded and written.
  int writeCount = 0;

  @override
  Future<String?> getOutboxEntries() async => _outboxData;

  @override
  Future<void> saveOutboxEntries(String json) async {
    writeCount++;
    _outboxData = json;
  }
}

class _BlockingMMKVStorage extends _FakeMMKVStorage {
  final saveStarted = Completer<void>();
  final allowSave = Completer<void>();

  @override
  Future<void> saveOutboxEntries(String json) async {
    if (!saveStarted.isCompleted) saveStarted.complete();
    await allowSave.future;
    await super.saveOutboxEntries(json);
  }
}

List<Map<String, dynamic>> _decodeStoredOutbox(_FakeMMKVStorage storage) {
  final protection = AtRestEncryptionService.memoryOnly(
    Uint8List.fromList(List<int>.generate(32, (index) => 32 - index)),
  );
  final plaintext = protection.unprotectString(
    storage._outboxData!,
    associatedData: 'message-outbox:v1',
  );
  return (jsonDecode(plaintext!) as List<dynamic>).cast<Map<String, dynamic>>();
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
          return null;
        },
      );

      final entry = _makeEntry();
      await outbox.add(entry);

      // Wait for debounce (100ms) to fire
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(outbox.contains(entry.localId), isTrue);
      expect(storage._outboxData, isNotNull);
      expect(
        storage._outboxData,
        startsWith(AtRestEncryptionService.envelopePrefix),
      );
      expect(storage._outboxData, isNot(contains(entry.localId)));
      expect(storage._outboxData, isNot(contains(entry.text)));
    });

    test('add does not complete before the durable write', () async {
      final blockingStorage = _BlockingMMKVStorage();
      final durableOutbox = MessageOutbox(storage: blockingStorage)
        ..configure(deliver: (entry) async => null);

      var completed = false;
      final addFuture = durableOutbox.add(_makeEntry()).then((_) {
        completed = true;
      });
      await blockingStorage.saveStarted.future;
      expect(completed, isFalse);

      blockingStorage.allowSave.complete();
      await addFuture;
      expect(completed, isTrue);
      durableOutbox.dispose();
    });

    test(
      'serializes delivery within a session but not across sessions',
      () async {
        final firstGate = Completer<void>();
        final secondStarted = Completer<void>();
        final otherStarted = Completer<void>();
        final order = <String>[];

        final first = outbox.serialize('session-a', () async {
          order.add('first');
          await firstGate.future;
        });
        final second = outbox.serialize('session-a', () async {
          order.add('second');
          secondStarted.complete();
        });
        final other = outbox.serialize('session-b', () async {
          order.add('other');
          otherStarted.complete();
        });

        await otherStarted.future;
        expect(secondStarted.isCompleted, isFalse);
        firstGate.complete();
        await Future.wait([first, second, other]);
        expect(order.indexOf('first'), lessThan(order.indexOf('second')));
      },
    );

    test(
      'legacy plaintext restore migrates without changing localId',
      () async {
        final entry = _makeEntry(localId: 'legacy-local');
        storage._outboxData = jsonEncode(<Map<String, dynamic>>[
          entry.toJson(),
        ]);
        outbox.configure(deliver: (e) async => OutboxDeliveryFailure.permanent);

        await outbox.restoreAndFlush();

        expect(outbox.contains('legacy-local'), isTrue);
        expect(
          storage._outboxData,
          startsWith(AtRestEncryptionService.envelopePrefix),
        );
        expect(storage._outboxData, isNot(contains('legacy-local')));
      },
    );

    test('encrypted cold-start restore preserves canonical localId', () async {
      outbox.configure(deliver: (e) async => OutboxDeliveryFailure.permanent);
      await outbox.add(_makeEntry(localId: 'stable-local'));
      await outbox.suspendAndFlush();
      outbox.dispose();

      final restored = MessageOutbox(storage: storage)
        ..configure(deliver: (e) async => OutboxDeliveryFailure.permanent);
      await restored.restoreAndFlush();

      expect(restored.contains('stable-local'), isTrue);
      expect(restored.entries.single.localId, 'stable-local');
      expect(storage._outboxData, isNot(contains('stable-local')));
      restored.dispose();
    });

    test('remove clears an entry and persists', () async {
      outbox.configure(deliver: (e) async => null);
      final entry = _makeEntry();
      await outbox.add(entry);

      await outbox.remove(entry.localId);

      // Wait for debounce (100ms) to fire
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(outbox.contains(entry.localId), isFalse);
      final saved = _decodeStoredOutbox(storage);
      expect(saved, isEmpty);
    });

    // ── Successful delivery ─────────────────────────────────────────────────

    test('successful delivery removes entry and fires sent status', () async {
      final statuses = <String>[];
      outbox.configure(
        deliver: (e) async => null,
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

    test(
      'failed delivery retries up to maxRetries then marks failed',
      () async {
        var attempts = 0;
        final statuses = <String>[];

        outbox.configure(
          deliver: (e) async {
            attempts++;
            return OutboxDeliveryFailure.permanent; // always fail
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
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    // ── Dead-letter ─────────────────────────────────────────────────────────

    test(
      'exhausted entry is dead-lettered, not destroyed',
      () async {
        final statuses = <String>[];
        final before = powerDiagnostics.snapshot();
        outbox.configure(
          deliver: (e) async => const OutboxDeliveryFailure(
            OutboxFailureClass.permanent,
            'session_gone',
          ),
          onStatusChanged: (_, __, status) => statuses.add(status),
        );

        await outbox.add(_makeEntry(localId: 'doomed'));
        await Future<void>.delayed(const Duration(milliseconds: 8000));

        expect(statuses.last, 'failed');
        expect(outbox.contains('doomed'), isFalse);

        // The encrypted payload survives in the dead-letter bucket, with
        // the failure class that chose the small permanent budget.
        final dead = outbox.deadEntry('doomed');
        expect(dead, isNotNull);
        expect(dead!.encryptedContent, 'enc-abc');
        expect(dead.dead, isTrue);
        expect(dead.failureClass, OutboxFailureClass.permanent);
        expect(dead.failureReason, 'session_gone');

        // …and it is persisted, so a cold start can still recover it.
        final saved = _decodeStoredOutbox(storage);
        expect(saved.single['localId'], 'doomed');
        expect(saved.single['dead'], isTrue);
        expect(saved.single['failureClass'], 'permanent');

        // Telemetry contract (audit 2026-08-03): EVERY failed attempt is
        // counted — the terminal one used to be skipped — and the
        // dead-letter itself gets its own counter.
        final after = powerDiagnostics.snapshot();
        expect(after.outboxFailures - before.outboxFailures, 3);
        expect(after.outboxDeadLetters - before.outboxDeadLetters, 1);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'restoreAndFlush rehydrates dead entries as failed rows',
      () async {
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
            return null;
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
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test(
      'reviveDead requeues with a fresh retry budget',
      () async {
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
            return null;
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
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    // ── Failure-class aware retry (audit 2026-08-03) ───────────────────────
    //
    // Four user messages were permanently lost during server brownouts
    // because the flat 3-retry / ~40 s budget was shorter than the outage.
    // Transient failures (timeout / network / 5xx / 429) now retry for
    // hours; permanent rejections (4xx / session gone) keep the small
    // budget; reconnect and foreground re-arm transient dead letters.

    test(
      'transient failures keep retrying past the old 3-attempt budget',
      () async {
        var attempts = 0;
        outbox.configure(
          deliver: (e) async {
            attempts++;
            return const OutboxDeliveryFailure(
              OutboxFailureClass.transient,
              'server_error',
            );
          },
        );
        // Marks the outbox initialized — resume() is a no-op without it,
        // exactly as in production where restoreAndFlush() always runs
        // after configure().
        await outbox.restoreAndFlush();

        await outbox.add(_makeEntry(localId: 'brownout'));
        // Drive the delivery state machine directly. The exponential delay is
        // a production scheduling concern; this contract only needs to prove
        // that transient failures survive the old three-attempt budget.
        for (var i = 0; i < 5; i++) {
          await outbox.testAttemptNow('brownout');
        }

        // Four failed attempts — one past the old flat budget that used to
        // dead-letter here — and the entry is still live, still retrying.
        expect(attempts, greaterThanOrEqualTo(4));
        expect(outbox.contains('brownout'), isTrue);
        expect(outbox.deadEntry('brownout'), isNull);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test(
      'throwing deliver is treated as transient, not dead-lettered',
      () async {
        var attempts = 0;
        outbox.configure(
          deliver: (e) async {
            attempts++;
            throw StateError('deliver blew up');
          },
        );
        await outbox.restoreAndFlush(); // resume() no-ops until initialized

        await outbox.add(_makeEntry(localId: 'throwy'));
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          outbox.resume();
        }

        expect(attempts, greaterThanOrEqualTo(4));
        expect(outbox.contains('throwy'), isTrue);
        expect(outbox.deadEntry('throwy'), isNull);
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );

    test('failure class and reason persist with the entry', () {
      final entry = _makeEntry(retryCount: 2).copyWith(
        failureClass: OutboxFailureClass.transient,
        failureReason: 'server_error',
      );
      final restored = OutboxEntry.fromJson(entry.toJson());
      expect(restored.failureClass, OutboxFailureClass.transient);
      expect(restored.failureReason, 'server_error');

      // Entries written by older builds carry no class — they must
      // round-trip as unclassified, which gets the loss-averse
      // transient budget.
      final legacy = OutboxEntry.fromJson(_makeEntry().toJson());
      expect(legacy.failureClass, isNull);
      expect(legacy.failureReason, isNull);
    });

    test(
      'reviveTransientDead re-arms transient + legacy, skips permanent',
      () async {
        final delivered = <OutboxEntry>[];
        outbox.configure(
          deliver: (e) async {
            delivered.add(e);
            return null;
          },
        );
        outbox.testInsertDead(
          _makeEntry(localId: 'dead-transient').copyWith(
            retryCount: 480,
            failureClass: OutboxFailureClass.transient,
            failureReason: 'server_error',
          ),
        );
        outbox.testInsertDead(
          _makeEntry(localId: 'dead-permanent').copyWith(
            retryCount: 3,
            failureClass: OutboxFailureClass.permanent,
            failureReason: 'session_gone',
          ),
        );
        // Legacy entry from an older build: no failure class at all.
        outbox.testInsertDead(
          _makeEntry(localId: 'dead-legacy').copyWith(retryCount: 3),
        );

        final revived = await outbox.reviveTransientDead();

        expect(revived, 2);
        expect(outbox.contains('dead-transient'), isTrue);
        expect(outbox.contains('dead-legacy'), isTrue);
        // Permanent rejections wait for the user's retry tap.
        expect(outbox.contains('dead-permanent'), isFalse);
        expect(outbox.deadEntry('dead-permanent'), isNotNull);

        // The revived entries deliver with the SAME localId and a fresh
        // budget — one tap's worth of message, never a duplicate.
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        expect(delivered.map((e) => e.localId).toSet(), {
          'dead-transient',
          'dead-legacy',
        });
        for (final e in delivered) {
          expect(e.retryCount, 0);
          expect(e.dead, isFalse);
        }
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test(
      'resume() re-arms transient dead entries (foreground recovery)',
      () async {
        outbox.configure(deliver: (e) async => null);
        await outbox.restoreAndFlush(); // marks the outbox initialized

        outbox.testInsertDead(
          _makeEntry(
            localId: 'brownout-dead',
          ).copyWith(failureClass: OutboxFailureClass.transient),
        );
        outbox.testInsertDead(
          _makeEntry(
            localId: 'gone-dead',
          ).copyWith(failureClass: OutboxFailureClass.permanent),
        );

        outbox.resume();

        expect(outbox.contains('brownout-dead'), isTrue);
        expect(outbox.deadEntry('gone-dead'), isNotNull);
      },
    );

    // ── Restore ─────────────────────────────────────────────────────────────

    test(
      'restoreAndFlush loads persisted entries and schedules retry',
      () async {
        // Pre-populate storage with one entry.
        final savedEntry = _makeEntry(localId: 'restored-1');
        storage._outboxData = jsonEncode([savedEntry.toJson()]);

        final delivered = <String>[];
        final outbox2 = MessageOutbox(storage: storage);
        outbox2.configure(
          deliver: (e) async {
            delivered.add(e.localId);
            return null;
          },
        );

        await outbox2.restoreAndFlush();

        expect(outbox2.contains('restored-1'), isTrue);

        // Wait for initial flush delay (2 s) plus backoff.
        await Future<void>.delayed(const Duration(milliseconds: 3500));

        expect(delivered, contains('restored-1'));
        outbox2.dispose();
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test('restoreAndFlush is idempotent', () async {
      outbox.configure(deliver: (e) async => null);
      await outbox.restoreAndFlush();
      await outbox.restoreAndFlush(); // second call should be a no-op
      // No exception thrown.
    });

    test(
      'restoreAndFlush delivers entries in queuedAt order',
      () async {
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
            return null;
          },
        );

        await outbox2.restoreAndFlush();

        // Wait for initial flush delay (2s) plus backoff for all three.
        await Future<void>.delayed(const Duration(milliseconds: 5000));

        // Entries should be delivered in queuedAt order: msg-1, msg-3, msg-2.
        expect(delivered, ['msg-1', 'msg-3', 'msg-2']);
        outbox2.dispose();
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    // ── Status callbacks ────────────────────────────────────────────────────

    test('add fires pending status immediately', () async {
      final statuses = <String>[];
      outbox.configure(
        deliver: (e) async => OutboxDeliveryFailure.permanent,
        onStatusChanged: (_, __, status) => statuses.add(status),
      );

      final entry = _makeEntry();
      await outbox.add(entry);

      expect(statuses, contains('pending'));
    });

    // ── Suspend ─────────────────────────────────────────────────────────────

    test(
      'suspendAndFlush preserves an already-durable pending entry',
      () async {
        outbox.configure(deliver: (e) async => OutboxDeliveryFailure.permanent);

        await outbox.add(_makeEntry(localId: 'flush-me'));
        // add() is the durability boundary: a successful return means the
        // encrypted entry is already recoverable if the process is killed.
        expect(storage._outboxData, isNotNull);
        expect(
          storage._outboxData,
          startsWith(AtRestEncryptionService.envelopePrefix),
        );

        await outbox.suspendAndFlush();

        expect(storage._outboxData, isNotNull);
        final saved = _decodeStoredOutbox(storage);
        expect(saved.single['localId'], 'flush-me');
        // Entry survives the suspend so resume() can retry it.
        expect(outbox.contains('flush-me'), isTrue);
      },
    );

    test(
      'suspendAndFlush skips the write when no persist is pending',
      () async {
        outbox.configure(deliver: (e) async => OutboxDeliveryFailure.permanent);

        await outbox.add(_makeEntry(localId: 'already-persisted'));
        // Let the debounced persist fire on its own.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(storage.writeCount, 1);

        // Nothing changed since, so the suspend has nothing to flush: the
        // completed debounce timer must not masquerade as pending work.
        await outbox.suspendAndFlush();
        await outbox.suspendAndFlush();

        expect(
          storage.writeCount,
          1,
          reason: 'an idle suspend must not re-encode the whole outbox blob',
        );
      },
    );

    test('suspend() preserves the durable snapshot without an await', () async {
      outbox.configure(deliver: (e) async => OutboxDeliveryFailure.permanent);

      await outbox.add(_makeEntry(localId: 'flush-sync'));
      expect(storage._outboxData, isNotNull);

      outbox.suspend();
      await Future<void>.delayed(Duration.zero);

      expect(storage._outboxData, isNotNull);
      final saved = _decodeStoredOutbox(storage);
      expect(saved.single['localId'], 'flush-sync');
    });

    // ── Dispose ─────────────────────────────────────────────────────────────

    test('dispose cancels pending timers', () async {
      var attempts = 0;
      outbox.configure(
        deliver: (e) async {
          attempts++;
          return OutboxDeliveryFailure.permanent;
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
