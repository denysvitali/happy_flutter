import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

Machine _machine({
  required String id,
  required bool online,
  String? version = '1.0.0',
  int metadataVersion = 1,
  int daemonStateVersion = 1,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Machine(
    id: id,
    seq: 1,
    createdAt: now,
    updatedAt: now,
    active: online,
    activeAt: now,
    metadataVersion: metadataVersion,
    daemonStateVersion: daemonStateVersion,
    metadata: MachineMetadata(happyCliVersion: version),
  );
}

Session _session({
  required String id,
  required String machineId,
  String presence = 'online',
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Session(
    id: id,
    seq: 1,
    createdAt: now,
    updatedAt: now,
    active: true,
    activeAt: now,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: presence,
    metadata: Metadata(machineId: machineId),
  );
}

Map<String, dynamic> _manifest(String scope) => <String, dynamic>{
  'scope': scope,
  'protocolVersion': 2,
  'methods': const <String>['mcp-list'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Sync sync;

  setUp(() {
    sync = createTestSync();
    sync.testMachines.clear();
    sync.testSessions.clear();
    sync.testResetRpcCapabilitiesPolicy();
  });

  tearDown(() {
    sync.testRpcCapabilitiesOverride = null;
    sync.testResetRpcCapabilitiesPolicy();
  });

  test(
    'concurrent machine capability checks share one transport probe',
    () async {
      sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: true);
      final response = Completer<dynamic>();
      var calls = 0;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) {
        calls++;
        expect(scope, 'machine');
        expect(id, 'machine-1');
        return response.future;
      };

      final first = sync.machineCapabilities('machine-1');
      final second = sync.machineCapabilities('machine-1');
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
      response.complete(_manifest('machine'));
      expect(await first, isNotNull);
      expect(await second, isNotNull);
    },
  );

  test('capability probes use a short bounded deadline', () async {
    sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: true);
    Duration? observedTimeout;
    sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
      observedTimeout = timeout;
      return _manifest(scope);
    };

    await sync.machineCapabilities('machine-1');

    expect(observedTimeout, const Duration(seconds: 4));
  });

  test('the deadline bounds a stalled transport and starts backoff', () async {
    sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: true);
    sync.testRpcCapabilityProbeTimeout = const Duration(milliseconds: 1);
    final response = Completer<dynamic>();
    var calls = 0;
    sync.testRpcCapabilitiesOverride = (scope, id, timeout) {
      calls++;
      return response.future;
    };

    expect(await sync.machineCapabilities('machine-1'), isNull);
    expect(await sync.machineCapabilities('machine-1'), isNull);

    expect(calls, 1);
  });

  test(
    'a late timed-out result cannot repopulate a stale version cache',
    () async {
      sync.testMachines['machine-1'] = _machine(
        id: 'machine-1',
        online: true,
        version: '1.0.0',
      );
      sync.testRpcCapabilityProbeTimeout = const Duration(milliseconds: 1);
      final staleResponse = Completer<dynamic>();
      var calls = 0;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) {
        calls++;
        if (calls == 1) return staleResponse.future;
        return Future<dynamic>.value(_manifest(scope));
      };

      expect(await sync.machineCapabilities('machine-1'), isNull);
      sync.testRpcCapabilityProbeTimeout = const Duration(seconds: 1);
      sync.testMachines['machine-1'] = _machine(
        id: 'machine-1',
        online: true,
        version: '1.1.0',
      );
      expect(await sync.machineCapabilities('machine-1'), isNotNull);

      staleResponse.complete(_manifest('machine'));
      await Future<void>.delayed(Duration.zero);
      sync.testMachines['machine-1'] = _machine(
        id: 'machine-1',
        online: true,
        version: '1.0.0',
      );
      expect(await sync.machineCapabilities('machine-1'), isNotNull);
      expect(calls, 3);
    },
  );

  test(
    'a daemon upgrade does not share or accept an older in-flight probe',
    () async {
      sync.testMachines['machine-1'] = _machine(
        id: 'machine-1',
        online: true,
        version: '1.0.0',
      );
      final staleResponse = Completer<dynamic>();
      var calls = 0;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) {
        calls++;
        if (calls == 1) return staleResponse.future;
        return Future<dynamic>.value(_manifest(scope));
      };

      final staleProbe = sync.machineCapabilities('machine-1');
      await Future<void>.delayed(Duration.zero);
      sync.testMachines['machine-1'] = _machine(
        id: 'machine-1',
        online: true,
        version: '1.1.0',
      );
      expect(await sync.machineCapabilities('machine-1'), isNotNull);

      staleResponse.complete(_manifest('machine'));
      expect(await staleProbe, isNull);
      expect(await sync.machineCapabilities('machine-1'), isNotNull);
      expect(calls, 2);
    },
  );

  test(
    'policy reset rejects an in-flight result from the previous user',
    () async {
      sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: true);
      final staleResponse = Completer<dynamic>();
      var calls = 0;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) {
        calls++;
        return staleResponse.future;
      };

      final staleProbe = sync.machineCapabilities('machine-1');
      await Future<void>.delayed(Duration.zero);
      sync.testResetRpcCapabilitiesPolicy();
      staleResponse.complete(_manifest('machine'));
      expect(await staleProbe, isNull);

      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
        calls++;
        return _manifest(scope);
      };
      expect(await sync.machineCapabilities('machine-1'), isNotNull);
      expect(calls, 2);
    },
  );

  test('known-offline machine skips the capability transport', () async {
    sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: false);
    var calls = 0;
    sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
      calls++;
      return _manifest(scope);
    };

    expect(await sync.machineCapabilities('machine-1'), isNull);
    expect(calls, 0);
  });

  test(
    'session on a known-offline machine skips capability transport',
    () async {
      sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: false);
      sync.testSessions['session-1'] = _session(
        id: 'session-1',
        machineId: 'machine-1',
      );
      var calls = 0;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
        calls++;
        return _manifest(scope);
      };

      expect(await sync.sessionCapabilities('session-1'), isNull);
      expect(calls, 0);
    },
  );

  test(
    'offline session presence alone does not skip capability transport',
    () async {
      sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: true);
      sync.testSessions['session-1'] = _session(
        id: 'session-1',
        machineId: 'machine-1',
        presence: 'offline',
      );
      var calls = 0;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
        calls++;
        return _manifest(scope);
      };

      expect(await sync.sessionCapabilities('session-1'), isNotNull);
      expect(calls, 1);
    },
  );

  test(
    'typed feature gates fail fast for a definitively offline machine',
    () async {
      sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: false);
      sync.testSessions['session-1'] = _session(
        id: 'session-1',
        machineId: 'machine-1',
      );
      var calls = 0;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
        calls++;
        return _manifest(scope);
      };

      await expectLater(
        sync.ensureMachineRPCSupported('machine-1', 'mcp-list'),
        throwsA(
          isA<RpcException>()
              .having(
                (error) => error.code,
                'code',
                RpcErrorCode.handlerOffline,
              )
              .having((error) => error.retryable, 'retryable', isTrue)
              .having((error) => error.scope, 'scope', 'machine-1')
              .having((error) => error.method, 'method', 'mcp-list'),
        ),
      );
      await expectLater(
        sync.ensureSessionRPCSupported('session-1', 'mcp-list'),
        throwsA(
          isA<RpcException>()
              .having(
                (error) => error.code,
                'code',
                RpcErrorCode.handlerOffline,
              )
              .having((error) => error.retryable, 'retryable', isTrue)
              .having((error) => error.scope, 'scope', 'session-1')
              .having((error) => error.method, 'method', 'mcp-list'),
        ),
      );
      expect(calls, 0);
    },
  );

  test('transient failure backs off across socket generations', () async {
    sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: true);
    var calls = 0;
    sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
      calls++;
      throw const SocketAckTimeoutException('rpc-call');
    };

    expect(await sync.machineCapabilities('machine-1'), isNull);
    socketIoClient.disconnect(preserveConnectionHistory: true);
    expect(await sync.machineCapabilities('machine-1'), isNull);

    expect(calls, 1);
  });

  test('daemon version change bypasses negative capability backoff', () async {
    sync.testMachines['machine-1'] = _machine(
      id: 'machine-1',
      online: true,
      version: '1.0.0',
    );
    var calls = 0;
    sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
      calls++;
      if (calls == 1) {
        throw const SocketAckTimeoutException('rpc-call');
      }
      return _manifest(scope);
    };

    expect(await sync.machineCapabilities('machine-1'), isNull);
    sync.testMachines['machine-1'] = _machine(
      id: 'machine-1',
      online: true,
      version: '1.1.0',
    );

    expect(await sync.machineCapabilities('machine-1'), isNotNull);
    expect(calls, 2);
  });

  test(
    'unversioned daemon state changes do not bypass negative backoff',
    () async {
      sync.testMachines['machine-1'] = _machine(
        id: 'machine-1',
        online: true,
        version: null,
      );
      var calls = 0;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
        calls++;
        throw const SocketAckTimeoutException('rpc-call');
      };

      expect(await sync.machineCapabilities('machine-1'), isNull);
      sync.testMachines['machine-1'] = _machine(
        id: 'machine-1',
        online: true,
        version: null,
        metadataVersion: 2,
        daemonStateVersion: 4,
      );

      expect(await sync.machineCapabilities('machine-1'), isNull);
      expect(calls, 1);
    },
  );

  test(
    'transient backoff expires and escalates after repeated failures',
    () async {
      sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: true);
      var nowMs = 1000;
      var calls = 0;
      sync.testRpcCapabilityNowMs = () => nowMs;
      sync.testRpcCapabilityTransientBackoffBase = const Duration(seconds: 10);
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
        calls++;
        if (calls < 3) {
          throw const SocketAckTimeoutException('rpc-call');
        }
        return _manifest(scope);
      };

      expect(await sync.machineCapabilities('machine-1'), isNull);
      nowMs += const Duration(seconds: 10).inMilliseconds;
      expect(await sync.machineCapabilities('machine-1'), isNull);
      nowMs += const Duration(seconds: 10).inMilliseconds;
      expect(await sync.machineCapabilities('machine-1'), isNull);
      expect(calls, 2);
      nowMs += const Duration(seconds: 10).inMilliseconds;
      expect(await sync.machineCapabilities('machine-1'), isNotNull);
      expect(calls, 3);
    },
  );

  test(
    'legacy daemon stays optimistic during a bounded negative TTL',
    () async {
      sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: true);
      var calls = 0;
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
        calls++;
        throw const RpcException(
          code: RpcErrorCode.methodUnsupported,
          message: 'unknown method',
          retryable: false,
        );
      };

      expect(await sync.machineSupportsRPC('machine-1', 'mcp-list'), isNull);
      socketIoClient.disconnect(preserveConnectionHistory: true);
      expect(await sync.machineSupportsRPC('machine-1', 'mcp-list'), isNull);
      await expectLater(
        sync.ensureMachineRPCSupported('machine-1', 'mcp-list'),
        completes,
      );

      expect(calls, 1);
    },
  );

  test(
    'legacy negative expires and re-probes the capability handler',
    () async {
      sync.testMachines['machine-1'] = _machine(id: 'machine-1', online: true);
      var nowMs = 1000;
      var calls = 0;
      sync.testRpcCapabilityNowMs = () => nowMs;
      sync.testRpcCapabilityLegacyTtl = const Duration(minutes: 5);
      sync.testRpcCapabilitiesOverride = (scope, id, timeout) async {
        calls++;
        if (calls == 1) {
          throw const RpcException(
            code: RpcErrorCode.methodUnsupported,
            message: 'unknown method',
            retryable: false,
          );
        }
        return _manifest(scope);
      };

      expect(await sync.machineCapabilities('machine-1'), isNull);
      nowMs += const Duration(minutes: 5).inMilliseconds - 1;
      expect(await sync.machineCapabilities('machine-1'), isNull);
      expect(calls, 1);
      nowMs++;
      expect(await sync.machineCapabilities('machine-1'), isNotNull);
      expect(calls, 2);
    },
  );
}
