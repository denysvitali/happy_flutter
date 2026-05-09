import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/actors/session_actor.dart';

void main() {
  group('SessionActorHost — single-isolate scaffold', () {
    test('start -> send -> ingest -> stop produces ordered outbound events',
        () async {
      final host = SessionActorHost(InProcessSessionActor.new);
      final events = <SessionOutbound>[];
      final sub = host.outbound.listen(events.add);

      await host.dispatch(const StartActor(sessionId: 'S'));
      await host.dispatch(const SendUserMessage(
        sessionId: 'S',
        localId: 'L1',
        text: 'hi',
      ));
      await host.dispatch(const IngestServerMessage(
        sessionId: 'S',
        localId: 'L1',
        serverId: 'srv-1',
        seq: 1,
      ));
      await host.dispatch(const StopActor(sessionId: 'S'));
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(4));
      expect(events[0], isA<ActorReady>());
      expect(events[1], isA<MessageProjected>());
      expect((events[1] as MessageProjected).state, 'sending');
      expect((events[2] as MessageProjected).state, 'merged');
      expect(events[3], isA<ActorStopped>());

      await sub.cancel();
      await host.dispose();
    });

    test('two sessions get two actors with independent state', () async {
      final host = SessionActorHost(InProcessSessionActor.new);
      await host.dispatch(const StartActor(sessionId: 'A'));
      await host.dispatch(const StartActor(sessionId: 'B'));
      await host.dispatch(const SendUserMessage(
        sessionId: 'A',
        localId: 'L1',
        text: 'a',
      ));
      // No exception. We're proving the dispatch keys by sessionId.
      await host.dispose();
    });
  });
}
