// Send-path latency regressions from production Jaeger traces.
//
// 7b3dad3f…: an auto-restore spent 3.2s on the spawn readiness ping, then a
// 4s capability-probe timeout, strictly in sequence, before dispatching the
// spawn. The two pre-flights are independent and idempotent, so they now
// run concurrently; a failed ping still prevents the spawn.
//
// 7295dbbc…: a resumed send respawned a live process (presence went stale
// in the background) and then waited 10.1s for the next server alive-batch.
// A manifest answered by the session's own process is direct liveness proof.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

Machine _machine(String id) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Machine(
    id: id,
    seq: 1,
    createdAt: now,
    updatedAt: now,
    active: true,
    activeAt: now,
    metadataVersion: 1,
    daemonStateVersion: 1,
    metadata: const MachineMetadata(happyCliVersion: '1.0.0'),
  );
}

Session _session(
  String id, {
  String presence = 'offline',
  String lifecycleState = 'running',
  bool archived = false,
}) => Session(
  id: id,
  seq: 1,
  createdAt: 0,
  updatedAt: 0,
  active: true,
  activeAt: 0,
  archived: archived,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: false,
  presence: presence,
  metadata: Metadata(
    host: '',
    machineId: 'machine-1',
    path: '/project',
    lifecycleState: lifecycleState,
    // Stale: a long-idle running process, as after a resume.
    lifecycleStateSince: 1,
  ),
);

Map<String, dynamic> _manifest(String scope, List<String> methods) =>
    <String, dynamic>{'scope': scope, 'protocolVersion': 2, 'methods': methods};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Sync sync;

  setUp(() {
    sync = createTestSync();
    sync.testMachines.clear();
    sync.testSessions.clear();
    sync.testResetRpcCapabilitiesPolicy();
    sync.testMachines['machine-1'] = _machine('machine-1');
    sync.testIsInitialized = true;
  });

  tearDown(() {
    sync.testRpcCapabilitiesOverride = null;
    sync.testEnsureMachineReachableOverride = null;
    sync.testSessionRPCOverride = null;
    sync.testRpcCapabilityProbeTimeout = null;
    sync.testResetRpcCapabilitiesPolicy();
  });

  group('spawn pre-flight', () {
    test('ping and capability probe overlap: cost is max, not sum', () {
      fakeAsync((async) {
        var capabilityStartedDuringPing = false;
        var pingDone = false;
        sync.testEnsureMachineReachableOverride = (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 3200));
          pingDone = true;
        };
        sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
          capabilityStartedDuringPing = !pingDone;
          await Future<void>.delayed(const Duration(seconds: 4));
          throw TimeoutException('ack');
        };

        var done = false;
        Object? failure;
        sync
            .testMachineRpcPreflight('machine-1', 'spawn-happy-session')
            .then(
              (_) {
                done = true;
              },
              onError: (Object e) {
                failure = e;
              },
            );

        async.elapse(const Duration(milliseconds: 4100));
        expect(failure, isNull);
        expect(capabilityStartedDuringPing, isTrue);
        // Sequential pre-flights would need 7.2s here.
        expect(done, isTrue);
      });
    });

    test('a failed ping still blocks the spawn even with a manifest', () {
      fakeAsync((async) {
        sync.testEnsureMachineReachableOverride = (_) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          throw StateError('Machine is unreachable');
        };
        sync.testRpcCapabilitiesOverride = (scope, id, timeout) async =>
            _manifest(scope, const ['spawn-happy-session']);

        Object? failure;
        sync
            .testMachineRpcPreflight('machine-1', 'spawn-happy-session')
            .then(
              (_) {},
              onError: (Object e) {
                failure = e;
              },
            );
        async.elapse(const Duration(seconds: 2));

        expect(failure, isA<StateError>());
      });
    });

    test('ping failure with a failing manifest check reports the ping and '
        'leaves no unhandled error', () async {
      sync.testEnsureMachineReachableOverride = (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        throw StateError('Machine is unreachable');
      };
      // An advertised manifest without the method fails the check first.
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async =>
          _manifest(scope, const <String>[]);

      await expectLater(
        sync.testMachineRpcPreflight('machine-1', 'spawn-happy-session'),
        throwsA(isA<StateError>()),
      );
    });

    test('an advertised manifest without the method still rejects it', () {
      sync.testEnsureMachineReachableOverride = (_) async {};
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async =>
          _manifest(scope, const <String>['ping']);

      expect(
        sync.testMachineRpcPreflight('machine-1', 'spawn-happy-session'),
        throwsA(
          isA<RpcException>().having(
            (e) => e.code,
            'code',
            RpcErrorCode.methodUnsupported,
          ),
        ),
      );
    });

    test('non-spawn methods never ping', () async {
      var pings = 0;
      sync.testEnsureMachineReachableOverride = (_) async => pings++;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async =>
          _manifest(scope, const <String>['mcp-list']);

      await sync.testMachineRpcPreflight('machine-1', 'mcp-list');

      expect(pings, 0);
    });
  });

  group('session liveness confirmation', () {
    test('a manifest from the session process marks it ready', () async {
      sync.testSessions['s1'] = _session('s1');
      final calls = <String>[];
      sync.testSessionRPCOverride = (sessionId, method, params) async {
        calls.add('$sessionId:$method');
        return _manifest('session', const <String>['abort']);
      };
      expect(sync.isSessionReadyForMessages('s1'), isFalse);

      expect(await sync.testConfirmSessionLiveness('s1'), isTrue);

      expect(calls, ['s1:rpc-capabilities']);
      expect(sync.isSessionReadyForMessages('s1'), isTrue);
    });

    test(
      'waitForAgentReady resolves as soon as liveness is confirmed',
      () async {
        // Real timers: the shared singleton's domain debounce timers live in
        // the root zone, so fake time cannot release their trailing events.
        sync.testSessions['s1'] = _session('s1');
        sync.testSessionRPCOverride = (_, _, _) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return _manifest('session', const <String>[]);
        };
        final clock = Stopwatch()..start();
        final ready = sync.waitForAgentReady('s1', 15000);
        unawaited(sync.testConfirmSessionLiveness('s1'));

        expect(await ready, isTrue);
        // Far below the 10s alive-batch wait seen in production.
        expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
      },
    );

    for (final entry in <String, Object>{
      'handler offline': const RpcException(
        code: RpcErrorCode.handlerOffline,
        message: 'not registered',
        retryable: true,
      ),
      'ack timeout': TimeoutException('ack'),
    }.entries) {
      test('${entry.key} proves nothing', () async {
        sync.testSessions['s1'] = _session('s1');
        sync.testSessionRPCOverride = (_, _, _) async => throw entry.value;

        expect(await sync.testConfirmSessionLiveness('s1'), isFalse);
        expect(sync.isSessionReadyForMessages('s1'), isFalse);
      });
    }

    test('a non-manifest reply proves nothing', () async {
      sync.testSessions['s1'] = _session('s1');
      sync.testSessionRPCOverride = (_, _, _) async => {'ok': true};

      expect(await sync.testConfirmSessionLiveness('s1'), isFalse);
      expect(sync.isSessionReadyForMessages('s1'), isFalse);
    });

    test('a terminally errored session is never revived by a reply', () async {
      sync.testSessions['s1'] = _session('s1', lifecycleState: 'errored');
      sync.testSessionRPCOverride = (_, _, _) async =>
          _manifest('session', const <String>[]);

      expect(await sync.testConfirmSessionLiveness('s1'), isFalse);
      expect(sync.isSessionReadyForMessages('s1'), isFalse);
    });

    test('a runtime reset during the probe discards the reply', () async {
      sync.testSessions['s1'] = _session('s1');
      final reply = Completer<dynamic>();
      sync.testSessionRPCOverride = (_, _, _) => reply.future;

      final pending = sync.testConfirmSessionLiveness('s1');
      sync.testAdvanceRuntimeGeneration();
      reply.complete(_manifest('session', const <String>[]));

      expect(await pending, isFalse);
      expect(sync.isSessionReadyForMessages('s1'), isFalse);
    });
  });
}
