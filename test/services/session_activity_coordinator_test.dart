import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/session_activity_coordinator.dart';

Session _makeSession({
  required String id,
  bool thinking = false,
  AgentState? agentState,
  Metadata? metadata,
  int activeAt = 1_700_000_000_000,
  int? thinkingAt,
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: true,
    activeAt: activeAt,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: 'online',
    agentState: agentState,
    metadata: metadata,
    thinkingAt: thinkingAt,
  );
}

void main() {
  group('SessionActivityCoordinator.computeDecision', () {
    test('idle session yields a noop decision', () {
      final c = SessionActivityCoordinator();
      final d = c.computeDecision(_makeSession(id: 's1'));
      expect(d.isNoop, isTrue);
      expect(d.sessionId, 's1');
    });

    test('thinking session yields a show decision with tool name', () {
      final c = SessionActivityCoordinator();
      final session = _makeSession(
        id: 's1',
        thinking: true,
        thinkingAt: 1_700_000_001_000,
        agentState: AgentState(
          requests: {
            'p1': RequestInfo(tool: 'Bash', arguments: {'cmd': 'ls'}),
          },
        ),
        metadata: Metadata(path: '/home/me/proj'),
      );
      final d = c.computeDecision(session);
      expect(d.isShow, isTrue);
      expect(d.sessionId, 's1');
      expect(d.toolName, 'Bash');
      expect(d.startedAt, isNotNull);
      expect(
        d.startedAt!.millisecondsSinceEpoch,
        1_700_000_001_000,
      );
      // Falls back to last segment of path when summary is absent.
      expect(d.sessionName, 'proj');
    });

    test(
      'thinking session with no in-flight tool reports a placeholder',
      () {
        final c = SessionActivityCoordinator();
        final d = c.computeDecision(
          _makeSession(id: 's1', thinking: true),
        );
        expect(d.isShow, isTrue);
        expect(d.toolName, 'Thinking…');
      },
    );

    test('visibleSessionId suppresses the activity decision', () {
      final c = SessionActivityCoordinator()..visibleSessionId = 's1';
      final d = c.computeDecision(
        _makeSession(id: 's1', thinking: true),
      );
      // Not actively tracked yet, and we shouldn't start one for it.
      expect(d.isNoop, isTrue);
    });

    test(
      'leaving the thinking state for a tracked session yields end',
      () async {
        final c = SessionActivityCoordinator();
        // First mark s1 as thinking via applyDecision so internal
        // bookkeeping records it as active.
        await c.applyDecision(
          ActivityDecision.show(
            sessionId: 's1',
            toolName: 'Bash',
            startedAt: DateTime.now(),
          ),
        );
        expect(c.debugTrackedSessions, contains('s1'));

        final d = c.computeDecision(
          _makeSession(id: 's1', thinking: false),
        );
        expect(d.isEnd, isTrue);
      },
    );

    test('setVisibleSession ends an active activity for that session',
        () async {
      final c = SessionActivityCoordinator();
      await c.applyDecision(
        ActivityDecision.show(
          sessionId: 's1',
          toolName: 'Bash',
          startedAt: DateTime.now(),
        ),
      );
      expect(c.debugTrackedSessions, contains('s1'));
      await c.setVisibleSession('s1');
      expect(c.debugTrackedSessions, isNot(contains('s1')));
      expect(c.visibleSessionId, 's1');
    });
  });
}
