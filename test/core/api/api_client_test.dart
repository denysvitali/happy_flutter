import 'dart:async';

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    show TraceFlags;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart'
    show BatchSpanProcessor, ConsoleExporter, OTel;
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/api/retry_interceptor.dart';

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

    test('connect + receive timeouts bound the request to 23s on the '
        'native adapter', () {
      // P0-1: connectTimeout was 30s, which Jaeger traced as ~28-34s
      // cold-start/resume stalls on the bootstrap fan-out (profile/
      // settings/machines/sessions).
      //
      // These are NOT two independent phases on device: NativeAdapter
      // (Cronet / cupertino_http) runs through ConversionLayerAdapter,
      // which applies `connectTimeout + receiveTimeout` as a single
      // `client.send(...).timeout(...)` and reports expiry as
      // DioExceptionType.receiveTimeout. The number that matters is the
      // sum — 23s here — and there is no separate handshake bound.
      final options = apiClient.testDio!.options;
      expect(options.connectTimeout, const Duration(seconds: 8));
      expect(options.receiveTimeout, const Duration(seconds: 15));
      expect(options.sendTimeout, const Duration(seconds: 30));
      expect(
        options.connectTimeout! + options.receiveTimeout!,
        const Duration(seconds: 23),
        reason: 'the effective single budget applied by the native adapter',
      );
    });

    test('server status failures reach the retry interceptor even though '
        'validateStatus accepts every status', () {
      // validateStatus: (_) => true means Dio never raises a DioException
      // for a 5xx, so the retry classification has to run on the response
      // chain. The retry interceptor must therefore be registered first
      // (response interceptors run in registration order).
      final options = apiClient.testDio!.options;
      expect(options.validateStatus(503), isTrue);
      final interceptors = apiClient.testDio!.interceptors;
      final retryIndex = interceptors.indexWhere((i) => i is RetryInterceptor);
      final firstWrapperIndex = interceptors.indexWhere(
        (i) => i is InterceptorsWrapper,
      );
      expect(retryIndex, isNonNegative);
      expect(
        retryIndex,
        lessThan(firstWrapperIndex),
        reason: 'the retry interceptor classifies responses first',
      );
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

    test('get() deduplicates calls issued before the adapter await resolves '
        '(battery regression: the dedup key was previously checked only '
        'after `await _ensureAdapterForRequest()`, so two calls issued in '
        'the same tick both saw an empty in-flight map and each fired an '
        'independent HTTP request to the same endpoint — observed in '
        'production power diagnostics as bursts of duplicate simultaneous '
        'GETs after a resume/reconnect invalidation cascade)', () {
      final f1 = apiClient.get('/v2/sessions');
      final f2 = apiClient.get('/v2/sessions');

      expect(
        identical(f1, f2),
        isTrue,
        reason:
            'both calls must share the exact same in-flight request '
            'future — checked and registered synchronously, with no '
            'await in between',
      );

      // The test server URL is not reachable; swallow the eventual
      // rejection so it is not reported as an unhandled async error.
      unawaited(
        f1.catchError(
          (_) => Response(requestOptions: RequestOptions(path: '')),
        ),
      );
    });

    test(
      'post() deduplicates calls issued before the adapter await resolves',
      () {
        final f1 = apiClient.post('/v1/account/settings', data: {'a': 1});
        final f2 = apiClient.post('/v1/account/settings', data: {'a': 1});

        expect(identical(f1, f2), isTrue);

        unawaited(
          f1.catchError(
            (_) => Response(requestOptions: RequestOptions(path: '')),
          ),
        );
      },
    );

    test(
      'in-flight lazy adapter startup does not escape after reinitialize',
      () async {
        final oldRequest = apiClient.get('/v2/sessions');

        apiClient.dispose();
        await apiClient.initialize(serverUrl: 'https://new.example.com');

        await expectLater(
          oldRequest,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('reconfigured'),
            ),
          ),
        );
      },
    );

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

    test('cache hits run the response chain so their span is closed', () async {
      // The cache interceptor resolves during onRequest. Without
      // `callFollowingResponseInterceptor`, every response interceptor —
      // including the one that ends the tracing span opened moments
      // earlier — is skipped, leaking one span per cache hit.
      final response = await apiClient.get('/cached');

      expect(response.requestOptions.extra['fromCache'], true);
      expect(
        response.requestOptions.extra['_otelSpan'],
        isNull,
        reason: 'no span is left open once the cached response is returned',
      );
    });
  });

  group('ApiClient retry instrumentation', () {
    late ApiClient apiClient;

    setUp(() async {
      apiClient = ApiClient();
      await apiClient.initialize(serverUrl: 'https://test.example.com');
    });

    tearDown(() {
      apiClient.dispose();
    });

    test('a retried request keeps the first attempt start so the total '
        'elapsed time is recorded, and each attempt gets fresh span '
        'bookkeeping', () async {
      var attempts = 0;
      apiClient.testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            attempts++;
            handler.resolve(
              Response<dynamic>(
                data: {'attempt': attempts},
                statusCode: attempts == 1 ? 503 : 200,
                requestOptions: options,
              ),
              // Run the response chain, mirroring how a real adapter
              // response flows through the interceptors.
              true,
            );
          },
        ),
      );

      final response = await apiClient.get('/v1/machines');

      expect(attempts, 2, reason: 'the 503 must be retried');
      expect(response.statusCode, 200);

      final extra = response.requestOptions.extra;
      expect(extra[RetryInterceptor.retryCountKey], 1);
      final firstStart = extra['_otelFirstStart'] as int;
      final lastStart = extra['_otelStart'] as int;
      expect(
        lastStart,
        greaterThan(firstStart),
        reason:
            'the second attempt has its own start; the first attempt start '
            'survives so http.total_duration_ms covers the whole sequence',
      );
      expect(
        extra['_otelSpan'],
        isNull,
        reason:
            'both the retried attempt span and the final span are ended and '
            'their reference cleared — nothing is left open and unexported',
      );
    });

    test('retry attributes expose the attempt index alongside the count', () {
      final options = RequestOptions(
        baseUrl: 'https://test.example.com',
        path: '/v1/push/send-all',
        method: 'POST',
        extra: {RetryInterceptor.retryCountKey: 2},
      );

      final attributes = ApiClient.debugBuildOtelHttpAttributes(options);

      expect(attributes['http.retry_count'], 2);
      expect(attributes['http.attempt'], 3);
    });
  });
}
