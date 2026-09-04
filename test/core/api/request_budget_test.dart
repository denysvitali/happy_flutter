import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/retry_interceptor.dart';

class _Adapter implements HttpClientAdapter {
  final started = Completer<void>();
  final canceled = Completer<void>();
  final release = Completer<ResponseBody>();
  int calls = 0;
  bool failFirst = false;
  final localIds = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    localIds.add((options.data as Map?)?['localId']);
    if (!started.isCompleted) started.complete();
    cancelFuture?.then((_) {
      if (!canceled.isCompleted) canceled.complete();
    });
    if (failFirst && calls == 1)
      return Future.value(ResponseBody.fromString('', 503));
    return release.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late RetryInterceptor retry;
  late _Adapter adapter;
  setUp(() {
    dio = Dio(
      BaseOptions(baseUrl: 'https://test.invalid', validateStatus: (_) => true),
    );
    retry = RetryInterceptor(
      dioGetter: () => dio,
      maxTotalElapsedMs: 150,
      baseDelayMs: 20,
      maxDelayMs: 20,
    );
    dio.interceptors.add(retry);
    adapter = _Adapter();
    dio.httpClientAdapter = adapter;
  });
  tearDown(() {
    if (!adapter.release.isCompleted)
      adapter.release.complete(ResponseBody.fromString('', 200));
    dio.close(force: true);
  });

  final canceled = throwsA(
    isA<DioException>().having((e) => e.type, 'type', DioExceptionType.cancel),
  );

  test(
    'deadline cancels a hung adapter instead of waiting for its timeout',
    () async {
      final request = expectLater(dio.get<dynamic>('/v1/sessions'), canceled);
      await adapter.started.future;
      await request.timeout(const Duration(seconds: 2));
      await adapter.canceled.future;
      expect(adapter.calls, 1);
    },
  );

  test(
    'caller cancellation interrupts backoff without starting another attempt',
    () async {
      adapter.failFirst = true;
      final token = CancelToken();
      final request = expectLater(
        dio.get<dynamic>('/v1/sessions', cancelToken: token),
        canceled,
      );
      await adapter.started.future;
      token.cancel('left screen');
      await request;
      expect(adapter.calls, 1);
    },
  );

  test('suspend cancels reads and resume admits one new refresh', () async {
    final request = expectLater(dio.get<dynamic>('/v1/sessions'), canceled);
    await adapter.started.future;
    retry.setSuspended(true);
    await request;
    await expectLater(dio.get<dynamic>('/v1/machines'), canceled);
    expect(adapter.calls, 1);
    retry.setSuspended(false);
    adapter.release.complete(ResponseBody.fromString('[]', 200));
    expect((await dio.get<dynamic>('/v1/sessions')).statusCode, 200);
    expect(adapter.calls, 2);
  });

  test('suspend preserves durable send and retry localId', () async {
    adapter.failFirst = true;
    final request = dio.post<dynamic>(
      '/v1/sessions/session/messages',
      data: {'localId': 'canonical-message', 'text': 'continue'},
    );
    await adapter.started.future;
    retry.setSuspended(true);
    adapter.release.complete(ResponseBody.fromString('{}', 200));
    expect((await request).statusCode, 200);
    expect(adapter.localIds, ['canonical-message', 'canonical-message']);
  });
}
