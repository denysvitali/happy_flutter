import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/provider_usage_api.dart';

/// Minimal [HttpClientAdapter] that returns canned responses keyed off the
/// request, exercising the real Dio JSON pipeline without any network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
  body is String ? body : jsonEncode(body),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json'],
  },
);

Dio _dioWith(ResponseBody Function(RequestOptions options) handler) {
  final dio = Dio(
    BaseOptions(validateStatus: (_) => true, responseType: ResponseType.json),
  )..httpClientAdapter = _FakeAdapter(handler);
  return dio;
}

void main() {
  group('KimiUsageApi', () {
    test('GETs the coding-plan /usages endpoint with a Bearer + UA', () async {
      RequestOptions? seen;
      final api = KimiUsageApi(
        dio: _dioWith((o) {
          seen = o;
          return _json(<String, dynamic>{
            'usage': <String, dynamic>{'limit': '10', 'used': '4'},
          }, 200);
        }),
      );

      await api.getUsage(apiKey: 'test-key', accountId: 'a1');

      expect(seen!.method, 'GET');
      expect(seen!.uri.toString(), 'https://api.kimi.com/coding/v1/usages');
      expect(seen!.headers['Authorization'], 'Bearer test-key');
      expect(seen!.headers['User-Agent'], isNotNull);
    });

    test('parses the usage + limits[] shape', () async {
      final api = KimiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'usage': <String, dynamic>{
              'limit': '1000000',
              'used': '250000',
              'resetTime': '2099-01-01T00:00:00Z',
            },
            'limits': <Map<String, dynamic>>[
              <String, dynamic>{
                'window': <String, dynamic>{
                  'duration': 5,
                  'timeUnit': 'TIME_UNIT_MINUTE',
                },
                'detail': <String, dynamic>{'limit': '100', 'used': '40'},
              },
              <String, dynamic>{
                'window': <String, dynamic>{
                  'duration': 1,
                  'timeUnit': 'TIME_UNIT_HOUR',
                },
                'detail': <String, dynamic>{'limit': '500', 'used': '500'},
              },
            ],
          }, 200),
        ),
      );

      final usage = await api.getUsage(apiKey: 'k', accountId: 'a1');

      expect(usage.windows, hasLength(3));

      final weekly = usage.windows[0];
      expect(weekly.label, 'Weekly Usage');
      expect(weekly.used, 250000);
      expect(weekly.limit, 1000000);
      expect(weekly.utilization, closeTo(25, 0.001));
      expect(weekly.resetsAtMs, isNotNull);

      expect(usage.windows[1].label, '5m Limit');
      expect(usage.windows[1].utilization, closeTo(40, 0.001));

      expect(usage.windows[2].label, '1h Limit');
      expect(usage.windows[2].utilization, 100);
    });

    test('parses the data[] shape and derives used from remaining', () async {
      final api = KimiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'model_name': 'all',
                'limit': 1000,
                'used': 300,
                'reset_at': '2099-01-01T00:00:00Z',
              },
              <String, dynamic>{
                'model_name': 'kimi-k2',
                'limit': 200,
                'remaining': 50,
              },
            ],
          }, 200),
        ),
      );

      final usage = await api.getUsage(apiKey: 'k', accountId: 'a1');

      expect(usage.windows, hasLength(2));
      expect(usage.windows[0].label, 'Weekly Usage');
      expect(usage.windows[0].utilization, closeTo(30, 0.001));

      // used = limit - remaining = 200 - 50 = 150 -> 75% utilization.
      expect(usage.windows[1].label, 'kimi-k2');
      expect(usage.windows[1].used, 150);
      expect(usage.windows[1].utilization, closeTo(75, 0.001));
    });

    test('falls back to /usage when /usages is not 200', () async {
      final api = KimiUsageApi(
        dio: _dioWith((o) {
          if (o.uri.path.endsWith('/usages')) {
            return _json(<String, dynamic>{'error': 'nope'}, 404);
          }
          if (o.uri.path.endsWith('/usage')) {
            return _json(<String, dynamic>{
              'usage': <String, dynamic>{'limit': 10, 'used': 1},
            }, 200);
          }
          return _json(<String, dynamic>{}, 500);
        }),
      );

      final usage = await api.getUsage(apiKey: 'k', accountId: 'a1');

      expect(usage.windows, hasLength(1));
      expect(usage.windows.single.used, 1);
      expect(usage.windows.single.limit, 10);
    });

    test('honours a custom base URL and relative reset_in', () async {
      RequestOptions? seen;
      final api = KimiUsageApi(
        dio: _dioWith((o) {
          seen = o;
          return _json(<String, dynamic>{
            'usage': <String, dynamic>{
              'limit': 10,
              'used': 2,
              'reset_in': 3600,
            },
          }, 200);
        }),
      );

      final usage = await api.getUsage(
        apiKey: 'k',
        accountId: 'a1',
        baseUrl: 'https://gw.example.com/v9/',
      );

      expect(seen!.uri.toString(), 'https://gw.example.com/v9/usages');
      expect(
        usage.windows.single.resetsAtMs,
        greaterThan(DateTime.now().millisecondsSinceEpoch),
      );
    });

    test('surfaces the server error body on 401', () async {
      final api = KimiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{'code': 'unauthenticated'}, 401),
        ),
      );

      await expectLater(
        api.getUsage(apiKey: 'bad', accountId: 'a1'),
        throwsA(
          isA<ProviderUsageApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having(
                (e) => e.message,
                'message',
                allOf(contains('401'), contains('unauthenticated')),
              ),
        ),
      );
    });
  });

  group('MiniMaxUsageApi', () {
    test('GETs token plan remains with a Bearer API key', () async {
      RequestOptions? seen;
      final api = MiniMaxUsageApi(
        dio: _dioWith((o) {
          seen = o;
          return _json(<String, dynamic>{
            'model_remains': <Map<String, dynamic>>[
              <String, dynamic>{
                'model_name': 'MiniMax-Text',
                'current_interval_total_count': 100,
                'current_interval_usage_count': 25,
                'end_time': 1893456000000,
              },
            ],
          }, 200);
        }),
      );

      final usage = await api.getUsage(apiKey: 'test-key', accountId: 'a1');

      expect(seen!.method, 'GET');
      expect(seen!.uri.path, '/v1/token_plan/remains');
      expect(seen!.headers['Authorization'], 'Bearer test-key');

      expect(usage.windows.single.label, 'MiniMax-Text');
      // current_interval_usage_count is the remaining quota for this endpoint:
      // used = 100 - 25 = 75.
      expect(usage.windows.single.used, 75);
      expect(usage.windows.single.remaining, 25);
      expect(usage.windows.single.utilization, closeTo(75, 0.001));
      expect(usage.extra, isEmpty);
    });

    test('parses top-level token plan quota', () async {
      final api = MiniMaxUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'total_count': '1000',
            'remain_count': '250',
            'reset_at': '2099-01-01T00:00:00Z',
          }, 200),
        ),
      );

      final usage = await api.getUsage(apiKey: 'test-key', accountId: 'a1');

      expect(usage.windows.single.label, 'Token Plan');
      expect(usage.windows.single.limit, 1000);
      expect(usage.windows.single.used, 750);
      expect(usage.windows.single.remaining, 250);
      expect(usage.windows.single.utilization, closeTo(75, 0.001));
      expect(usage.windows.single.resetsAtMs, isNotNull);
    });
  });
}
