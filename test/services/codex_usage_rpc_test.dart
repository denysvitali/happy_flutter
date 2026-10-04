import 'dart:async';
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

  test(
    'transient usage failure retries only the idempotent usage RPC',
    () async {
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
      expect(methods, ['get-codex-usage', 'get-codex-usage']);
    },
  );

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
      expect(methods, ['get-codex-usage', 'get-codex-usage']);
    },
  );

  test(
    'usage recovers when the handler registers after the first call',
    () async {
      final methods = <String>[];
      sync.testMachineRPCOverride = (_, method, __) async {
        methods.add(method);
        if (methods.length == 1) {
          throw const RpcException(
            code: RpcErrorCode.handlerOffline,
            message: 'reconnecting',
            retryable: true,
          );
        }
        return {'success': false, 'error': 'No credentials'};
      };
      final response = await sync.machineGetCodexUsage(machineId: 'machine-1');
      expect(response.error, 'No credentials');
      expect(methods, ['get-codex-usage', 'get-codex-usage']);
    },
  );

  test('late unsupported usage cannot launch Bash while suspended', () async {
    final pending = Completer<Map<String, dynamic>>();
    final methods = <String>[];
    sync.testMachineRPCOverride = (_, method, __) {
      methods.add(method);
      return pending.future;
    };
    final request = sync.machineGetCodexUsage(machineId: 'machine-1');
    InvalidateSync.isBackgrounded = true;
    pending.completeError(
      const RpcException(
        code: RpcErrorCode.methodUnsupported,
        message: 'unsupported',
        retryable: false,
      ),
    );
    final response = await request;
    expect(response.success, isFalse);
    expect(response.error, 'machine offline');
    expect(methods, ['get-codex-usage']);
  });

  test('late usage response cannot cross a runtime/cache reset', () async {
    final pending = Completer<Map<String, dynamic>>();
    sync.testMachineRPCOverride = (_, __, ___) => pending.future;
    final first = sync.machineGetCodexUsage(machineId: 'machine-1');
    sync.testClearCodexModelsCache();
    pending.complete({'success': false, 'error': 'old-account'});
    expect((await first).error, contains('context changed'));
  });

  test('legacy missing handler errors do not invoke Bash fallback', () async {
    final methods = <String>[];
    sync.testMachineRPCOverride = (_, method, __) async {
      methods.add(method);
      throw StateError('RPC handler is not registered');
    };
    final result = await sync.machineGetCodexUsage(machineId: 'machine-1');
    expect(result.success, isFalse);
    expect(methods, ['get-codex-usage']);
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
