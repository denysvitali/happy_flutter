import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/workflow_run.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

class _FakeEncryption implements Encryption {
  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      const _FakeSessionEncryption();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionEncryption implements SessionEncryption {
  const _FakeSessionEncryption();

  @override
  bool get canDecryptAes => true;

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async => const ProcessedMessages(
    messages: [],
    toolResults: [],
    usageUpdates: [],
    maxSeq: 0,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Session _session({
  required String id,
  required int activeAt,
  String presence = 'online',
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 0,
    updatedAt: activeAt,
    active: true,
    activeAt: activeAt,
    metadataVersion: 0,
    agentStateVersion: 0,
    thinking: false,
    presence: presence,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Sync sync;

  setUp(() {
    sync = createTestSync();
    sync.testSessions.clear();
    sync.testClearAllWorkflows();
    sync.testResetWorkflowRefreshPolicy();
    sync.testIsInitialized = true;
    sync.testSocketConnectedOverride = true;
    sync.encryption = _FakeEncryption();
  });

  tearDown(() {
    sync.testSessionRPCOverride = null;
    sync.testSocketConnectedOverride = null;
    sync.testSetVisibleSessionId(null);
    sync.testResetWorkflowRefreshPolicy();
    sync.testIsInitialized = false;
  });

  test(
    'bulk refresh targets visible then three most-recent online sessions',
    () {
      sync.testSessions.addAll({
        'old-online': _session(id: 'old-online', activeAt: 10),
        'newest': _session(id: 'newest', activeAt: 50),
        'visible-offline': _session(
          id: 'visible-offline',
          activeAt: 5,
          presence: 'offline',
        ),
        'middle': _session(id: 'middle', activeAt: 30),
        'newer': _session(id: 'newer', activeAt: 40),
        'offline': _session(id: 'offline', activeAt: 100, presence: 'offline'),
      });
      sync.testSetVisibleSessionId('visible-offline');

      expect(sync.testWorkflowRefreshCandidates(), [
        'visible-offline',
        'newest',
        'newer',
        'middle',
      ]);
    },
  );

  test('concurrent per-session refreshes share one RPC', () async {
    sync.testSessions['s1'] = _session(id: 's1', activeAt: 1);
    final response = Completer<dynamic>();
    var calls = 0;
    sync.testSessionRPCOverride = (sessionId, method, params) {
      calls++;
      return response.future;
    };

    final first = sync.refreshWorkflowsForSession('s1');
    final second = sync.refreshWorkflowsForSession('s1');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);

    response.complete({'ok': true, 'workflows': <dynamic>[]});
    await Future.wait([first, second]);
  });

  test('concurrent snapshot fetches share one RPC', () async {
    sync.testSessions['s1'] = _session(id: 's1', activeAt: 1);
    final response = Completer<dynamic>();
    var calls = 0;
    sync.testSessionRPCOverride = (sessionId, method, params) {
      calls++;
      return response.future;
    };

    final first = sync.fetchWorkflowSnapshot('s1', 'run-1');
    final second = sync.fetchWorkflowSnapshot('s1', 'run-1');
    expect(first, same(second));
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);

    response.complete({
      'ok': true,
      'snapshot': <String, dynamic>{
        'runId': 'run-1',
        'workflowName': 'Audit',
        'status': WorkflowStatus.running,
      },
    });
    final snapshots = await Future.wait([first, second]);

    expect(snapshots[0], same(snapshots[1]));
  });

  test('unchanged list refresh does not publish a workflow change', () async {
    sync.testSessions['s1'] = _session(id: 's1', activeAt: 1);
    const cached = WorkflowRun(
      runId: 'run-1',
      workflowName: 'Audit',
      status: WorkflowStatus.running,
    );
    sync.testSetWorkflows('s1', const <WorkflowRun>[cached]);
    sync.testSessionRPCOverride = (sessionId, method, params) async =>
        <String, dynamic>{
          'ok': true,
          'workflows': <dynamic>[cached.toJson()],
        };
    var changeEvents = 0;
    final subscription = sync.onWorkflowsChanged.listen((_) => changeEvents++);
    addTearDown(subscription.cancel);

    await sync.refreshWorkflowsForSession('s1');
    await Future<void>.delayed(Duration.zero);

    expect(changeEvents, 0);
    expect(sync.workflowsForSession('s1').single, same(cached));
  });

  test(
    'unsupported workflow RPC is remembered for the session capability',
    () async {
      sync.testSessions['s1'] = _session(id: 's1', activeAt: 1);
      var calls = 0;
      sync.testSessionRPCOverride = (sessionId, method, params) async {
        calls++;
        throw StateError('RPC method workflow-list not available');
      };

      await sync.refreshWorkflowsForSession('s1');
      await sync.refreshWorkflowsForSession('s1');

      expect(calls, 1);
      expect(sync.testIsWorkflowRefreshCapabilityBlocked('s1'), isTrue);
    },
  );

  test(
    'schema-skewed workflow response preserves last-known-good runs',
    () async {
      sync.testSessions['s1'] = _session(id: 's1', activeAt: 1);
      const cached = WorkflowRun(
        runId: 'run-1',
        workflowName: 'Audit',
        status: WorkflowStatus.running,
      );
      sync.testSetWorkflows('s1', const <WorkflowRun>[cached]);
      sync.testSessionRPCOverride = (sessionId, method, params) async =>
          <String, dynamic>{'ok': true, 'renamedRuns': <dynamic>[]};

      await sync.refreshWorkflowsForSession('s1');

      expect(sync.workflowsForSession('s1'), const <WorkflowRun>[cached]);
    },
  );
}
