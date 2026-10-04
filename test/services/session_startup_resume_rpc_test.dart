import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/rpc/rpc_exception.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

void main() {
  final sync = Sync();

  tearDown(() {
    sync.testMachineRPCOverride = null;
    InvalidateSync.isBackgrounded = false;
  });

  test('confirmed startup-resume write survives backgrounding', () async {
    var calls = 0;
    sync.testMachineRPCOverride = (_, method, __) async {
      expect(method, 'session-startup-resume-set');
      calls++;
      InvalidateSync.isBackgrounded = true;
      return {'ok': true};
    };
    await sync.machineSetSessionStartupResume(
      machineId: 'machine-1',
      sessionId: 'session-1',
      enabled: true,
      message: 'continue',
    );
    expect(calls, 1);
  });

  test(
    'retries an offline handler with the exact same configuration',
    () async {
      final payloads = <Map<String, dynamic>>[];
      sync.testMachineRPCOverride = (_, method, params) async {
        expect(method, 'session-startup-resume-set');
        payloads.add(Map<String, dynamic>.from(params));
        if (payloads.length == 1) {
          throw const RpcException(
            code: RpcErrorCode.handlerOffline,
            message: 'reconnecting',
            retryable: true,
          );
        }
        return {'ok': true};
      };
      await sync.machineSetSessionStartupResume(
        machineId: 'machine-1',
        sessionId: 'session-1',
        enabled: true,
        message: 'continue',
      );
      expect(payloads, hasLength(2));
      expect(payloads.first, payloads.last);
    },
  );

  test('never retries invalid configuration', () async {
    var calls = 0;
    sync.testMachineRPCOverride = (_, __, ___) async {
      calls++;
      throw const RpcException(
        code: RpcErrorCode.invalidRequest,
        message: 'invalid',
        retryable: false,
      );
    };
    await expectLater(
      sync.machineSetSessionStartupResume(
        machineId: 'machine-1',
        sessionId: 'session-1',
        enabled: true,
        message: 'continue',
      ),
      throwsA(isA<RpcException>()),
    );
    expect(calls, 1);
  });

  test('sends startup resume configuration to the owning daemon', () async {
    String? capturedMachineId;
    String? capturedMethod;
    Map<String, dynamic>? capturedParams;
    sync.testMachineRPCOverride = (machineId, method, params) async {
      capturedMachineId = machineId;
      capturedMethod = method;
      capturedParams = Map<String, dynamic>.from(params);
      return <String, dynamic>{'ok': true};
    };

    await sync.machineSetSessionStartupResume(
      machineId: 'machine-1',
      sessionId: 'session-1',
      enabled: true,
      message: 'continue',
    );

    expect(capturedMachineId, 'machine-1');
    expect(capturedMethod, 'session-startup-resume-set');
    expect(capturedParams, <String, dynamic>{
      'sessionId': 'session-1',
      'enabled': true,
      'message': 'continue',
    });
  });
}
