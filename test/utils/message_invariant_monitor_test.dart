import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/message_invariant_monitor.dart';

void main() {
  group('MessageInvariantMonitor', () {
    late MessageInvariantMonitor monitor;
    late List<MessageInvariantViolation> captured;
    late List<MessageInvariant> counted;
    late List<MessageInvariant> primed;
    late List<(Duration, String)> durations;

    setUp(() {
      captured = <MessageInvariantViolation>[];
      counted = <MessageInvariant>[];
      primed = <MessageInvariant>[];
      durations = <(Duration, String)>[];
      monitor = MessageInvariantMonitor(
        captureException:
            (
              Object error, {
              required MessageInvariant invariant,
              String? sessionId,
              String? localId,
              String? detail,
            }) async {
              captured.add(error as MessageInvariantViolation);
            },
        recordCounter: (invariant, {bool prime = false}) {
          (prime ? primed : counted).add(invariant);
        },
        recordSendDuration: (elapsed, {required outcome}) {
          durations.add((elapsed, outcome));
        },
      );
    });

    int countFor(MessageInvariant i) => monitor.counters[i.tag] ?? -1;

    test('constructor primes all four counters so the series exist at zero',
        () {
      // Audit 2026-08-03: lazy counter creation meant a never-fired
      // invariant had no Prometheus series, so "zero breaches" and
      // "metric missing" were indistinguishable for alerting.
      expect(primed, MessageInvariant.values);
      expect(counted, isEmpty);
    });

    test('happy path records ZERO violations', () async {
      // One tap -> one localId -> one optimistic row -> one ack.
      monitor.recordOptimisticSent('local-1');
      monitor.recordAck(
        localId: 'local-1',
        optimisticRowCount: 1,
        sessionId: 's1',
      );
      // Repeated identical send: distinct localId, distinct logical row.
      monitor.recordOptimisticSent('local-2');
      monitor.recordAck(
        localId: 'local-2',
        optimisticRowCount: 1,
        sessionId: 's1',
      );
      // Explicit retry preserving identity, still a single row.
      monitor.recordRetry(
        expected: 'local-1',
        observed: 'local-1',
        rowCount: 1,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(monitor.totalViolations, 0);
      expect(captured, isEmpty);
      for (final i in MessageInvariant.values) {
        expect(countFor(i), 0, reason: 'expected zero for ${i.tag}');
      }
    });

    test('unmatched optimistic increments its counter', () async {
      monitor.recordOptimisticSent('local-x');
      // Sent, but the optimistic placeholder row went missing before ack.
      monitor.recordAck(
        localId: 'local-x',
        optimisticRowCount: 0,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.unmatchedOptimistic), 1);
      expect(monitor.totalViolations, 1);
      expect(counted.single, MessageInvariant.unmatchedOptimistic);
      expect(captured.single.invariant, MessageInvariant.unmatchedOptimistic);
    });

    test('duplicate localId increments its counter', () async {
      monitor.recordOptimisticSent('dup');
      monitor.recordAck(localId: 'dup', optimisticRowCount: 2, sessionId: 's1');

      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.duplicateLocalId), 1);
      expect(counted.single, MessageInvariant.duplicateLocalId);
      expect(captured.single.invariant, MessageInvariant.duplicateLocalId);
      expect(captured.single.detail, 'rowCount=2');
    });

    test('unknown acked localId increments its counter', () async {
      // No recordOptimisticSent — the ack references an id never minted.
      monitor.recordAck(
        localId: 'ghost',
        optimisticRowCount: 1,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.unknownAckedLocalId), 1);
      expect(counted.single, MessageInvariant.unknownAckedLocalId);
      expect(captured.single.invariant, MessageInvariant.unknownAckedLocalId);
    });

    test('retry-created duplicate (changed id) increments counter', () async {
      monitor.recordRetry(
        expected: 'orig',
        observed: 'NEW-minted-id',
        rowCount: 1,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.retryCreatedDuplicate), 1);
      expect(counted.single, MessageInvariant.retryCreatedDuplicate);
      expect(captured.single.invariant, MessageInvariant.retryCreatedDuplicate);
      expect(captured.single.detail, 'observed=NEW-minted-id');
    });

    test('retry-created duplicate (extra row) increments counter', () async {
      monitor.recordRetry(
        expected: 'orig',
        observed: 'orig',
        rowCount: 2,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.retryCreatedDuplicate), 1);
      expect(counted.single, MessageInvariant.retryCreatedDuplicate);
      expect(captured.single.detail, 'rowCount=2');
    });

    test('captures are rate-limited per (invariant, session)', () async {
      // Two duplicate violations for the same session -> counter bumps
      // twice but Sentry is captured once.
      monitor.recordOptimisticSent('a');
      monitor.recordAck(localId: 'a', optimisticRowCount: 2, sessionId: 's1');
      monitor.recordOptimisticSent('b');
      monitor.recordAck(localId: 'b', optimisticRowCount: 3, sessionId: 's1');

      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.duplicateLocalId), 2);
      expect(counted, <MessageInvariant>[
        MessageInvariant.duplicateLocalId,
        MessageInvariant.duplicateLocalId,
      ]);
      expect(captured, hasLength(1));

      // A different session captures again.
      monitor.recordOptimisticSent('c');
      monitor.recordAck(localId: 'c', optimisticRowCount: 2, sessionId: 's2');
      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.duplicateLocalId), 3);
      expect(counted, <MessageInvariant>[
        MessageInvariant.duplicateLocalId,
        MessageInvariant.duplicateLocalId,
        MessageInvariant.duplicateLocalId,
      ]);
      expect(captured, hasLength(2));
    });

    test('reset clears counters and rate-limit state', () async {
      monitor.recordAck(localId: 'ghost', optimisticRowCount: 1);
      await Future<void>.delayed(Duration.zero);
      expect(monitor.totalViolations, 1);

      monitor.reset();
      expect(monitor.totalViolations, 0);
      for (final i in MessageInvariant.values) {
        expect(countFor(i), 0);
      }
    });

    test('empty localId is ignored (defensive no-op)', () async {
      monitor.recordOptimisticSent('');
      monitor.recordAck(localId: '', optimisticRowCount: 0);
      monitor.recordRetry(expected: '', observed: 'x', rowCount: 5);

      await Future<void>.delayed(Duration.zero);
      expect(monitor.totalViolations, 0);
      expect(captured, isEmpty);
    });

    // ── Audit 2026-08-03 fixes ────────────────────────────────────────────

    test('a double-tapped ack is observed once (REST path + status path)',
        () async {
      // The same server ack reaches recordAck from BOTH the REST-ack
      // apply path and the send-status path. Before the dedupe this
      // double-counted every ack — and any violation with it.
      monitor.recordOptimisticSent('local-d');
      monitor.recordAck(
        localId: 'local-d',
        optimisticRowCount: 2, // a real duplicate row
        sessionId: 's1',
      );
      monitor.recordAck(
        localId: 'local-d',
        optimisticRowCount: 2,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.duplicateLocalId), 1);
      expect(counted, hasLength(1));
      expect(captured, hasLength(1));
      expect(durations, hasLength(1));
    });

    test('seeded localId from a persisted row is not unknown-acked',
        () async {
      // Restart case: the id was minted by an earlier process and came
      // back via cache restore / history fetch. Its ack must NOT read
      // as unknown_acked_local_id (the audit's false positive).
      monitor.seedSentLocalId('restored-1');
      monitor.recordAck(
        localId: 'restored-1',
        optimisticRowCount: 1,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(monitor.totalViolations, 0);
      expect(captured, isEmpty);
      // Seeded ids carry no mint timestamp → no latency sample.
      expect(durations, isEmpty);
    });

    test('seeded localId with a missing row is unmatched, not unknown',
        () async {
      monitor.seedSentLocalId('restored-2');
      monitor.recordAck(
        localId: 'restored-2',
        optimisticRowCount: 0,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.unmatchedOptimistic), 1);
      expect(countFor(MessageInvariant.unknownAckedLocalId), 0);
    });

    test('tap→ack latency is recorded with the outcome label', () async {
      monitor.recordOptimisticSent('local-t');
      monitor.recordAck(
        localId: 'local-t',
        optimisticRowCount: 1,
        sessionId: 's1',
      );

      expect(durations, hasLength(1));
      final (elapsed, outcome) = durations.single;
      expect(outcome, 'ok');
      expect(elapsed, greaterThanOrEqualTo(Duration.zero));
    });

    test('tap→ack latency carries the violated invariant as outcome',
        () async {
      monitor.recordOptimisticSent('local-v');
      monitor.recordAck(
        localId: 'local-v',
        optimisticRowCount: 0, // placeholder lost before the ack
        sessionId: 's1',
      );

      expect(durations, hasLength(1));
      expect(durations.single.$2, 'unmatched_optimistic');
    });

    test('unknown ack records no latency sample (never minted here)',
        () async {
      monitor.recordAck(
        localId: 'ghost-latency',
        optimisticRowCount: 1,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.unknownAckedLocalId), 1);
      expect(durations, isEmpty);
    });

    test('reset clears ack dedupe so a fresh process view can re-observe',
        () async {
      monitor.recordOptimisticSent('local-r');
      monitor.recordAck(
        localId: 'local-r',
        optimisticRowCount: 1,
        sessionId: 's1',
      );
      monitor.reset();
      monitor.recordOptimisticSent('local-r');
      monitor.recordAck(
        localId: 'local-r',
        optimisticRowCount: 1,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(monitor.totalViolations, 0);
      // One sample before reset, one after.
      expect(durations, hasLength(2));
    });
  });
}
