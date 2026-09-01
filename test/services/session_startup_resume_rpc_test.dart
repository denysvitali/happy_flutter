import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

void main() {
  final sync = Sync();

  tearDown(() {
    sync.testMachineRPCOverride = null;
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
