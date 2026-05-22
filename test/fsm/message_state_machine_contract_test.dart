// P0 contract tests for the outbound-message FSM.
//
// CLAUDE.md mandates that chat send reliability is a P0 surface and that
// `localId` is the canonical identity preserved across optimistic UI, REST
// send, retry, socket forwarding, and merge. ROADMAP.md item "Core
// messaging state-machine tests" asks for the
// `draft -> sending -> sent/pending/failed -> merged` lifecycle to be
// pinned with valid + invalid transition coverage.
//
// This suite is the FSM contract:
//
//   * Per legal transition, assert the new state and that `localId` is
//     identical to the prior state.
//   * Per illegal/unsupported transition, assert that the FSM either
//     stays put (apply() ignores it) or rejects it (the static
//     [MessageStateTransitions] helpers refuse to construct an output
//     when the input is the wrong variant — they're typed so wrong-state
//     inputs do not compile, which is itself part of the contract).
//   * Walk a full lifecycle: draft -> sending -> failed -> sending
//     (retry) -> sent -> merged, asserting `localId` survives every hop.
//   * Two consecutive identical `continue` sends must produce distinct
//     `localId`s and progress through the FSM independently.
//
// The FSM exposes two surfaces:
//
//   1. [MessageStateTransitions] — pure, typed transition functions
//      keyed on the source variant. This is the authoritative spec
//      (see lib/core/fsm/message_state.g.dart, generated from
//      spec/message.fsm.yaml).
//   2. [MessageStateMachine.apply] — the event-log projection currently
//      wired into the merge entry point. It implements a *subset* of
//      the spec (no explicit Draft start state, no separate Sent
//      intermediate — Sending acks land directly in Merged). Both
//      surfaces are tested so future widening of `apply()` cannot
//      regress the spec.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/event_log/event_log.dart';
import 'package:happy_flutter/core/fsm/message_state.g.dart';
import 'package:happy_flutter/core/fsm/message_state_machine.dart';

const _kLocalId = 'L-canonical-1';

MessageEvent _ev(
  MessageEventKind kind,
  Map<String, Object?> payload, {
  int lamport = 1,
}) =>
    MessageEvent(
      sessionId: 'S',
      lamport: lamport,
      kind: kind,
      payload: payload,
      recordedAt: 0,
    );

void main() {
  group('MessageStateTransitions — typed FSM spec', () {
    group('legal transitions preserve localId', () {
      test('Draft -> Sending via sendFromDraft', () {
        const draft = MessageStateDraft(localId: _kLocalId, text: 'hi');
        final sending = MessageStateTransitions.sendFromDraft(
          draft,
          text: 'hi',
        );
        expect(sending, isA<MessageStateSending>());
        expect(sending!.localId, _kLocalId);
        expect(sending.text, 'hi');
        expect(sending.attempt, 1);
      });

      test('Sending -> Sent via ackFromSending', () {
        const sending = MessageStateSending(
          localId: _kLocalId,
          text: 'hi',
        );
        final sent = MessageStateTransitions.ackFromSending(
          sending,
          serverId: 'srv-1',
          seq: 7,
        );
        expect(sent, isA<MessageStateSent>());
        expect(sent!.localId, _kLocalId);
        expect(sent.serverId, 'srv-1');
        expect(sent.seq, 7);
      });

      test('Sending -> Pending via pendingFromSending', () {
        const sending = MessageStateSending(
          localId: _kLocalId,
          text: 'hi',
        );
        final pending = MessageStateTransitions.pendingFromSending(
          sending,
          reason: 'socket-disconnected',
        );
        expect(pending, isA<MessageStatePending>());
        expect(pending!.localId, _kLocalId);
        expect(pending.reason, 'socket-disconnected');
      });

      test('Sending -> Failed via failFromSending', () {
        const sending = MessageStateSending(
          localId: _kLocalId,
          text: 'hi',
        );
        final failed = MessageStateTransitions.failFromSending(
          sending,
          reason: 'http-500',
        );
        expect(failed, isA<MessageStateFailed>());
        expect(failed!.localId, _kLocalId);
        expect(failed.reason, 'http-500');
        expect(failed.attempt, 1);
      });

      test('Pending -> Sent via ackFromPending', () {
        const pending = MessageStatePending(
          localId: _kLocalId,
          reason: 'offline',
        );
        final sent = MessageStateTransitions.ackFromPending(
          pending,
          serverId: 'srv-9',
          seq: 11,
        );
        expect(sent, isA<MessageStateSent>());
        expect(sent!.localId, _kLocalId);
        expect(sent.serverId, 'srv-9');
        expect(sent.seq, 11);
      });

      test('Pending -> Failed via failFromPending', () {
        const pending = MessageStatePending(
          localId: _kLocalId,
          reason: 'offline',
        );
        final failed = MessageStateTransitions.failFromPending(
          pending,
          reason: 'max-retries',
        );
        expect(failed, isA<MessageStateFailed>());
        expect(failed!.localId, _kLocalId);
        expect(failed.reason, 'max-retries');
      });

      test('Failed -> Sending via retryFromFailed (preserves localId, '
          'increments attempt)', () {
        const failed = MessageStateFailed(
          localId: _kLocalId,
          reason: 'net',
        );
        final retried = MessageStateTransitions.retryFromFailed(
          failed,
          text: 'hi',
          attempt: failed.attempt + 1,
        );
        expect(retried, isA<MessageStateSending>());
        expect(retried!.localId, _kLocalId);
        expect(retried.text, 'hi');
        expect(retried.attempt, 2);
      });

      test('Sent -> Merged via mergeFromSent', () {
        const sent = MessageStateSent(
          localId: _kLocalId,
          serverId: 'srv-1',
          seq: 7,
        );
        final merged = MessageStateTransitions.mergeFromSent(
          sent,
          serverId: 'srv-1',
          seq: 7,
          text: 'hi',
        );
        expect(merged, isA<MessageStateMerged>());
        expect(merged!.localId, _kLocalId);
        expect(merged.serverId, 'srv-1');
        expect(merged.seq, 7);
        expect(merged.text, 'hi');
      });
    });

    group('ack/merge contract violations are rejected', () {
      test('ackFromSending without serverId throws ArgumentError', () {
        const sending = MessageStateSending(
          localId: _kLocalId,
          text: 'hi',
        );
        expect(
          () => MessageStateTransitions.ackFromSending(sending),
          throwsArgumentError,
        );
      });

      test('ackFromPending without serverId throws ArgumentError', () {
        const pending = MessageStatePending(
          localId: _kLocalId,
          reason: 'offline',
        );
        expect(
          () => MessageStateTransitions.ackFromPending(pending),
          throwsArgumentError,
        );
      });

      test('mergeFromSent without serverId throws ArgumentError', () {
        const sent = MessageStateSent(
          localId: _kLocalId,
          serverId: 'srv-1',
          seq: 7,
        );
        expect(
          () => MessageStateTransitions.mergeFromSent(sent),
          throwsArgumentError,
        );
      });
    });

    test('full lifecycle Draft -> Sending -> Failed -> Sending -> Sent '
        '-> Merged preserves localId at every hop', () {
      const draft = MessageStateDraft(localId: _kLocalId, text: 'continue');

      final sending = MessageStateTransitions.sendFromDraft(
        draft,
        text: draft.text,
      )!;
      expect(sending.localId, _kLocalId);

      final failed = MessageStateTransitions.failFromSending(
        sending,
        reason: 'net',
      )!;
      expect(failed.localId, _kLocalId);

      final retried = MessageStateTransitions.retryFromFailed(
        failed,
        text: draft.text,
        attempt: failed.attempt + 1,
      )!;
      expect(retried.localId, _kLocalId);
      expect(retried.attempt, 2,
          reason: 'retry must bump attempt to expose retry telemetry');

      final sent = MessageStateTransitions.ackFromSending(
        retried,
        serverId: 'srv-1',
        seq: 1,
      )!;
      expect(sent.localId, _kLocalId);

      final merged = MessageStateTransitions.mergeFromSent(
        sent,
        serverId: sent.serverId,
        seq: sent.seq,
        text: draft.text,
      )!;
      expect(merged.localId, _kLocalId);
      expect(merged.serverId, 'srv-1');
      expect(merged.seq, 1);
      expect(merged.text, 'continue');
    });
  });

  group('MessageStateMachine.apply — event-log projection contract', () {
    group('legal transitions', () {
      test('null -> Sending via optimisticAppended', () {
        final fsm = MessageStateMachine();
        fsm.apply(_ev(MessageEventKind.optimisticAppended,
            {'localId': _kLocalId, 'text': 'hi'}));
        final s = fsm.stateFor(_kLocalId);
        expect(s, isA<MessageStateSending>());
        expect(s!.localId, _kLocalId);
        expect((s as MessageStateSending).text, 'hi');
      });

      test('Sending -> Failed via sendFailed preserves localId', () {
        final fsm = MessageStateMachine();
        fsm
          ..apply(_ev(MessageEventKind.optimisticAppended,
              {'localId': _kLocalId, 'text': 'hi'}))
          ..apply(_ev(MessageEventKind.sendFailed,
              {'localId': _kLocalId, 'reason': 'net'}));
        final s = fsm.stateFor(_kLocalId);
        expect(s, isA<MessageStateFailed>());
        expect(s!.localId, _kLocalId);
        expect((s as MessageStateFailed).reason, 'net');
      });

      test('Failed -> Sending via retryRequested preserves localId', () {
        final fsm = MessageStateMachine();
        fsm
          ..apply(_ev(MessageEventKind.optimisticAppended,
              {'localId': _kLocalId, 'text': 'hi'}))
          ..apply(_ev(MessageEventKind.sendFailed,
              {'localId': _kLocalId, 'reason': 'net'}))
          ..apply(_ev(MessageEventKind.retryRequested,
              {'localId': _kLocalId}));
        final s = fsm.stateFor(_kLocalId);
        expect(s, isA<MessageStateSending>());
        expect(s!.localId, _kLocalId);
      });

      test('Sending -> Merged via serverAcked preserves localId', () {
        final fsm = MessageStateMachine();
        fsm
          ..apply(_ev(MessageEventKind.optimisticAppended,
              {'localId': _kLocalId, 'text': 'hi'}))
          ..apply(_ev(MessageEventKind.serverAcked, {
            'localId': _kLocalId,
            'serverId': 'srv-1',
            'seq': 7,
            'content': 'hi',
          }));
        final s = fsm.stateFor(_kLocalId);
        expect(s, isA<MessageStateMerged>());
        expect(s!.localId, _kLocalId);
        expect((s as MessageStateMerged).serverId, 'srv-1');
        expect(s.seq, 7);
      });

      test('Sending -> Merged via socketObserved preserves localId', () {
        final fsm = MessageStateMachine();
        fsm
          ..apply(_ev(MessageEventKind.optimisticAppended,
              {'localId': _kLocalId, 'text': 'hi'}))
          ..apply(_ev(MessageEventKind.socketObserved, {
            'localId': _kLocalId,
            'serverId': 'srv-2',
            'seq': 8,
            'content': 'hi',
          }));
        final s = fsm.stateFor(_kLocalId);
        expect(s, isA<MessageStateMerged>());
        expect(s!.localId, _kLocalId);
      });

      test('null -> Failed via sendFailed (outbox give-up before optimistic '
          'was even projected)', () {
        final fsm = MessageStateMachine();
        fsm.apply(_ev(MessageEventKind.sendFailed,
            {'localId': _kLocalId, 'reason': 'max-retries'}));
        final s = fsm.stateFor(_kLocalId);
        expect(s, isA<MessageStateFailed>());
        expect(s!.localId, _kLocalId);
        expect((s as MessageStateFailed).reason, 'max-retries');
      });

      test('null -> Merged via fetchedFromServer (server message we never '
          'optimistically appended)', () {
        final fsm = MessageStateMachine();
        fsm.apply(_ev(MessageEventKind.fetchedFromServer, {
          'localId': _kLocalId,
          'serverId': 'srv-3',
          'seq': 9,
          'content': 'inbound',
        }));
        final s = fsm.stateFor(_kLocalId);
        expect(s, isA<MessageStateMerged>());
        expect(s!.localId, _kLocalId);
      });
    });

    group('illegal/no-op transitions never invent identity or '
        'regress state', () {
      test('optimisticAppended on existing Sending is a no-op '
          '(prevents duplicate-row creation)', () {
        final fsm = MessageStateMachine();
        fsm.apply(_ev(MessageEventKind.optimisticAppended,
            {'localId': _kLocalId, 'text': 'hi'}));
        final before = fsm.stateFor(_kLocalId);
        fsm.apply(_ev(MessageEventKind.optimisticAppended,
            {'localId': _kLocalId, 'text': 'OVERWRITE'}));
        final after = fsm.stateFor(_kLocalId);
        expect(after, isA<MessageStateSending>());
        expect((after! as MessageStateSending).text, 'hi',
            reason: 'second optimistic must not overwrite text');
        expect(identical(before, after), isTrue,
            reason: 'state object must be unchanged');
      });

      test('optimisticAppended after Merged does not regress state '
          '(socket-before-optimistic ordering)', () {
        final fsm = MessageStateMachine();
        fsm
          ..apply(_ev(MessageEventKind.socketObserved, {
            'localId': _kLocalId,
            'serverId': 'srv-1',
            'seq': 1,
            'content': 'hi',
          }))
          ..apply(_ev(MessageEventKind.optimisticAppended,
              {'localId': _kLocalId, 'text': 'hi'}));
        final s = fsm.stateFor(_kLocalId);
        expect(s, isA<MessageStateMerged>(),
            reason: 'Merged must not regress to Sending');
        expect(s!.localId, _kLocalId);
      });

      test('retryRequested on Merged is a no-op '
          '(cannot retry an acked message)', () {
        final fsm = MessageStateMachine();
        fsm
          ..apply(_ev(MessageEventKind.optimisticAppended,
              {'localId': _kLocalId, 'text': 'hi'}))
          ..apply(_ev(MessageEventKind.serverAcked, {
            'localId': _kLocalId,
            'serverId': 'srv-1',
            'seq': 1,
            'content': 'hi',
          }));
        final before = fsm.stateFor(_kLocalId);
        fsm.apply(_ev(MessageEventKind.retryRequested,
            {'localId': _kLocalId}));
        final after = fsm.stateFor(_kLocalId);
        expect(after, isA<MessageStateMerged>());
        expect(identical(before, after), isTrue,
            reason: 'retry on Merged must be a strict no-op');
      });

      test('retryRequested on Sending is a no-op '
          '(no double-fire while in flight)', () {
        final fsm = MessageStateMachine();
        fsm.apply(_ev(MessageEventKind.optimisticAppended,
            {'localId': _kLocalId, 'text': 'hi'}));
        final before = fsm.stateFor(_kLocalId);
        fsm.apply(_ev(MessageEventKind.retryRequested,
            {'localId': _kLocalId}));
        final after = fsm.stateFor(_kLocalId);
        expect(after, isA<MessageStateSending>());
        expect(identical(before, after), isTrue);
      });

      test('retryRequested with no prior state is a no-op '
          '(cannot retry an unknown localId)', () {
        final fsm = MessageStateMachine();
        fsm.apply(_ev(MessageEventKind.retryRequested,
            {'localId': _kLocalId}));
        expect(fsm.stateFor(_kLocalId), isNull);
      });

      test('sendFailed on Merged is a no-op '
          '(failure cannot un-merge an acked message)', () {
        final fsm = MessageStateMachine();
        fsm
          ..apply(_ev(MessageEventKind.optimisticAppended,
              {'localId': _kLocalId, 'text': 'hi'}))
          ..apply(_ev(MessageEventKind.serverAcked, {
            'localId': _kLocalId,
            'serverId': 'srv-1',
            'seq': 1,
            'content': 'hi',
          }));
        final before = fsm.stateFor(_kLocalId);
        fsm.apply(_ev(MessageEventKind.sendFailed,
            {'localId': _kLocalId, 'reason': 'net'}));
        final after = fsm.stateFor(_kLocalId);
        expect(after, isA<MessageStateMerged>());
        expect(identical(before, after), isTrue);
      });

      test('event without localId is silently dropped '
          '(no anonymous state is created)', () {
        final fsm = MessageStateMachine();
        fsm.apply(_ev(MessageEventKind.optimisticAppended,
            {'text': 'orphan'}));
        expect(fsm.snapshot, isEmpty);
      });
    });

    test('end-to-end lifecycle via apply(): '
        'optimistic -> failed -> retry -> ack -> merge — '
        'localId is identical at every step', () {
      final fsm = MessageStateMachine();

      fsm.apply(_ev(MessageEventKind.optimisticAppended,
          {'localId': _kLocalId, 'text': 'continue'}));
      final s1 = fsm.stateFor(_kLocalId);
      expect(s1, isA<MessageStateSending>());
      expect(s1!.localId, _kLocalId);

      fsm.apply(_ev(MessageEventKind.sendFailed,
          {'localId': _kLocalId, 'reason': 'net'}));
      final s2 = fsm.stateFor(_kLocalId);
      expect(s2, isA<MessageStateFailed>());
      expect(s2!.localId, _kLocalId);

      fsm.apply(_ev(MessageEventKind.retryRequested,
          {'localId': _kLocalId}));
      final s3 = fsm.stateFor(_kLocalId);
      expect(s3, isA<MessageStateSending>());
      expect(s3!.localId, _kLocalId);

      fsm.apply(_ev(MessageEventKind.serverAcked, {
        'localId': _kLocalId,
        'serverId': 'srv-final',
        'seq': 42,
        'content': 'continue',
      }));
      final s4 = fsm.stateFor(_kLocalId);
      expect(s4, isA<MessageStateMerged>());
      expect(s4!.localId, _kLocalId);
      final merged = s4 as MessageStateMerged;
      expect(merged.serverId, 'srv-final');
      expect(merged.seq, 42);
      expect(merged.text, 'continue');
    });

    test("two consecutive identical 'continue' sends produce distinct "
        'localIds and progress through the FSM independently', () {
      const l1 = 'L-continue-1';
      const l2 = 'L-continue-2';
      final fsm = MessageStateMachine();

      // Both tap "continue" — UI is responsible for minting distinct
      // localIds. The FSM must keep them as separate aggregates.
      fsm
        ..apply(_ev(MessageEventKind.optimisticAppended,
            {'localId': l1, 'text': 'continue'}))
        ..apply(_ev(MessageEventKind.optimisticAppended,
            {'localId': l2, 'text': 'continue'}));

      expect(fsm.snapshot.keys.toSet(), {l1, l2},
          reason: 'identical text must not collapse aggregates');

      // First send fails and is retried.
      fsm
        ..apply(_ev(MessageEventKind.sendFailed,
            {'localId': l1, 'reason': 'net'}))
        ..apply(_ev(MessageEventKind.retryRequested, {'localId': l1}));
      expect(fsm.stateFor(l1), isA<MessageStateSending>());
      expect(fsm.stateFor(l2), isA<MessageStateSending>(),
          reason: "second send must not be affected by first's failure");

      // First send finally acks. Second is still in flight.
      fsm.apply(_ev(MessageEventKind.serverAcked, {
        'localId': l1,
        'serverId': 'srv-a',
        'seq': 1,
        'content': 'continue',
      }));
      expect(fsm.stateFor(l1), isA<MessageStateMerged>());
      expect((fsm.stateFor(l1)! as MessageStateMerged).localId, l1);
      expect(fsm.stateFor(l2), isA<MessageStateSending>(),
          reason: "ack for L1 must not bleed into L2's identity");

      // Second send acks last.
      fsm.apply(_ev(MessageEventKind.serverAcked, {
        'localId': l2,
        'serverId': 'srv-b',
        'seq': 2,
        'content': 'continue',
      }));
      final m2 = fsm.stateFor(l2)! as MessageStateMerged;
      expect(m2.localId, l2);
      expect(m2.serverId, 'srv-b');
      expect(m2.seq, 2);

      // Distinct server identities, never collapsed.
      final m1 = fsm.stateFor(l1)! as MessageStateMerged;
      expect(m1.serverId, isNot(equals(m2.serverId)));
      expect(m1.seq, isNot(equals(m2.seq)));
    });
  });
}
