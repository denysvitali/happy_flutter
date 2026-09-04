import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Measurements at the Dart/native boundary. NativeAdapter does not expose
/// DNS, TCP or TLS callbacks; header wait includes those phases and scheduling.
/// Never label this aggregate as server latency or invent per-phase timings.
class HttpTransportTiming {
  HttpTransportTiming(this.adapter, this.lifecycleAtDispatch);
  static const extraKey = '_httpTransportTiming';
  final String adapter;
  final String lifecycleAtDispatch;
  final Stopwatch clock = Stopwatch()..start();
  int? headersUs;
  int? bodyDoneUs;
  int? failedUs;
  int? callbackUs;
  String? lifecycleAtHeaders;

  Map<String, Object?> attributes() => {
    'http.adapter': adapter,
    'http.transport.phase_detail': 'headers_and_body',
    'app.lifecycle.dispatch': lifecycleAtDispatch,
    if (lifecycleAtHeaders != null) 'app.lifecycle.headers': lifecycleAtHeaders,
    if (headersUs != null) 'http.transport.headers_ms': headersUs! / 1000,
    if (bodyDoneUs != null && headersUs != null)
      'http.transport.body_ms': (bodyDoneUs! - headersUs!) / 1000,
    if (bodyDoneUs != null && callbackUs != null && callbackUs! >= bodyDoneUs!)
      'http.transport.callback_ms': (callbackUs! - bodyDoneUs!) / 1000,
    if (failedUs != null) 'http.transport.failed_after_ms': failedUs! / 1000,
  };
}

class TimedHttpAdapter implements HttpClientAdapter {
  TimedHttpAdapter(this.inner, {required this.lifecycle});
  final HttpClientAdapter inner;
  final String Function() lifecycle;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final timing = HttpTransportTiming(
      inner.runtimeType.toString(),
      lifecycle(),
    );
    options.extra[HttpTransportTiming.extraKey] = timing;
    try {
      final response = await inner.fetch(options, requestStream, cancelFuture);
      timing.headersUs = timing.clock.elapsedMicroseconds;
      timing.lifecycleAtHeaders = lifecycle();
      response.stream = _measureBody(response.stream, timing);
      return response;
    } catch (_) {
      timing.failedUs = timing.clock.elapsedMicroseconds;
      rethrow;
    }
  }

  Stream<Uint8List> _measureBody(
    Stream<Uint8List> source,
    HttpTransportTiming timing,
  ) async* {
    try {
      yield* source;
      timing.bodyDoneUs = timing.clock.elapsedMicroseconds;
    } catch (_) {
      timing.failedUs = timing.clock.elapsedMicroseconds;
      rethrow;
    }
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}
