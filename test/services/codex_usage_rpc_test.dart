import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/rpc/rpc_exception.dart';

void main() {
  final sync = Sync();
  tearDown(() {
    sync.testMachineRPCOverride = null;
  });

  test('transient usage failure does not launch a second Bash RPC', () async {
    final methods = <String>[];
    sync.testMachineRPCOverride = (_, method, __) async {
      methods.add(method);
      throw const RpcException(
        code: RpcErrorCode.forwardingFailed,
        message: 'routing unavailable',
        retryable: true,
      );
    };
    final result = await sync.machineGetCodexUsage(machineId: 'machine-1');
    expect(result.success, isFalse);
    expect(methods, ['get-codex-usage']);
  });

  test(
    'offline handler is not treated as an unsupported usage method',
    () async {
      final methods = <String>[];
      sync.testMachineRPCOverride = (_, method, __) async {
        methods.add(method);
        throw const RpcException(
          code: RpcErrorCode.handlerOffline,
          message: 'not registered',
          retryable: true,
        );
      };
      final result = await sync.machineGetCodexUsage(machineId: 'machine-1');
      expect(result.success, isFalse);
      expect(result.error, contains('unavailable'));
      expect(methods, ['get-codex-usage']);
    },
  );

  test('late usage response cannot cross a runtime/cache reset', () async {
    final pending = Completer<Map<String, dynamic>>();
    sync.testMachineRPCOverride = (_, __, ___) => pending.future;
    final first = sync.machineGetCodexUsage(machineId: 'machine-1');
    sync.testClearCodexModelsCache();
    pending.complete({'success': false, 'error': 'old-account'});
    expect((await first).error, contains('context changed'));
  });

  test('concurrent usage refreshes share a single daemon request', () async {
    var calls = 0;
    final pending = Completer<Map<String, dynamic>>();
    sync.testMachineRPCOverride = (_, __, ___) {
      calls++;
      return pending.future;
    };
    final first = sync.machineGetCodexUsage(machineId: 'machine-1');
    final second = sync.machineGetCodexUsage(machineId: 'machine-1');
    pending.complete({'success': false, 'error': 'No credentials'});
    await Future.wait([first, second]);
    expect(calls, 1);
  });
}
