// The `sentry` package is transitive via `sentry_flutter`. The constructors
// we need (SentryEvent, SentryException, SentryThread, SentryStackFrame) are
// not re-exported by `sentry_flutter`, so we import the package directly.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/dart_sentry_transport.dart';
import 'package:http/http.dart' as http;
import 'package:sentry/sentry.dart';

class _CapturingClient extends http.BaseClient {
  Uint8List? lastBody;
  int requestCount = 0;
  final List<int> bodySizes = <int>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    if (request is http.Request) {
      lastBody = Uint8List.fromList(request.bodyBytes);
      bodySizes.add(lastBody!.length);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode('{}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

SentryOptions _buildOptions() {
  return SentryOptions(
    dsn: 'https://abc123@glitchtip.example.com/1',
  )..tracesSampleRate = 0;
}

SentryStackTrace _bigStack() {
  return SentryStackTrace(
    frames: List.generate(
      50,
      (i) => SentryStackFrame(
        function: 'func_$i ${'x' * 200}',
        fileName: 'long_file_name_${'a' * 100}_$i.dart',
        lineNo: i,
      ),
    ),
  );
}

SentryEvent _anrEvent({int breadcrumbSize = 0}) {
  final stack = _bigStack();
  return SentryEvent(
    exceptions: [
      SentryException(
        type: 'ApplicationNotResponding',
        value: 'Process main is not responding',
        stackTrace: stack,
      ),
    ],
    threads: [
      SentryThread(
        name: 'main',
        crashed: true,
        stacktrace: stack,
      ),
    ],
    breadcrumbs: List.generate(
      breadcrumbSize,
      (i) => Breadcrumb(
        message: 'msg ${'x' * 200}',
        data: {'k': 'v' * 200},
      ),
    ),
    level: SentryLevel.fatal,
    message: SentryMessage('ANR detected'),
  );
}

SentryEvent _regularEvent() {
  return SentryEvent(
    exceptions: [
      SentryException(
        type: 'StateError',
        value: 'regular crash',
      ),
    ],
    level: SentryLevel.error,
  );
}

SentryEnvelope _wrap(SentryEvent event) {
  return SentryEnvelope.fromEvent(
    event,
    SdkVersion(name: 'test', version: '0'),
  );
}

void main() {
  group('DartSentryTransport envelope cap', () {
    test('small envelope passes through unchanged', () async {
      final client = _CapturingClient();
      final transport = DartSentryTransport(
        _buildOptions(),
        client: client,
        maxEnvelopeBytes: 4 * 1024 * 1024,
      );

      final result = await transport.send(_wrap(_regularEvent()));

      expect(result, isNot(SentryId.empty()));
      expect(client.requestCount, 1);
    });

    test('oversized ANR envelope is shrunk to fit cap', () async {
      final client = _CapturingClient();
      final transport = DartSentryTransport(
        _buildOptions(),
        client: client,
        maxEnvelopeBytes: 4 * 1024,
      );

      final envelope = _wrap(_anrEvent(breadcrumbSize: 2000));
      final result = await transport.send(envelope);

      expect(result, isNot(SentryId.empty()));
      expect(client.requestCount, 1);
      final sentSize = client.bodySizes.first;
      expect(sentSize, lessThanOrEqualTo(4 * 1024));

      // Envelope wire format: envelope-header\nitem-header\nitem-payload\n
      // (followed by a trailing empty line).
      final lines = utf8.decode(client.lastBody!).split('\n');
      final eventJson = json.decode(lines[2]) as Map<String, dynamic>;

      // Required shrink invariants: breadcrumbs and stacktraces stripped.
      expect(eventJson['breadcrumbs'], isNull);
      expect(eventJson['exception']['values'][0]['stacktrace'], isNull);
    });

    test('unshrinkable oversized envelope is dropped (no request sent)',
        () async {
      final client = _CapturingClient();
      final transport = DartSentryTransport(
        _buildOptions(),
        client: client,
        maxEnvelopeBytes: 64,
      );

      final envelope = _wrap(_anrEvent(breadcrumbSize: 100));
      final result = await transport.send(envelope);

      expect(result, SentryId.empty());
      expect(client.requestCount, 0);
    });

    test('non-ANR oversized envelope is dropped (no shrink attempt)',
        () async {
      final client = _CapturingClient();
      final transport = DartSentryTransport(
        _buildOptions(),
        client: client,
        maxEnvelopeBytes: 32,
      );

      final envelope = _wrap(_regularEvent());
      final result = await transport.send(envelope);

      expect(result, SentryId.empty());
      expect(client.requestCount, 0);
    });
  });
}
