import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/event_log/event_log.dart';
import 'package:happy_flutter/core/fsm/message_state.g.dart';
import 'package:happy_flutter/core/fsm/message_state_machine.dart';

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
  group('MessageStateMachine — sealed FSM applied to events', () {
    test('optimistic + ack ends in Merged with same localId', () {
      final fsm = MessageStateMachine();
      fsm.apply(_ev(MessageEventKind.optimisticAppended,
          {'localId': 'L1', 'text': 'hi'}));
      expect(fsm.stateFor('L1'), isA<MessageStateSending>());
      fsm.apply(_ev(MessageEventKind.serverAcked,
          {'localId': 'L1', 'serverId': 'srv-1', 'seq': 7, 'content': 'hi'}));
      final s = fsm.stateFor('L1');
      expect(s, isA<MessageStateMerged>());
      final merged = s! as MessageStateMerged;
      expect(merged.localId, 'L1');
      expect(merged.serverId, 'srv-1');
      expect(merged.seq, 7);
      expect(merged.text, 'hi');
    });

    test('fail then retry returns to Sending; ack still merges', () {
      final fsm = MessageStateMachine();
      fsm.apply(_ev(MessageEventKind.optimisticAppended,
          {'localId': 'L1', 'text': 'continue'}));
      fsm.apply(_ev(MessageEventKind.sendFailed,
          {'localId': 'L1', 'reason': 'net'}));
      expect(fsm.stateFor('L1'), isA<MessageStateFailed>());
      fsm.apply(_ev(MessageEventKind.retryRequested, {'localId': 'L1'}));
      expect(fsm.stateFor('L1'), isA<MessageStateSending>());
      fsm.apply(_ev(MessageEventKind.serverAcked,
          {'localId': 'L1', 'serverId': 'srv-9', 'seq': 1}));
      expect(fsm.stateFor('L1'), isA<MessageStateMerged>());
    });

    test('two distinct localIds with same text never collapse', () {
      final fsm = MessageStateMachine();
      fsm.apply(_ev(MessageEventKind.optimisticAppended,
          {'localId': 'L1', 'text': 'continue'}));
      fsm.apply(_ev(MessageEventKind.optimisticAppended,
          {'localId': 'L2', 'text': 'continue'}));
      fsm.apply(_ev(MessageEventKind.serverAcked,
          {'localId': 'L1', 'serverId': 'srv-1', 'seq': 1}));
      expect(fsm.snapshot.keys.toSet(), {'L1', 'L2'});
      expect(fsm.stateFor('L1'), isA<MessageStateMerged>());
      expect(fsm.stateFor('L2'), isA<MessageStateSending>());
    });

    test('socket arrives before optimistic — still ends Merged', () {
      final fsm = MessageStateMachine();
      fsm.apply(_ev(MessageEventKind.socketObserved,
          {'localId': 'L1', 'serverId': 'srv-1', 'seq': 1, 'content': 'hi'}));
      fsm.apply(_ev(MessageEventKind.optimisticAppended,
          {'localId': 'L1', 'text': 'hi'}));
      // Optimistic should not regress a Merged state.
      expect(fsm.stateFor('L1'), isA<MessageStateMerged>());
    });
  });
}
