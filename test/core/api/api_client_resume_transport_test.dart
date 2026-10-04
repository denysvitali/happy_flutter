import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/api/renewable_http_adapter.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

void main() {
  late ApiClient client;
  late List<_Transport> transports;

  setUp(() async {
    client = ApiClient();
    await client.initialize(serverUrl: 'https://example.test');
    client.setSuspended(false);
    transports = [];
    client.testDio!.httpClientAdapter = RenewableHttpAdapter(() {
      final transport = _Transport();
      transports.add(transport);
      return transport;
    });
  });

  tearDown(() {
    client.dispose();
    client.setSuspended(false);
  });

  Future<Response<String>> read() => client.testDio!.get<String>(
    '/v1/sessions',
    options: Options(
      responseType: ResponseType.plain,
      extra: {'bypassCache': true},
    ),
  );

  test('resume renews before reads without a connectivity change', () async {
    await read();
    final sync = Sync();
    final wasInitialized = sync.testIsInitialized;
    sync.testIsInitialized = false;
    try {
      client.setSuspended(true);
      sync.resume();

      // Auth restoration can still be pending. The lifecycle policy must
      // renew synchronously before either auth or initialized sync resumes.
      expect(transports.single.closed, isTrue);
      expect((await read()).statusCode, 200);
      expect(transports, hasLength(2));
    } finally {
      sync.testIsInitialized = wasInitialized;
    }
  });

  test('foreground resume calls do not churn the healthy pool', () async {
    await read();
    client.setSuspended(false);
    await read();
    expect(transports, hasLength(1));
    expect(transports.single.closed, isFalse);

    client.setSuspended(true);
    client.setSuspended(true);
    client.setSuspended(false);
    await read();
    client.setSuspended(false);
    await read();
    expect(transports, hasLength(2));
    expect(transports.last.closed, isFalse);
  });

  test('resume lets an active POST drain with its original identity', () async {
    final response = await client.testDio!.post<ResponseBody>(
      '/v1/messages',
      data: {'localId': 'canonical', 'content': 'continue'},
      options: Options(responseType: ResponseType.stream),
    );
    final body = response.data!.stream.toList();
    final old = transports.single;

    client.setSuspended(true);
    client.setSuspended(false);
    expect(old.closed, isFalse);
    await read();
    expect(transports, hasLength(2));
    expect(old.requests, hasLength(1));
    expect(old.requests.single.data, {
      'localId': 'canonical',
      'content': 'continue',
    });

    old.writeBody.add(Uint8List.fromList([1, 2, 3]));
    await old.writeBody.close();
    expect((await body).single, [1, 2, 3]);
    expect(old.closed, isTrue);
    expect(transports.last.closed, isFalse);
  });

  test('old pre-header failure cannot retire the resumed pool', () async {
    await read();
    final old = transports.single;
    old.holdWriteHeaders = true;
    final write = client.testDio!.post<ResponseBody>(
      '/v1/messages',
      data: {'localId': 'canonical', 'content': 'continue'},
      options: Options(
        responseType: ResponseType.stream,
        extra: {'disableRetry': true},
      ),
    );
    final failure = expectLater(write, throwsA(isA<DioException>()));
    await old.writeDispatched.future;
    client.setSuspended(true);
    client.setSuspended(false);
    await read();
    expect(transports, hasLength(2));

    old.writeHeaders.completeError(
      DioException(
        requestOptions: old.requests.last,
        error: 'net::ERR_NAME_NOT_RESOLVED',
      ),
    );
    await failure;
    expect(old.closed, isTrue);
    await read();
    expect(transports, hasLength(2));
    expect(transports.last.closed, isFalse);
    expect(
      old.requests.where((request) => request.method == 'POST'),
      hasLength(1),
    );
  });
}

class _Transport implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final writeBody = StreamController<Uint8List>();
  final writeHeaders = Completer<ResponseBody>();
  final writeDispatched = Completer<void>();
  bool holdWriteHeaders = false;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'POST') {
      if (holdWriteHeaders) {
        writeDispatched.complete();
        return writeHeaders.future;
      }
      return ResponseBody(writeBody.stream, 200);
    }
    return ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) => closed = true;
}
