import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/timed_http_adapter.dart';

class _Transport implements HttpClientAdapter {
  final headers = Completer<ResponseBody>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) => headers.future;
  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'separates header wait, body and callback without altering bytes',
    () async {
      final transport = _Transport();
      var lifecycle = 'active';
      final adapter = TimedHttpAdapter(transport, lifecycle: () => lifecycle);
      final options = RequestOptions(path: '/v1/sessions');
      final response = adapter.fetch(options, null, null);
      final timing =
          options.extra[HttpTransportTiming.extraKey] as HttpTransportTiming;
      expect(timing.headersUs, isNull);
      lifecycle = 'suspended';
      final body = StreamController<Uint8List>();
      transport.headers.complete(ResponseBody(body.stream, 200));
      final headers = await response;
      expect(timing.headersUs, isNotNull);
      expect(timing.bodyDoneUs, isNull);
      final chunks = headers.stream.toList();
      body.add(Uint8List.fromList([1, 2, 3]));
      await body.close();
      expect((await chunks).single, [1, 2, 3]);
      timing.callbackUs = timing.clock.elapsedMicroseconds;
      final attributes = timing.attributes();
      expect(attributes['app.lifecycle.dispatch'], 'active');
      expect(attributes['app.lifecycle.headers'], 'suspended');
      expect(attributes['http.transport.body_ms'], isNonNegative);
      expect(attributes['http.transport.callback_ms'], isNonNegative);
      expect(attributes.containsKey('http.transport.dns_ms'), isFalse);
    },
  );
}
