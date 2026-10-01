import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/renewable_http_adapter.dart';
import 'package:happy_flutter/core/api/retry_interceptor.dart';

class _Adapter implements HttpClientAdapter {
  final body = StreamController<Uint8List>();
  bool closed = false;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody(body.stream, 200);
  }

  @override
  void close({bool force = false}) => closed = true;
}

void main() {
  test(
    'DNS renewal retries the same POST payload and canonical identity',
    () async {
      final identities = <String>[];
      var created = 0;
      final adapter = RenewableHttpAdapter(
        () => _ReplyAdapter(fail: created++ == 0, identities: identities),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(
          dioGetter: () => dio,
          baseDelayMs: 1,
          maxDelayMs: 2,
          onTransportFailure: (error) =>
              adapter.renewForRequest(error.requestOptions),
        ),
      );
      addTearDown(dio.close);
      final response = await dio.post<String>(
        '/messages',
        data: {'localId': 'canonical', 'content': 'continue'},
      );
      expect(response.statusCode, 200);
      expect(identities, ['canonical', 'canonical']);
      expect(created, 2);
    },
  );

  test(
    'renewal preserves in-flight writes and retires after body drain',
    () async {
      final transports = <_Adapter>[];
      final adapter = RenewableHttpAdapter(() {
        final transport = _Adapter();
        transports.add(transport);
        return transport;
      });
      final request = RequestOptions(
        path: '/messages',
        method: 'POST',
        data: {'localId': 'canonical'},
      );
      final first = await adapter.fetch(request, null, null);
      final firstBytes = first.stream.toList();
      adapter.renew();
      expect(transports.single.closed, isFalse);
      final second = await adapter.fetch(
        RequestOptions(path: '/machines'),
        null,
        null,
      );
      final secondBytes = second.stream.toList();
      expect(transports, hasLength(2));
      expect(identical(transports.first.request, request), isTrue);
      expect(transports.first.request!.data, {'localId': 'canonical'});
      transports.first.body.add(Uint8List.fromList([1]));
      await transports.first.body.close();
      expect((await firstBytes).single, [1]);
      expect(transports.first.closed, isTrue);
      await transports.last.body.close();
      await secondBytes;
      adapter.close(force: true);
      expect(transports.last.closed, isTrue);
    },
  );

  test(
    'late failure from retired transport cannot renew healthy transport',
    () async {
      final transports = <_Adapter>[];
      final adapter = RenewableHttpAdapter(() {
        final transport = _Adapter();
        transports.add(transport);
        return transport;
      });
      final stale = RequestOptions(path: '/old');
      final first = await adapter.fetch(stale, null, null);
      final firstBytes = first.stream.toList();
      adapter.renew();
      final fresh = RequestOptions(path: '/fresh');
      final second = await adapter.fetch(fresh, null, null);
      final secondBytes = second.stream.toList();
      adapter.renewForRequest(stale);
      final third = await adapter.fetch(
        RequestOptions(path: '/another'),
        null,
        null,
      );
      // Consume the shared fake stream only once.
      expect(transports, hasLength(2));
      expect(third.statusCode, 200);
      await transports.first.body.close();
      await firstBytes;
      await transports.last.body.close();
      await secondBytes;
      adapter.close(force: true);
    },
  );
}

class _ReplyAdapter implements HttpClientAdapter {
  _ReplyAdapter({required this.fail, required this.identities});
  final bool fail;
  final List<String> identities;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data as Map<String, dynamic>;
    identities.add(data['localId'] as String);
    expect(data['content'], 'continue');
    if (fail) {
      throw DioException(
        requestOptions: options,
        error: 'net::ERR_NAME_NOT_RESOLVED',
      );
    }
    return ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) {}
}
