import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/api/retry_interceptor.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  late Sync sync;
  late DioException failure;

  setUp(() async {
    sync = createTestSync()..testIsInitialized = true;
    sync.testMachines.clear();
    await ApiClient().initialize(serverUrl: 'http://localhost');
    ApiClient().testDio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(failure),
      ),
    );
    LoggerService().clear();
  });

  tearDown(() {
    ApiClient().dispose();
    sync.testMachines.clear();
    sync.testIsInitialized = false;
  });

  for (final hasCachedMachine in [false, true]) {
    test('canceled machine fetch preserves cache and propagates cancellation '
        '(cached=$hasCachedMachine)', () async {
      const machine = Machine(
        id: 'cached-machine',
        seq: 1,
        createdAt: 1,
        updatedAt: 1,
        active: true,
        activeAt: 1,
        metadataVersion: 0,
        daemonStateVersion: 0,
      );
      if (hasCachedMachine) sync.testMachines[machine.id] = machine;
      failure = DioException(
        requestOptions: RequestOptions(path: '/v1/machines'),
        type: DioExceptionType.cancel,
        error: HttpCancellationReason.appSuspended,
      );

      // A canceled refresh must not resolve as an authoritative empty fetch
      // or mark the retry manager's current attempt successful.
      await expectLater(sync.fetchMachines(), throwsA(same(failure)));

      expect(sync.machines, hasCachedMachine ? {machine.id: machine} : isEmpty);
      final logs = LoggerService().getLogs();
      expect(
        logs.where((entry) => entry.message == 'Error fetching machines'),
        isEmpty,
      );
      expect(
        logs.where(
          (entry) =>
              entry.level == LogLevel.info &&
              entry.message == 'fetchMachines: request canceled',
        ),
        hasLength(1),
      );
    });
  }

  test('non-cancellation machine failures remain errors', () async {
    failure = DioException(
      requestOptions: RequestOptions(path: '/v1/machines'),
      error: StateError('Unexpected machine response'),
    );

    await expectLater(sync.fetchMachines(), throwsA(same(failure)));

    expect(
      LoggerService().getLogs().where(
        (entry) =>
            entry.level == LogLevel.error &&
            entry.message == 'Error fetching machines',
      ),
      hasLength(1),
    );
  });

  test('deadline cancellation remains an error', () async {
    failure = DioException(
      requestOptions: RequestOptions(path: '/v1/machines'),
      type: DioExceptionType.cancel,
      error: 'Request deadline exceeded',
    );

    await expectLater(sync.fetchMachines(), throwsA(same(failure)));

    expect(
      LoggerService().getLogs().where(
        (entry) =>
            entry.level == LogLevel.error &&
            entry.message == 'Error fetching machines',
      ),
      hasLength(1),
    );
  });
}
