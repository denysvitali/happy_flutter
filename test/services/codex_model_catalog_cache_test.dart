import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/rpc/rpc_exception.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

Map<String, dynamic> _catalog(String slug) => <String, dynamic>{
  'success': true,
  'models': <Map<String, dynamic>>[
    <String, dynamic>{
      'slug': slug,
      'displayName': slug,
      'supportedReasoningEfforts': <String>['medium'],
    },
  ],
};

void main() {
  final sync = Sync();

  setUp(sync.testClearCodexModelsCache);
  tearDown(() {
    sync.testMachineRPCOverride = null;
    sync.testClearCodexModelsCache();
  });

  test('reuses a successful machine catalog across chat refreshes', () async {
    var calls = 0;
    sync.testMachineRPCOverride = (machineId, method, params) async {
      calls++;
      return _catalog('gpt-5.6');
    };

    final first = await sync.machineGetCodexModels(machineId: 'machine-1');
    final second = await sync.machineGetCodexModels(machineId: 'machine-1');

    expect(first.success, isTrue);
    expect(second.models.single.slug, 'gpt-5.6');
    expect(calls, 1);
  });

  test('coalesces concurrent catalog requests for one machine', () async {
    var calls = 0;
    final response = Completer<Map<String, dynamic>>();
    sync.testMachineRPCOverride = (machineId, method, params) {
      calls++;
      return response.future;
    };

    final first = sync.machineGetCodexModels(machineId: 'machine-1');
    final second = sync.machineGetCodexModels(machineId: 'machine-1');
    response.complete(_catalog('gpt-5.6'));

    await Future.wait([first, second]);
    expect(calls, 1);
  });

  test('missing Codex is a cached unavailable capability', () async {
    var calls = 0;
    sync.testMachineRPCOverride = (machineId, method, params) async {
      calls++;
      throw const RpcException(
        code: RpcErrorCode.handlerError,
        message:
            'codex debug models: exec: "codex": '
            'executable file not found in \$PATH',
        retryable: false,
      );
    };
    LoggerService().clear();
    final first = await sync.machineGetCodexModels(machineId: 'machine-1');
    final second = await sync.machineGetCodexModels(machineId: 'machine-1');
    expect(first.providerUnavailable, isTrue);
    expect(second.providerUnavailable, isTrue);
    expect(first.error, contains('Install Codex'));
    expect(calls, 1);
    expect(
      LoggerService().getLogs().where(
        (entry) =>
            entry.level == LogLevel.error &&
            entry.message.contains('machineGetCodexModels'),
      ),
      isEmpty,
    );
    await sync.machineGetCodexModels(machineId: 'machine-2');
    expect(calls, 2, reason: 'Availability belongs to one machine');
    sync.testClearCodexModelsCache();
    sync.testMachineRPCOverride = (_, __, ___) async => _catalog('gpt-5.6');
    expect(
      (await sync.machineGetCodexModels(machineId: 'machine-1')).success,
      isTrue,
    );
  });

  // GlitchTip 8729/8748: the same "Codex is not installed" condition reaches
  // the client as RpcErrorCode.unknown, not handlerError, depending on how the
  // daemon surfaced it. The detector gated on the code, so both of those fell
  // through to the error logger and opened an issue for a machine that simply
  // has no Codex — while 8763, the handlerError shape, was handled correctly.
  test('missing Codex is unavailable however the daemon codes it', () async {
    for (final code in [RpcErrorCode.handlerError, RpcErrorCode.unknown]) {
      sync
        ..testClearCodexModelsCache()
        ..testMachineRPCOverride = (machineId, method, params) async {
          throw RpcException(
            code: code,
            message:
                'codex debug models: exec: "codex": '
                'executable file not found in \$PATH',
            retryable: false,
          );
        };
      LoggerService().clear();

      final response = await sync.machineGetCodexModels(
        machineId: 'machine-1',
      );

      expect(response.providerUnavailable, isTrue, reason: 'code=$code');
      expect(response.error, contains('Install Codex'), reason: 'code=$code');
      expect(
        LoggerService().getLogs().where(
          (entry) =>
              entry.level == LogLevel.error &&
              entry.message.contains('machineGetCodexModels'),
        ),
        isEmpty,
        reason: 'code=$code must not open an error issue',
      );
    }
  });

  test('daemon SIGKILL on get-codex-models is info, not error', () async {
    sync.testMachineRPCOverride = (machineId, method, params) async {
      throw const RpcException(
        code: RpcErrorCode.handlerError,
        message: 'codex debug models: signal: killed',
        retryable: false,
      );
    };
    LoggerService().clear();

    final response = await sync.machineGetCodexModels(machineId: 'machine-1');

    expect(response.success, isFalse);
    final logs = LoggerService().getLogs();
    expect(
      logs.where(
        (e) =>
            e.level == LogLevel.error &&
            e.message.contains('machineGetCodexModels'),
      ),
      isEmpty,
    );
    expect(
      logs.any(
        (e) =>
            e.level == LogLevel.info && e.message.contains('subprocess killed'),
      ),
      isTrue,
    );
  });
}
