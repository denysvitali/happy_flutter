import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

void main() {
  test('discovery RPCs that start provider CLIs get a 10 s SLOW bar', () {
    expect(Sync.slowMachineRpcThresholdMs('get-codex-models'), 10000);
    expect(Sync.slowMachineRpcThresholdMs('get-provider-versions'), 10000);
  });

  test('liveness and control RPCs keep the 2 s SLOW bar', () {
    expect(Sync.slowMachineRpcThresholdMs('ping'), 2000);
    expect(Sync.slowMachineRpcThresholdMs('rpc-capabilities'), 2000);
    expect(Sync.slowMachineRpcThresholdMs('spawn-happy-session'), 2000);
  });
}
