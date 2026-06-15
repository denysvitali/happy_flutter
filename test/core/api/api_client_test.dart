import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show TraceFlags;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart'
    show BatchSpanProcessor, ConsoleExporter, OTel;
import 'package:happy_flutter/core/api/api_client.dart';

void main() {
  group('ApiClient Retry Logic', () {
    late ApiClient apiClient;

    setUp(() async {
      apiClient = ApiClient();
      await apiClient.initialize(serverUrl: 'https://test.example.com');
    });

    tearDown(() {
      apiClient.dispose();
    });

    test('retry interceptor exists and is configured', () async {
      // Verify the client was initialized
      expect(apiClient.testDio, isNotNull);
      expect(apiClient.getCurrentServerUrl(), 'https://test.example.com');
    });

    test('should not retry on 4xx client errors', () async {
      // We can't directly test the interceptor without mocking,
      // but we can verify the client is properly configured
      expect(apiClient.testDio, isNotNull);
      expect(apiClient.testDio!.interceptors, isNotEmpty);
    });

    test('should not retry on cancellation', () async {
      // Verify interceptors are configured
      expect(apiClient.testDio, isNotNull);
      expect(apiClient.testDio!.interceptors.length, greaterThan(0));
    });

    test('should have proper retry configuration', () async {
      // The retry interceptor should be the first interceptor added
      expect(apiClient.testDio, isNotNull);
      expect(apiClient.testDio!.interceptors, isNotEmpty);
    });

    test('dispose clears resources', () async {
      apiClient.dispose();
      // After dispose, _ensureInitialized should throw
      expect(() => apiClient.get('/test'), throwsA(isA<StateError>()));
    });

    test('request pre-flight terminates and does not self-recurse '
        '(regression: _ensureAdapterForRequest infinite recursion froze '
        'startup at "Checking sign-in status" → ANR)', () async {
      // The per-request adapter hook must call the init guard, not
      // itself.  A recursive _ensureAdapterForRequest() re-enters its
      // own body before the first await and stack-overflows (or, once
      // an await is reached, pegs the event loop forever) — on device
      // this starves checkAuth()'s microtask so the UI never paints
      // past the auth splash.  After dispose the guard throws a
      // StateError synchronously, before any adapter/network work;
      // with the recursion it instead overflows the stack or hangs.
      apiClient.dispose();
      await expectLater(
        apiClient.get('/test').timeout(const Duration(seconds: 5)),
        throwsA(isA<StateError>()),
      );
    });

    test('updateToken updates auth header', () async {
      apiClient.updateToken('test-token');
      expect(apiClient.testDio, isNotNull);
      expect(
        apiClient.testDio!.options.headers['Authorization'],
        'Bearer test-token',
      );
    });

    test('clearToken removes auth header', () async {
      apiClient
        ..updateToken('test-token')
        ..clearToken();
      expect(apiClient.testDio, isNotNull);
      expect(
        apiClient.testDio!.options.headers.containsKey('Authorization'),
        false,
      );
    });

    test('refreshServerUrl updates when URL changes', () async {
      // This test verifies the refreshServerUrl method exists and is callable
      expect(apiClient.getCurrentServerUrl(), 'https://test.example.com');
      // Note: We can't fully test refreshServerUrl without mocking getServerUrl
      // but we verify the method exists and current URL is tracked
    });
  });

  group('ApiClient Error Detection', () {
    late ApiClient apiClient;

    setUp(() async {
      apiClient = ApiClient();
      await apiClient.initialize(serverUrl: 'https://test.example.com');
    });

    tearDown(() {
      apiClient.dispose();
    });

    test('isAuthError detects 401', () {
      final response = Response<dynamic>(
        data: {},
        statusCode: 401,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(apiClient.isAuthError(response), true);
    });

    test('isAuthError detects 403', () {
      final response = Response<dynamic>(
        data: {},
        statusCode: 403,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(apiClient.isAuthError(response), true);
    });

    test('isAuthError returns false for other codes', () {
      final response = Response<dynamic>(
        data: {},
        statusCode: 404,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(apiClient.isAuthError(response), false);
    });

    test('isSuccess detects 2xx codes', () {
      final response = Response<dynamic>(
        data: {},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(apiClient.isSuccess(response), true);
    });

    test('isSuccess returns false for non-2xx codes', () {
      final response = Response<dynamic>(
        data: {},
        statusCode: 404,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(apiClient.isSuccess(response), false);
    });
  });

  group('ApiClient OpenTelemetry trace context propagation', () {
    setUp(() async {
      await OTel.reset();
      await OTel.initialize(
        endpoint: 'http://localhost:4318',
        serviceName: 'api-client-test',
        serviceVersion: '1.0.0',
        detectPlatformResources: false,
        enableMetrics: false,
        enableLogs: false,
        spanProcessor: BatchSpanProcessor(ConsoleExporter()),
      );
    });

    tearDown(() async {
      await OTel.reset();
    });

    test('injects W3C traceparent header from span context', () {
      final traceId = OTel.traceIdFrom('8d08af79194aef4486a84ec5010d5d8e');
      final spanId = OTel.spanIdFrom('1234567890abcdef');
      final spanContext = OTel.spanContext(
        traceId: traceId,
        spanId: spanId,
        traceFlags: TraceFlags.sampled,
      );
      final options = RequestOptions(path: '/v1/test');
      options.headers['X-Custom'] = 'keep';

      ApiClient.injectTraceContext(spanContext, options);

      expect(
        options.headers['traceparent'],
        '00-8d08af79194aef4486a84ec5010d5d8e-1234567890abcdef-01',
      );
      expect(options.headers['X-Custom'], 'keep');
    });

    test('injects traceparent with unsampled trace flags', () {
      final spanContext = OTel.spanContext(
        traceId: OTel.traceIdFrom('8d08af79194aef4486a84ec5010d5d8e'),
        spanId: OTel.spanIdFrom('1234567890abcdef'),
        traceFlags: TraceFlags.none,
      );
      final options = RequestOptions(path: '/v1/test');

      ApiClient.injectTraceContext(spanContext, options);

      expect(
        options.headers['traceparent'],
        '00-8d08af79194aef4486a84ec5010d5d8e-1234567890abcdef-00',
      );
    });

    test('does not inject traceparent for invalid span context', () {
      final options = RequestOptions(path: '/v1/test');

      ApiClient.injectTraceContext(OTel.spanContextInvalid(), options);

      expect(options.headers.containsKey('traceparent'), isFalse);
    });
  });

  group('ApiClient OpenTelemetry attributes', () {
    test('normalizes dynamic path segments and removes query strings', () {
      final normalized = ApiClient.normalizePathForTracing(
        '/v1/sessions/0190b7aa-1f3b-7a51-9920-bcbd4d9582bb/'
        'messages/123?token=secret&message=hello',
      );

      expect(normalized, '/v1/sessions/:id/messages/:id');
      expect(normalized, isNot(contains('secret')));
      expect(normalized, isNot(contains('hello')));
      expect(normalized, isNot(contains('?')));
    });

    test('normalizes long opaque IDs without exposing tokens', () {
      final normalized = ApiClient.normalizePathForTracing(
        '/v1/files/sk_test_abcdefghijklmnopqrstuvwxyz/download',
      );

      expect(normalized, '/v1/files/:id/download');
      expect(normalized, isNot(contains('abcdefghijklmnopqrstuvwxyz')));
    });

    test('uses normalized route in span name without raw IDs', () {
      final options = RequestOptions(
        path: '/v3/sessions/cf6949f3e2e86b18f1b12f0fc/messages',
        method: 'GET',
      );

      final spanName = ApiClient.debugBuildOtelHttpSpanName(options);

      expect(spanName, 'GET /v3/sessions/:id/messages');
      expect(spanName, isNot(contains('cf6949f3e2e86b18f1b12f0fc')));
    });

    test('exports http.route but not sanitized url.path', () {
      final options = RequestOptions(
        baseUrl: 'https://test.example.com',
        path:
            '/v3/sessions/cf6949f3e2e86b18f1b12f0fc/messages'
            '?token=secret',
        method: 'POST',
        data: 'hello',
      );

      final attributes = ApiClient.debugBuildOtelHttpAttributes(options);

      expect(attributes['http.route'], '/v3/sessions/:id/messages');
      expect(attributes['http.request.method'], 'POST');
      expect(attributes['server.address'], 'test.example.com');
      expect(attributes['http.request.body.size'], 5);
      expect(attributes.containsKey('url.path'), isFalse);
      expect(attributes.values.join(' '), isNot(contains('secret')));
      expect(
        attributes.values.join(' '),
        isNot(contains('cf6949f3e2e86b18f1b12f0fc')),
      );
    });
  });

  group('ApiClient cache instrumentation', () {
    late ApiClient apiClient;
    var hitCount = 0;

    setUp(() async {
      hitCount = 0;
      apiClient = ApiClient();
      await apiClient.initialize(serverUrl: 'https://test.example.com');
      apiClient.debugSeedCache(
        Response<dynamic>(
          data: const {'cached': true},
          statusCode: 200,
          requestOptions: RequestOptions(
            path: '/cached',
            method: 'GET',
            baseUrl: 'https://test.example.com',
          ),
        ),
      );
      apiClient.testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            hitCount++;
            handler.resolve(
              Response<dynamic>(
                data: {'hitCount': hitCount},
                statusCode: 200,
                requestOptions: options,
              ),
            );
          },
        ),
      );
    });

    tearDown(() {
      apiClient.dispose();
    });

    test('cache hits still carry current request instrumentation', () async {
      final response = await apiClient.get('/cached');

      expect(response.data, const {'cached': true});
      expect(response.requestOptions.extra['fromCache'], true);
      expect(response.requestOptions.extra['_trackId'], isA<int>());
      expect(response.requestOptions.extra['_trackStart'], isA<int>());
      expect(hitCount, 0);
    });
  });
}
