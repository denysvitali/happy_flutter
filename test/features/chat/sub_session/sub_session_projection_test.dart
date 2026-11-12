import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sidechain_grouper.dart';
import 'package:happy_flutter/features/chat/sub_session/sub_session_agents.dart';
import 'package:happy_flutter/features/chat/sub_session/sub_session_projection.dart';
import 'package:happy_flutter/features/chat/widgets/agents_list_sheet.dart';

const _now = 10000000;

Map<String, dynamic> _call({
  required String callId,
  String childId = 'child-1',
  int seq = 1,
  int createdAt = _now - 1000,
  String state = 'running',
  Object? result,
  String? resultStatus,
  String description = 'Fix the flaky test',
}) => {
  'id': 'msg-$callId',
  'toolUseId': callId,
  'kind': 'tool-call',
  'name': 'Agent',
  'seq': seq,
  'createdAt': createdAt,
  'state': state,
  'result': ?result,
  'resultStatus': ?resultStatus,
  'input': {
    'description': description,
    'prompt': 'Please fix it',
    'subagent_type': 'happy-session',
    'agentId': childId,
    'sessionId': childId,
  },
};

Session _session({
  String id = 'child-1',
  bool thinking = false,
  bool archived = false,
  String presence = 'online',
  bool active = true,
  String? summary,
}) => Session(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: active,
  activeAt: _now,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: thinking,
  archived: archived,
  presence: presence,
  metadata: Metadata(
    path: '/work/happy_flutter',
    repoUrl: 'https://github.com/acme/happy_flutter.git',
    summary: summary == null ? null : Summary(text: summary, updatedAt: 1),
  ),
);

void main() {
  group('happy-session detection', () {
    test('only happy-session Agent calls are sub-session spawns', () {
      expect(isHappySubSessionSpawn(_call(callId: 'a')), isTrue);
      final inProcess = _call(callId: 'b')
        ..['input'] = {'subagent_type': 'general-purpose'};
      expect(isHappySubSessionSpawn(inProcess), isFalse);
      expect(happySubSessionChildId(_call(callId: 'a')), 'child-1');
      final onlyTopLevel = _call(callId: 'c')
        ..['input'] = {'subagent_type': 'happy-session'}
        ..['agentId'] = 'child-9';
      expect(happySubSessionChildId(onlyTopLevel), 'child-9');
    });
  });

  group('turn status', () {
    test('in progress, completed, failed and unknown', () {
      expect(
        subSessionTurnStatus(_call(callId: 'a')),
        SubSessionTurnStatus.running,
      );
      expect(
        subSessionTurnStatus(
          _call(callId: 'a', state: 'completed', result: 'Done'),
        ),
        SubSessionTurnStatus.completed,
      );
      expect(
        subSessionTurnStatus(_call(callId: 'a', state: 'error')),
        SubSessionTurnStatus.failed,
      );
      expect(
        subSessionTurnStatus(
          _call(callId: 'a', state: 'completed', resultStatus: 'failed'),
        ),
        SubSessionTurnStatus.failed,
      );
      // `unknown` wins even when the transport reported no error.
      expect(
        subSessionTurnStatus(
          _call(callId: 'a', state: 'completed', resultStatus: 'unknown'),
        ),
        SubSessionTurnStatus.unknown,
      );
    });

    test('reply text is read from string and block results', () {
      expect(
        subSessionReply(_call(callId: 'a', result: '  **Done**  ')),
        '**Done**',
      );
      expect(
        subSessionReply(
          _call(
            callId: 'a',
            result: [
              {'type': 'text', 'text': 'One'},
              {'type': 'text', 'text': 'Two'},
            ],
          ),
        ),
        'One\n\nTwo',
      );
      expect(subSessionReply(_call(callId: 'a', result: '   ')), isNull);
    });
  });

  group('child state', () {
    test('maps the session store onto live states', () {
      expect(subSessionChildState(null), SubSessionChildState.notLoaded);
      expect(
        subSessionChildState(_session(thinking: true)),
        SubSessionChildState.working,
      );
      expect(subSessionChildState(_session()), SubSessionChildState.idle);
      expect(
        subSessionChildState(
          _session(archived: true, presence: 'offline', active: false),
        ),
        SubSessionChildState.archived,
      );
      expect(
        subSessionChildState(_session(presence: 'offline', active: false)),
        SubSessionChildState.offline,
      );
    });

    test('repository label prefers the repository path', () {
      expect(subSessionRepositoryLabel(_session()), 'acme/happy_flutter');
      expect(subSessionRepositoryLabel(null), isNull);
    });
  });

  group('threads', () {
    test('follow-up turns to the same child are numbered in order', () {
      final spawn = _call(callId: 'a', seq: 3);
      final followUp = _call(callId: 'b', seq: 9);
      final other = _call(callId: 'c', childId: 'child-2', seq: 5);
      // Transcript order must not matter: seq orders the thread.
      final threads = SubSessionThreads.fromMessages([followUp, other, spawn]);

      final first = threads.positionOf(spawn)!;
      final second = threads.positionOf(followUp)!;
      expect((first.number, first.count, first.isFollowUp), (1, 2, false));
      expect(
        (second.number, second.isFollowUp, second.isLatest),
        (2, true, true),
      );
      expect(threads.positionOf(other)!.count, 1);
      expect(threads.childIds, containsAll(['child-1', 'child-2']));
    });

    test('unindexed calls have no position', () {
      final threads = SubSessionThreads.fromMessages([_call(callId: 'a')]);
      expect(threads.positionOf(_call(callId: 'zzz')), isNull);
    });
  });

  group('open turns', () {
    bool open(Map<String, dynamic> call, Session? child, {bool sup = false}) =>
        isSubSessionTurnOpen(call, child: child, superseded: sup, nowMs: _now);

    test('a running turn stays open while the child works', () {
      final call = _call(callId: 'a', createdAt: _now - 600000);
      expect(open(call, _session(thinking: true)), isTrue);
      expect(open(call, null), isTrue, reason: 'unknown child: keep waiting');
    });

    test('an idle child settles the turn after the grace period', () {
      final fresh = _call(callId: 'a', createdAt: _now - 1000);
      final stale = _call(callId: 'a', createdAt: _now - 600000);
      expect(open(fresh, _session()), isTrue);
      expect(open(stale, _session()), isFalse);
    });

    test('archived children and superseded turns never stay open', () {
      final call = _call(callId: 'a', createdAt: _now - 1000);
      expect(
        open(call, _session(archived: true, presence: 'offline')),
        isFalse,
      );
      expect(open(call, _session(thinking: true), sup: true), isFalse);
    });

    test('a result closes the turn', () {
      final done = _call(callId: 'a', state: 'completed', result: 'ok');
      expect(open(done, _session(thinking: true)), isFalse);
    });
  });

  group('agent rows', () {
    ({
      List<Map<String, dynamic>> rows,
      SubSessionRowCounts counts,
      int signature,
    })
    build(List<Map<String, dynamic>> calls, Map<String, Session> sessions) =>
        buildSubSessionAgentRows(
          calls,
          lookup: (id) => sessions[id],
          titleOf: (s) => s.metadata?.summary?.text ?? s.id,
          nowMs: _now,
        );

    test('one row per child, from its latest turn', () {
      final spawn = _call(
        callId: 'a',
        seq: 1,
        state: 'completed',
        result: 'First',
      );
      final followUp = _call(callId: 'b', seq: 2, description: 'Now docs');
      final built = build(
        [spawn, followUp],
        {'child-1': _session(thinking: true, summary: 'Flaky test fix')},
      );

      expect(built.rows, hasLength(1));
      final row = built.rows.single;
      expect(row['toolUseId'], 'b');
      expect(row['state'], 'running');
      expect(row[subSessionChildIdField], 'child-1');
      expect(row[subSessionChildStateField], 'working');
      expect(row[subSessionTurnCountField], 2);
      expect(row[subSessionTitleField], 'Flaky test fix');
      expect(built.counts.running, 1);
      expect(subSessionAgentChildId(row), 'child-1');
    });

    test('a missing result does not count as running once idle', () {
      final call = _call(callId: 'a', createdAt: _now - 600000);
      final built = build([call], {'child-1': _session()});
      expect(built.rows.single['state'], 'completed');
      expect(built.counts.running, 0);
      expect(built.counts.completed, 1);
    });

    test('failed and unknown outcomes count as errors', () {
      final built = build([
        _call(callId: 'a', state: 'error'),
        _call(
          callId: 'b',
          childId: 'child-2',
          state: 'completed',
          resultStatus: 'unknown',
        ),
      ], const {});
      expect(built.counts.error, 2);
      expect(
        built.rows.map((r) => r[subSessionChildStateField]),
        everyElement('notLoaded'),
      );
    });

    test('signature changes when the child state changes', () {
      final calls = [_call(callId: 'a')];
      final working = build(calls, {'child-1': _session(thinking: true)});
      final archived = build(calls, {
        'child-1': _session(archived: true, presence: 'offline'),
      });
      expect(working.signature, isNot(archived.signature));
    });
  });

  group('transcript projection', () {
    test('sub-sessions are not counted as in-process agents', () {
      final projection = AgentsListSheet.computeTranscriptProjection([
        _call(callId: 'a'),
        {
          'id': 'task-1',
          'toolUseId': 'task-1',
          'kind': 'tool-call',
          'name': 'Agent',
          'state': 'running',
          'input': {'subagent_type': 'Explore', 'description': 'Look'},
        },
      ]);
      expect(projection.agents.map((a) => a['id']), ['task-1']);
      expect(projection.progress.total, 1);
      expect(projection.subSessionCalls.map((c) => c['toolUseId']), ['a']);
      expect(projection.hasSubSessions, isTrue);
    });

    test('routes sub-session rows to the child chat', () {
      final row = _call(callId: 'a');
      expect(
        AgentsListSheet.routeForAgent('parent', row, 'msg-a'),
        '/chat/child-1',
      );
      final inProcess = {
        'id': 'task-1',
        'kind': 'tool-call',
        'name': 'Agent',
        'input': {'subagent_type': 'Explore'},
      };
      expect(
        AgentsListSheet.routeForAgent('parent', inProcess, 'task-1'),
        '/chat/parent/agent/task-1',
      );
    });
  });

  group('sidechain grouping', () {
    test('a spawn never adopts rows that share its prompt', () {
      final spawn = _call(callId: 'a');
      final sidechain = <String, dynamic>{
        'id': 'side-1',
        'kind': 'text',
        'isSidechain': true,
        'uuid': 'side-1',
        'parentUuid': 'msg-a',
        'content': 'unrelated',
      };
      final grouped = SidechainGrouper().groupMessages([spawn, sidechain]);
      final messages = grouped?.messages ?? [spawn, sidechain];
      expect(messages.map((m) => m['id']), contains('side-1'));
      expect(spawn['children'], isNull);
    });
  });
}
