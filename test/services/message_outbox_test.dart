import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
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
  bool failWrites = false;
  bool failReads = false;

  @override
  Future<String?> getOutboxEntries() async {
    if (failReads) throw StateError('disk read failed');
    return _outboxData;
  }

  @override
  Future<void> saveOutboxEntries(String json) async {
    writeCount++;
    if (failWrites) throw StateError('disk write failed');
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

class _BlockingReadMMKVStorage extends _FakeMMKVStorage {
  final readStarted = Completer<void>();
  final allowRead = Completer<void>();
  bool blockReads = false;

  @override
  Future<String?> getOutboxEntries() async {
    final snapshot = await super.getOutboxEntries();
    if (blockReads) {
      if (!readStarted.isCompleted) readStarted.complete();
      await allowRead.future;
    }
    return snapshot;
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

/// Runs [body] under [FakeAsync] so the outbox's real 1 s → 30 s backoff
/// timers elapse virtually instead of on the wall clock.
///
/// The body awaits the outbox's microtask-only work as usual and calls
/// `async.elapse(...)` wherever it used to sleep on a real
/// `Future.delayed`. The production delays are untouched; only the clock
/// they run against is faked.
@isTest
void _runFakeAsyncTest(
  String description,
  Future<void> Function(FakeAsync async) body,
) {
  test(description, () {
    fakeAsync((async) {
      var completed = false;
      Object? failure;
      StackTrace? failureTrace;
      body(async).then(
        (_) => completed = true,
        onError: (Object error, StackTrace trace) {
          failure = error;
          failureTrace = trace;
        },
      );
      async.flushMicrotasks();
      if (failure != null) {
        Error.throwWithStackTrace(failure!, failureTrace!);
      }
      expect(
        completed,
        isTrue,
        reason:
            'test body did not complete under FakeAsync — it awaited '
            'something that is not driven by microtasks or async.elapse()',
      );
    });
  });
}

void main() {
  test(
    'owner scope is stable, normalized and never stores URL credentials',
    () {
      final first = MessageOutbox.ownerScope(
        accountId: 'derived-id',
        serverUrl: 'https://user:password@EXAMPLE.com/',
      );
      final second = MessageOutbox.ownerScope(
        accountId: 'derived-id',
        serverUrl: 'https://example.com',
      );
      expect(first, second);
      expect(first, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(first, isNot(contains('password')));
    },
  );

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

    @isTest
    void outboxFakeTest(
      String description,
      Future<void> Function(FakeAsync async) body,
    ) {
      _runFakeAsyncTest(description, (async) {
        // Persistence futures must belong to the same zone as the fake clock.
        outbox.dispose();
        outbox = MessageOutbox(storage: storage);
        return body(async);
      });
    }

    outboxFakeTest(
      'readiness deferral waits for an explicit readiness wakeup',
      (async) async {
        var attempts = 0;
        final deliveredIds = <String>[];
        outbox.configure(
          deliver: (entry) async {
            attempts++;
            deliveredIds.add(entry.localId);
            if (attempts == 1) {
              return const OutboxDeliveryFailure.readiness('agent_starting');
            }
            return null;
          },
        );
        outbox.testInsertPending(_makeEntry(retryCount: 479));

        await outbox.testAttemptNow('local-1');

        expect(outbox.entries.single.retryCount, 479);
        expect(outbox.entries.single.failureReason, 'agent_starting');
        expect(outbox.deadEntries, isEmpty);

        // Readiness deferral must not create a timer-driven retry storm.
        async.elapse(const Duration(seconds: 30));
        expect(attempts, 1);

        outbox.notifySessionReady('session-a');
        outbox.notifySessionReady('session-a');
        async.elapse(Duration.zero);

        expect(attempts, 2);
        expect(deliveredIds, ['local-1', 'local-1']);
        expect(outbox.entries, isEmpty);
      },
    );

    test('readiness deferral does not consume the retry budget', () async {
      outbox.configure(
        deliver: (entry) async =>
            const OutboxDeliveryFailure.readiness('agent_starting'),
      );
      outbox.testInsertPending(_makeEntry(retryCount: 479));

      await outbox.testAttemptNow('local-1');

      expect(outbox.entries.single.retryCount, 479);
      expect(outbox.entries.single.failureReason, 'agent_starting');
      expect(outbox.deadEntries, isEmpty);
    });

    test('terminal session fails readiness-deferred sends without losing '
        'their localIds or payloads', () async {
      final statuses = <String, String>{};
      var attempts = 0;
      outbox.configure(
        deliver: (_) async {
          attempts++;
          return const OutboxDeliveryFailure.readiness('agent_starting');
        },
        onStatusChanged: (_, localId, status) => statuses[localId] = status,
      );
      outbox.testInsertPending(_makeEntry(localId: 'first'));
      outbox.testInsertPending(_makeEntry(localId: 'second'));
      outbox.testInsertPending(
        _makeEntry(localId: 'other', sessionId: 'session-b'),
      );
      await outbox.testAttemptNow('first');
      await outbox.testAttemptNow('second');
      await outbox.testAttemptNow('other');

      outbox.notifySessionUnavailable('session-a');

      expect(attempts, 2);
      expect(outbox.readinessDeferredSessionIds, ['session-b']);
      expect(outbox.entries.map((entry) => entry.localId), ['other']);
      expect(outbox.deadEntries.map((entry) => entry.localId).toSet(), {
        'first',
        'second',
      });
      for (final entry in outbox.deadEntries) {
        expect(entry.failureClass, OutboxFailureClass.permanent);
        expect(entry.failureReason, 'session_gone');
        expect(entry.encryptedContent, 'enc-abc');
        expect(entry.retryCount, 0);
        expect(statuses[entry.localId], 'failed');
      }
      expect(statuses['other'], 'pending');
    });

    test(
      'account and server switches retain foreign buckets without attempts',
      () async {
        final scopeA = MessageOutbox.ownerScope(
          accountId: 'account-a',
          serverUrl: 'https://one.example',
        );
        final scopeB = MessageOutbox.ownerScope(
          accountId: 'account-b',
          serverUrl: 'https://one.example',
        );
        final scopeOtherServer = MessageOutbox.ownerScope(
          accountId: 'account-a',
          serverUrl: 'https://two.example',
        );
        final attempts = <String>[];
        Future<OutboxDeliveryFailure?> deliver(OutboxEntry entry) async {
          attempts.add(entry.localId);
          return OutboxDeliveryFailure.transient;
        }

        outbox.configure(ownerScope: scopeA, deliver: deliver);
        await outbox.restoreAndFlush();
        await outbox.add(_makeEntry(localId: 'a', retryCount: 7));
        outbox.dispose();
        for (final scope in [scopeB, scopeOtherServer]) {
          outbox.configure(ownerScope: scope, deliver: deliver);
          await outbox.restoreAndFlush();
          expect(outbox.entries, isEmpty);
          await outbox.add(_makeEntry(localId: scope));
          await outbox.remove(scope);
          outbox.dispose();
        }
        outbox.configure(ownerScope: scopeA, deliver: deliver);
        await outbox.restoreAndFlush();
        expect(attempts, isEmpty);
        expect(outbox.entries.single.localId, 'a');
        expect(outbox.entries.single.retryCount, 7);
        expect(outbox.entries.single.encryptedContent, 'enc-abc');
      },
    );

    test('scoped restart retains explicit retry reservation order', () async {
      outbox.configure(ownerScope: 'a', deliver: (_) async => null);
      final older = _makeEntry(localId: 'older');
      outbox.testInsertDead(older);
      await outbox.add(
        OutboxEntry(
          localId: 'newer',
          sessionId: 'session-a',
          text: 'continue',
          encryptedContent: 'new-ciphertext',
          rawRecord: const {},
          queuedAt: 2000,
        ),
      );
      await outbox.reviveDead('older');
      outbox.dispose();
      outbox.configure(ownerScope: 'a', deliver: (_) async => null);
      await outbox.restoreAndFlush();
      expect(outbox.entries.map((entry) => entry.localId), ['newer', 'older']);
    });

    test(
      'scoped add waits for single-flight restore before replacing bucket',
      () async {
        final blocking = _BlockingReadMMKVStorage();
        final seed = MessageOutbox(storage: blocking)
          ..configure(ownerScope: 'a', deliver: (_) async => null);
        await seed.add(_makeEntry(localId: 'first'));
        seed.dispose();
        final scoped = MessageOutbox(storage: blocking)
          ..configure(ownerScope: 'a', deliver: (_) async => null);
        blocking.blockReads = true;
        final restore = scoped.restoreAndFlush();
        await blocking.readStarted.future;
        final sameRestore = scoped.restoreAndFlush();
        expect(identical(restore, sameRestore), isTrue);
        final add = scoped.add(_makeEntry(localId: 'second'));
        blocking.allowRead.complete();
        await Future.wait([restore, sameRestore, add]);
        expect(scoped.entries.map((entry) => entry.localId), [
          'first',
          'second',
        ]);
        scoped.dispose();
      },
    );

    test('account restore drains old in-flight durable writes', () async {
      final blocking = _BlockingMMKVStorage();
      final scoped = MessageOutbox(storage: blocking);
      scoped.configure(ownerScope: 'a', deliver: (_) async => null);
      final save = scoped.add(_makeEntry(localId: 'a-pending'));
      await blocking.saveStarted.future;
      scoped.dispose();
      scoped.configure(ownerScope: 'b', deliver: (_) async => null);
      final restore = scoped.restoreAndFlush();
      blocking.allowSave.complete();
      await Future.wait([save, restore]);
      expect(scoped.entries, isEmpty);
      await scoped.add(_makeEntry(localId: 'b-pending'));
      scoped.dispose();
      scoped.configure(ownerScope: 'a', deliver: (_) async => null);
      await scoped.restoreAndFlush();
      expect(scoped.entries.single.localId, 'a-pending');
      scoped.dispose();
    });

    test('malformed foreign bucket does not prevent owned recovery', () async {
      final protection = AtRestEncryptionService.memoryOnly(
        Uint8List.fromList(List<int>.generate(32, (index) => 32 - index)),
      );
      storage._outboxData = protection.protectString(
        jsonEncode({
          'version': 2,
          'buckets': {
            'selected': [_makeEntry(localId: 'owned').toJson()],
            'foreign': {'opaque': 'invalid bucket'},
          },
        }),
        associatedData: 'message-outbox:v1',
      );
      outbox.configure(ownerScope: 'selected', deliver: (_) async => null);
      await outbox.restoreAndFlush();
      expect(outbox.entries.single.localId, 'owned');
      await outbox.remove('owned');
      final plaintext = protection.unprotectString(
        storage._outboxData!,
        associatedData: 'message-outbox:v1',
      );
      final envelope = jsonDecode(plaintext!) as Map<String, dynamic>;
      expect((envelope['buckets'] as Map<String, dynamic>)['foreign'], {
        'opaque': 'invalid bucket',
      });
    });

    test('malformed selected bucket never deletes a foreign bucket', () async {
      final protection = AtRestEncryptionService.memoryOnly(
        Uint8List.fromList(List<int>.generate(32, (index) => 32 - index)),
      );
      storage._outboxData = protection.protectString(
        jsonEncode({
          'version': 2,
          'buckets': {
            'selected': [
              {'localId': 'broken'},
            ],
            'foreign': [_makeEntry(localId: 'foreign').toJson()],
          },
        }),
        associatedData: 'message-outbox:v1',
      );
      final before = storage._outboxData;
      outbox.configure(ownerScope: 'selected', deliver: (_) async => null);
      await outbox.restoreAndFlush();
      expect(storage._outboxData, before);
      expect(outbox.entries, isEmpty);
    });

    test('scoped restore never claims unowned legacy sends', () async {
      storage._outboxData = jsonEncode([_makeEntry().toJson()]);
      outbox.configure(
        ownerScope: MessageOutbox.ownerScope(
          accountId: 'account-b',
          serverUrl: 'https://one.example',
        ),
        deliver: (_) async => fail('foreign send attempted'),
      );
      await outbox.restoreAndFlush();
      expect(outbox.entries, isEmpty);
      expect(outbox.unownedEntryCount, 1);
      await outbox.add(_makeEntry(localId: 'owned'));
      expect(outbox.entries.single.localId, 'owned');
      expect(storage._outboxData, isNot(contains('hello')));
    });

    outboxFakeTest('failed head blocks follow-up until retry succeeds', (
      async,
    ) async {
      final successes = <String>[];
      var firstAttempts = 0;
      outbox.configure(
        deliver: (entry) async {
          if (entry.localId == 'first' && ++firstAttempts == 1) {
            return OutboxDeliveryFailure.transient;
          }
          successes.add(entry.localId);
          return null;
        },
      );
      await outbox.add(_makeEntry(localId: 'first', text: 'continue'));
      await outbox.add(_makeEntry(localId: 'second', text: 'continue'));
      await outbox.testAttemptNow('first');
      await outbox.testAttemptNow('second');
      expect(successes, isEmpty);
      expect(outbox.entries.first.retryCount, 1);
      await outbox.testAttemptNow('first');
      async.elapse(Duration.zero);
      expect(successes, ['first', 'second']);
      expect(outbox.entries, isEmpty);
    });

    outboxFakeTest('follow-up timer cannot bypass repeated head backoff', (
      async,
    ) async {
      final successes = <String>[];
      var attempts = 0;
      outbox.configure(
        deliver: (entry) async {
          if (entry.localId == 'first' && ++attempts <= 2) {
            return OutboxDeliveryFailure.transient;
          }
          successes.add(entry.localId);
          return null;
        },
      );
      await outbox.add(_makeEntry(localId: 'first'));
      await outbox.testAttemptNow('first');
      await outbox.add(_makeEntry(localId: 'second'));
      await outbox.testAttemptNow('first');
      // Follow-up's shorter initial timer expires while head backs off.
      async.elapse(const Duration(milliseconds: 1300));
      expect(successes, isEmpty);
      expect(attempts, 2);
      await outbox.testAttemptNow('first');
      async.elapse(Duration.zero);
      expect(successes, ['first', 'second']);
    });

    outboxFakeTest(
      'dead-lettered head releases follow-up without losing payload',
      (async) async {
        final successes = <String>[];
        outbox.configure(
          deliver: (entry) async {
            if (entry.localId == 'first')
              return OutboxDeliveryFailure.permanent;
            successes.add(entry.localId);
            return null;
          },
        );
        await outbox.add(_makeEntry(localId: 'first', retryCount: 2));
        await outbox.add(_makeEntry(localId: 'second'));
        await outbox.testAttemptNow('first');
        async.elapse(Duration.zero);
        expect(successes, ['second']);
        expect(outbox.deadEntries.single.localId, 'first');
        expect(outbox.deadEntries.single.encryptedContent, 'enc-abc');
      },
    );

    // ── Basic add / remove ──────────────────────────────────────────────────

    outboxFakeTest('add queues an entry and persists it', (async) async {
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
      async.elapse(const Duration(milliseconds: 150));

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

    outboxFakeTest('remove clears an entry and persists', (async) async {
      outbox.configure(deliver: (e) async => null);
      final entry = _makeEntry();
      await outbox.add(entry);

      await outbox.remove(entry.localId);

      // Wait for debounce (100ms) to fire
      async.elapse(const Duration(milliseconds: 150));

      expect(outbox.contains(entry.localId), isFalse);
      final saved = _decodeStoredOutbox(storage);
      expect(saved, isEmpty);
    });

    outboxFakeTest('removing a deferred send clears its readiness wait', (
      async,
    ) async {
      outbox.configure(
        deliver: (_) async =>
            const OutboxDeliveryFailure.readiness('agent_starting'),
      );
      outbox.testInsertPending(_makeEntry());
      await outbox.testAttemptNow('local-1');
      expect(outbox.readinessDeferredSessionIds, ['session-a']);

      await outbox.remove('local-1');

      expect(outbox.entries, isEmpty);
      expect(outbox.readinessDeferredSessionIds, isEmpty);
      async.elapse(const Duration(seconds: 2));
    });

    // ── Successful delivery ─────────────────────────────────────────────────

    outboxFakeTest('successful delivery removes entry and fires sent status', (
      async,
    ) async {
      final statuses = <String>[];
      outbox.configure(
        deliver: (e) async => null,
        onStatusChanged: (_, __, status) => statuses.add(status),
      );

      final entry = _makeEntry();
      await outbox.add(entry);

      // Wait for the immediate retry (initialDelay = backoff(0) = 1s+jitter).
      // Since we're using fake timers in tests, we pump the timer manually.
      async.elapse(const Duration(milliseconds: 1300));

      expect(outbox.contains(entry.localId), isFalse);
      expect(statuses, containsAllInOrder(['pending', 'sent']));
    });

    // ── Failed delivery with retry ─────────────────────────────────────────

    outboxFakeTest(
      'failed delivery retries up to maxRetries then marks failed',
      (async) async {
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
        async.elapse(const Duration(milliseconds: 8000));

        expect(attempts, greaterThanOrEqualTo(3));
        expect(outbox.contains(entry.localId), isFalse);
        expect(statuses.last, 'failed');
      },
    );

    // ── Dead-letter ─────────────────────────────────────────────────────────

    outboxFakeTest('exhausted entry is dead-lettered, not destroyed', (
      async,
    ) async {
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
      async.elapse(const Duration(milliseconds: 8000));

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
    });

    outboxFakeTest('restoreAndFlush rehydrates dead entries as failed rows', (
      async,
    ) async {
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
      async.elapse(const Duration(milliseconds: 3500));
      expect(delivered, isEmpty);
      outbox2.dispose();
    });

    for (final automatic in [false, true]) {
      test(
        'failed revival retains retry identity (automatic=$automatic)',
        () async {
          final entry = _makeEntry(
            retryCount: 3,
          ).copyWith(dead: true, failureClass: OutboxFailureClass.transient);
          outbox.testInsertDead(entry);
          storage.failWrites = true;

          await expectLater(
            automatic
                ? outbox.reviveTransientDead()
                : outbox.reviveDead(entry.localId),
            throwsStateError,
          );

          expect(outbox.entries, isEmpty);
          expect(outbox.deadEntries.single.localId, entry.localId);
          expect(outbox.deadEntries.single.retryCount, 3);
          expect(
            outbox.deadEntries.single.encryptedContent,
            entry.encryptedContent,
          );

          storage.failWrites = false;
          expect(await outbox.reviveDead(entry.localId), isTrue);
          expect(outbox.deadEntries, isEmpty);
          expect(outbox.entries.single.localId, entry.localId);
          expect(_decodeStoredOutbox(storage).single['localId'], entry.localId);
        },
      );
    }

    outboxFakeTest('reviveDead requeues with a fresh retry budget', (
      async,
    ) async {
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

      async.elapse(const Duration(milliseconds: 1500));
      expect(delivered.single.localId, 'dead-2');
      expect(delivered.single.retryCount, 0);
      expect(delivered.single.dead, isFalse);
      outbox2.dispose();
    });

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

    outboxFakeTest(
      'throwing deliver is treated as transient, not dead-lettered',
      (async) async {
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
          async.elapse(const Duration(milliseconds: 1500));
          outbox.resume();
        }

        expect(attempts, greaterThanOrEqualTo(4));
        expect(outbox.contains('throwy'), isTrue);
        expect(outbox.deadEntry('throwy'), isNull);
      },
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

    outboxFakeTest(
      'reviveTransientDead re-arms transient + legacy, skips permanent',
      (async) async {
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
        async.elapse(const Duration(milliseconds: 1500));
        expect(delivered.map((e) => e.localId).toSet(), {
          'dead-transient',
          'dead-legacy',
        });
        for (final e in delivered) {
          expect(e.retryCount, 0);
          expect(e.dead, isFalse);
        }
      },
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

    outboxFakeTest(
      'restoreAndFlush loads persisted entries and schedules retry',
      (async) async {
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
        async.elapse(const Duration(milliseconds: 3500));

        expect(delivered, contains('restored-1'));
        outbox2.dispose();
      },
    );

    test('restoreAndFlush is idempotent', () async {
      outbox.configure(deliver: (e) async => null);
      await outbox.restoreAndFlush();
      await outbox.restoreAndFlush(); // second call should be a no-op
      // No exception thrown.
    });

    outboxFakeTest('restoreAndFlush delivers entries in queuedAt order', (
      async,
    ) async {
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
      async.elapse(const Duration(milliseconds: 5000));

      // Entries should be delivered in queuedAt order: msg-1, msg-3, msg-2.
      expect(delivered, ['msg-1', 'msg-3', 'msg-2']);
      outbox2.dispose();
    });

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

    outboxFakeTest('resume before restore recovery re-enables retries', (
      async,
    ) async {
      final deliveredIds = <String>[];
      outbox.configure(
        deliver: (entry) async {
          deliveredIds.add(entry.localId);
          return null;
        },
      );
      storage._outboxData = jsonEncode([
        _makeEntry(localId: 'restored-after-failure').toJson(),
      ]);
      storage.failReads = true;
      await outbox.restoreAndFlush();
      await outbox.suspendAndFlush();
      outbox.resume();

      storage.failReads = false;
      await outbox.restoreAndFlush();
      async.elapse(const Duration(seconds: 3));

      expect(deliveredIds, ['restored-after-failure']);
      expect(outbox.entries, isEmpty);
    });

    outboxFakeTest(
      'an in-flight failure stays suspended until foreground resume',
      (async) async {
        final delivery = Completer<OutboxDeliveryFailure?>();
        final deliveredIds = <String>[];
        outbox.configure(
          deliver: (entry) async {
            deliveredIds.add(entry.localId);
            if (deliveredIds.length == 1) return delivery.future;
            return null;
          },
        );
        await outbox.restoreAndFlush();
        await outbox.add(_makeEntry(localId: 'stable-retry'));
        async.elapse(const Duration(seconds: 2));
        expect(deliveredIds, ['stable-retry']);

        await outbox.suspendAndFlush();
        delivery.complete(OutboxDeliveryFailure.transient);
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 1));

        expect(deliveredIds, ['stable-retry']);
        expect(outbox.entries.single.localId, 'stable-retry');
        outbox.resume();
        async.elapse(const Duration(seconds: 2));
        expect(deliveredIds, ['stable-retry', 'stable-retry']);
        expect(outbox.entries, isEmpty);
      },
    );

    outboxFakeTest(
      'entries added while suspended wait for resume without losing identity',
      (async) async {
        final deliveredIds = <String>[];
        outbox.configure(
          deliver: (entry) async {
            deliveredIds.add(entry.localId);
            return null;
          },
        );
        await outbox.restoreAndFlush();
        await outbox.suspendAndFlush();
        await outbox.add(_makeEntry(localId: 'background-send'));
        async.elapse(const Duration(minutes: 1));

        expect(deliveredIds, isEmpty);
        expect(
          _decodeStoredOutbox(storage).single['localId'],
          'background-send',
        );
        outbox.resume();
        async.elapse(const Duration(seconds: 2));
        expect(deliveredIds, ['background-send']);
      },
    );

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

    outboxFakeTest(
      'suspendAndFlush skips the write when no persist is pending',
      (async) async {
        outbox.configure(deliver: (e) async => OutboxDeliveryFailure.permanent);

        await outbox.add(_makeEntry(localId: 'already-persisted'));
        // Let the debounced persist fire on its own.
        async.elapse(const Duration(milliseconds: 200));
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

    outboxFakeTest(
      'suspend() preserves the durable snapshot without an await',
      (async) async {
        outbox.configure(deliver: (e) async => OutboxDeliveryFailure.permanent);

        await outbox.add(_makeEntry(localId: 'flush-sync'));
        expect(storage._outboxData, isNotNull);

        outbox.suspend();
        async.elapse(Duration.zero);

        expect(storage._outboxData, isNotNull);
        final saved = _decodeStoredOutbox(storage);
        expect(saved.single['localId'], 'flush-sync');
      },
    );

    // ── Dispose ─────────────────────────────────────────────────────────────

    outboxFakeTest('a stale restore cannot resurrect disposed entries', (
      async,
    ) async {
      final blockingStorage = _BlockingReadMMKVStorage();
      final restoringOutbox = MessageOutbox(storage: blockingStorage);
      final deliveredIds = <String>[];
      restoringOutbox.configure(
        deliver: (entry) async {
          deliveredIds.add(entry.localId);
          return null;
        },
      );
      await restoringOutbox.add(_makeEntry(localId: 'old-account-send'));
      await restoringOutbox.suspendAndFlush();
      blockingStorage.blockReads = true;
      final restore = restoringOutbox.restoreAndFlush();
      await blockingStorage.readStarted.future;

      restoringOutbox.dispose();
      restoringOutbox.configure(
        deliver: (entry) async {
          deliveredIds.add(entry.localId);
          return null;
        },
      );
      blockingStorage.allowRead.complete();
      await restore;
      async.elapse(const Duration(seconds: 3));

      expect(restoringOutbox.entries, isEmpty);
      expect(restoringOutbox.deadEntries, isEmpty);
      expect(deliveredIds, isEmpty);
      restoringOutbox.dispose();
    });

    outboxFakeTest('a disposed add cannot notify the replacement runtime', (
      async,
    ) async {
      final blockingStorage = _BlockingMMKVStorage();
      final savingOutbox = MessageOutbox(storage: blockingStorage);
      final statuses = <String>[];
      savingOutbox.configure(deliver: (_) async => null);
      final save = savingOutbox.add(_makeEntry(localId: 'old-account-send'));
      await blockingStorage.saveStarted.future;

      savingOutbox.dispose();
      savingOutbox.configure(
        deliver: (_) async => null,
        onStatusChanged: (_, localId, status) =>
            statuses.add('$localId:$status'),
      );
      blockingStorage.allowSave.complete();
      await save;
      async.elapse(const Duration(seconds: 3));

      expect(statuses, isEmpty);
      expect(savingOutbox.entries, isEmpty);
      savingOutbox.dispose();
    });

    outboxFakeTest('dispose cancels pending timers', (async) async {
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
      async.elapse(const Duration(milliseconds: 1500));
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
