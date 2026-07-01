import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/event_log/event_log.dart';
import 'package:happy_flutter/core/event_log/event_log_flag.dart';
import 'package:happy_flutter/core/event_log/message_projection.dart';

void main() {
  final logs = <EventLog>[];

  EventLog newLog() {
    final log = EventLog(InMemoryEventLogStore());
    logs.add(log);
    return log;
  }

  setUp(() {
    setUseEventLogForTest(true);
  });
  tearDown(() async {
    for (final log in logs) {
      await log.dispose();
    }
    logs.clear();
    setUseEventLogForTest(false);
  });

  group('EventLog', () {
    test('lamport counter is monotonic and per-session', () async {
      final log = newLog();
      final a1 = await log.append(
        sessionId: 'A',
        kind: MessageEventKind.optimisticAppended,
        payload: {'localId': 'a-1', 'role': 'user', 'text': 'hi'},
      );
      final a2 = await log.append(
        sessionId: 'A',
        kind: MessageEventKind.serverAcked,
        payload: {'localId': 'a-1', 'serverId': 'srv-1', 'seq': 1},
      );
      final b1 = await log.append(
        sessionId: 'B',
        kind: MessageEventKind.optimisticAppended,
        payload: {'localId': 'b-1', 'role': 'user', 'text': 'hi'},
      );
      expect(a1.lamport, 1);
      expect(a2.lamport, 2);
      expect(b1.lamport, 1);

      final aEvents = await log.events('A');
      expect(aEvents.map((e) => e.lamport).toList(), [1, 2]);
    });

    test('event roundtrips through JSON', () {
      const e = MessageEvent(
        sessionId: 'S',
        lamport: 7,
        kind: MessageEventKind.optimisticAppended,
        payload: {'localId': 'x', 'text': 'hello'},
        recordedAt: 1234,
      );
      final back = MessageEvent.fromJson(e.toJson());
      expect(back.sessionId, e.sessionId);
      expect(back.lamport, e.lamport);
      expect(back.kind, e.kind);
      expect(back.payload['localId'], 'x');
      expect(back.recordedAt, e.recordedAt);
    });

    test('flag defaults to false in production', () {
      setUseEventLogForTest(false);
      expect(kUseEventLog, isFalse);
    });
  });

  group('MessageProjection — pure folding rules', () {
    Future<List<MessageEvent>> mk(
      EventLog log,
      String sessionId,
      List<(MessageEventKind, Map<String, Object?>)> facts,
    ) async {
      for (final f in facts) {
        await log.append(sessionId: sessionId, kind: f.$1, payload: f.$2);
      }
      return log.events(sessionId);
    }

    test('optimistic appended produces sending state', () async {
      final log = newLog();
      final events = await mk(log, 'S', [
        (
          MessageEventKind.optimisticAppended,
          {'localId': 'L1', 'role': 'user', 'text': 'hello'},
        ),
      ]);
      final out = MessageProjection.project(events);
      expect(out, hasLength(1));
      expect(out.first.localId, 'L1');
      expect(out.first.state, ProjectedState.sending);
      expect(out.first.text, 'hello');
    });

    test('server ack promotes optimistic to merged by localId', () async {
      final log = newLog();
      final events = await mk(log, 'S', [
        (
          MessageEventKind.optimisticAppended,
          {'localId': 'L1', 'role': 'user', 'text': 'hi'},
        ),
        (
          MessageEventKind.serverAcked,
          {'localId': 'L1', 'serverId': 'srv-9', 'seq': 1, 'content': 'hi'},
        ),
      ]);
      final out = MessageProjection.project(events);
      expect(out.single.state, ProjectedState.merged);
      expect(out.single.serverId, 'srv-9');
      expect(out.single.seq, 1);
    });

    test('two distinct localIds with identical text never collapse', () async {
      final log = newLog();
      final events = await mk(log, 'S', [
        (
          MessageEventKind.optimisticAppended,
          {'localId': 'L1', 'role': 'user', 'text': 'continue'},
        ),
        (
          MessageEventKind.optimisticAppended,
          {'localId': 'L2', 'role': 'user', 'text': 'continue'},
        ),
        (
          MessageEventKind.serverAcked,
          {'localId': 'L1', 'serverId': 'srv-1', 'seq': 1, 'content': 'continue'},
        ),
        (
          MessageEventKind.serverAcked,
          {'localId': 'L2', 'serverId': 'srv-2', 'seq': 2, 'content': 'continue'},
        ),
      ]);
      final out = MessageProjection.project(events);
      expect(out, hasLength(2));
      expect(out.map((m) => m.serverId).toList(), ['srv-1', 'srv-2']);
      expect(out.map((m) => m.state).toSet(), {ProjectedState.merged});
    });

    test('retry preserves localId; fail then ack still ends merged', () async {
      final log = newLog();
      final events = await mk(log, 'S', [
        (
          MessageEventKind.optimisticAppended,
          {'localId': 'L1', 'role': 'user', 'text': 'hi'},
        ),
        (MessageEventKind.sendFailed, {'localId': 'L1', 'reason': 'net'}),
        (MessageEventKind.retryRequested, {'localId': 'L1'}),
        (
          MessageEventKind.serverAcked,
          {'localId': 'L1', 'serverId': 'srv-9', 'seq': 1, 'content': 'hi'},
        ),
      ]);
      final out = MessageProjection.project(events);
      expect(out.single.localId, 'L1');
      expect(out.single.state, ProjectedState.merged);
      expect(out.single.serverId, 'srv-9');
    });

    test('out-of-order: socket observed before optimistic still merges',
        () async {
      final log = newLog();
      final events = await mk(log, 'S', [
        (
          MessageEventKind.socketObserved,
          {'localId': 'L1', 'serverId': 'srv-1', 'seq': 1, 'content': 'hi'},
        ),
        (
          MessageEventKind.optimisticAppended,
          {'localId': 'L1', 'role': 'user', 'text': 'hi'},
        ),
      ]);
      final out = MessageProjection.project(events);
      expect(out.single.state, ProjectedState.merged);
    });

    test('events without a localId are ignored', () async {
      final log = newLog();
      await log.append(
        sessionId: 'S',
        kind: MessageEventKind.serverAcked,
        payload: const {'serverId': 'orphan'},
      );
      final out = MessageProjection.project(await log.events('S'));
      expect(out, isEmpty);
    });

    test('truncate empties the log for one session only', () async {
      final log = newLog();
      await log.append(
        sessionId: 'A',
        kind: MessageEventKind.optimisticAppended,
        payload: const {'localId': 'L', 'text': 'a'},
      );
      await log.append(
        sessionId: 'B',
        kind: MessageEventKind.optimisticAppended,
        payload: const {'localId': 'L', 'text': 'b'},
      );
      await log.truncate('A');
      expect(await log.events('A'), isEmpty);
      expect((await log.events('B')).single.payload['text'], 'b');
    });
  });
}
