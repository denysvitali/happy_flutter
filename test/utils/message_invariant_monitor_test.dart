import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/message_invariant_monitor.dart';

void main() {
  group('MessageInvariantMonitor', () {
    late MessageInvariantMonitor monitor;
    late List<MessageInvariantViolation> captured;

    setUp(() {
      captured = <MessageInvariantViolation>[];
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
      );
    });

    int countFor(MessageInvariant i) => monitor.counters[i.tag] ?? -1;

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
      expect(captured.single.invariant, MessageInvariant.unmatchedOptimistic);
    });

    test('duplicate localId increments its counter', () async {
      monitor.recordOptimisticSent('dup');
      monitor.recordAck(
        localId: 'dup',
        optimisticRowCount: 2,
        sessionId: 's1',
      );

      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.duplicateLocalId), 1);
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
      expect(captured, hasLength(1));

      // A different session captures again.
      monitor.recordOptimisticSent('c');
      monitor.recordAck(localId: 'c', optimisticRowCount: 2, sessionId: 's2');
      await Future<void>.delayed(Duration.zero);
      expect(countFor(MessageInvariant.duplicateLocalId), 3);
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
  });
}
