import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/provider_usage_api.dart';
import 'package:happy_flutter/core/models/provider_usage.dart';

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

    test('attaches raw payload when includeDebugPayload is true', () async {
      final api = KimiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'usage': <String, dynamic>{'limit': '100', 'used': '30'},
          }, 200),
        ),
      );

      final production = await api.getUsage(
        apiKey: 'test-key',
        accountId: 'a1',
      );
      expect(production.extra, isEmpty);

      final debug = await api.getUsage(
        apiKey: 'test-key',
        accountId: 'a1',
        includeDebugPayload: true,
      );
      expect(debug.extra['endpoint'], '/usages');
      expect(debug.extra['status'], 200);
      expect(debug.extra['window_count'], 1);
      expect(debug.extra['raw_payload'], isA<String>());
      expect(debug.extra['raw_payload_compact'], contains('"limit"'));
      expect(
        debug.extra['request_url'],
        'https://api.kimi.com/coding/v1/usages',
      );
    });

    test('reflects fallback endpoint in debug payload when /usages fails',
        () async {
      final api = KimiUsageApi(
        dio: _dioWith((o) {
          if (o.uri.path.endsWith('/usages')) {
            return _json(<String, dynamic>{'error': 'nope'}, 404);
          }
          return _json(<String, dynamic>{
            'usage': <String, dynamic>{'limit': '50', 'used': '10'},
          }, 200);
        }),
      );

      final usage = await api.getUsage(
        apiKey: 'test-key',
        accountId: 'a1',
        includeDebugPayload: true,
      );

      expect(usage.extra['endpoint'], '/usage');
      expect(usage.extra['status'], 200);
      expect(usage.extra['request_url'], endsWith('/usage'));
      expect(usage.extra['raw_payload'], isA<String>());
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
                'current_interval_remaining_percent': 25,
                'current_interval_total_count': 100,
                'current_interval_usage_count': 75,
                'end_time': 1893456000000,
                'current_weekly_remaining_percent': 50,
                'weekly_end_time': 1896057600000,
              },
            ],
          }, 200);
        }),
      );

      final usage = await api.getUsage(apiKey: 'test-key', accountId: 'a1');

      expect(seen!.method, 'GET');
      expect(seen!.uri.path, '/v1/token_plan/remains');
      expect(seen!.headers['Authorization'], 'Bearer test-key');

      // The canonical signal is `*_remaining_percent` — we should not derive
      // utilization from `usage_count` (which is the count USED in this
      // endpoint, not remaining). 25% remaining → 75% used.
      expect(usage.windows, hasLength(2));
      final interval = usage.windows[0];
      expect(interval.label, 'MiniMax-Text');
      expect(interval.utilization, closeTo(75, 0.001));
      expect(interval.resetsAtMs, 1893456000000);

      final weekly = usage.windows[1];
      expect(weekly.label, 'MiniMax-Text Weekly');
      expect(weekly.utilization, closeTo(50, 0.001));
      expect(weekly.resetsAtMs, 1896057600000);

      // Default behaviour (production): no debug payload leaks into `extra`.
      expect(usage.extra, isEmpty);
    });

    test('attaches raw payload only when includeDebugPayload is true',
        () async {
      final api = MiniMaxUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'model_remains': <Map<String, dynamic>>[
              <String, dynamic>{
                'model_name': 'MiniMax-Text',
                'current_interval_remaining_percent': 25,
                'end_time': 1893456000000,
              },
            ],
          }, 200),
        ),
      );

      final usage = await api.getUsage(
        apiKey: 'test-key',
        accountId: 'a1',
        includeDebugPayload: true,
      );

      expect(usage.extra['endpoint'], '/v1/token_plan/remains');
      expect(usage.extra['status'], 200);
      expect(usage.extra['window_count'], 1);
      expect(usage.extra['raw_payload'], isA<String>());
      expect(usage.extra['raw_payload_compact'], contains('MiniMax-Text'));
    });

    test('handles the production shape (current_interval_remaining_percent)',
        () async {
      // Mirrors the live payload probed on 2026-06-17 — confirms the parser
      // doesn't trust the misleading `*_total_count` / `*_usage_count`
      // integers (both 0 here) when the percent signal is present.
      final api = MiniMaxUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'model_remains': <Map<String, dynamic>>[
              <String, dynamic>{
                'start_time': 1781672400000,
                'end_time': 1781690400000,
                'remains_time': 5554012,
                'current_interval_total_count': 0,
                'current_interval_usage_count': 0,
                'model_name': 'general',
                'current_weekly_total_count': 0,
                'current_weekly_usage_count': 0,
                'current_interval_remaining_percent': 79,
                'current_weekly_remaining_percent': 82,
              },
              <Map<String, dynamic>>{
                <String, dynamic>{
                  'start_time': 1781654400000,
                  'end_time': 1781740800000,
                  'current_interval_total_count': 3,
                  'current_interval_usage_count': 0,
                  'model_name': 'video',
                  'current_interval_remaining_percent': 100,
                  'current_weekly_remaining_percent': 100,
                },
              }.first,
            ],
            'base_resp': <String, dynamic>{
              'status_code': 0,
              'status_msg': 'success',
            },
          }, 200),
        ),
      );

      final usage = await api.getUsage(apiKey: 'k', accountId: 'a1');

      // general: 21% used (interval), 18% used (weekly)
      // video: 0% used (interval), 0% used (weekly)
      final generalInterval = usage.windows.firstWhere(
        (w) => w.label == 'general',
      );
      expect(generalInterval.utilization, closeTo(21, 0.001));
      expect(generalInterval.resetsAtMs, 1781690400000);

      final generalWeekly = usage.windows.firstWhere(
        (w) => w.label == 'general Weekly',
      );
      expect(generalWeekly.utilization, closeTo(18, 0.001));

      final videoInterval = usage.windows.firstWhere(
        (w) => w.label == 'video',
      );
      expect(videoInterval.utilization, 0);
    });

    test('falls back to total/used when percent is missing', () async {
      final api = MiniMaxUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'model_remains': <Map<String, dynamic>>[
              <String, dynamic>{
                'model_name': 'no-percent',
                'current_interval_total_count': 200,
                'current_interval_usage_count': 50,
                'end_time': 1893456000000,
              },
            ],
          }, 200),
        ),
      );

      final usage = await api.getUsage(apiKey: 'k', accountId: 'a1');

      expect(usage.windows.single.label, 'no-percent');
      // 50 / 200 = 25% used.
      expect(usage.windows.single.used, 50);
      expect(usage.windows.single.limit, 200);
      expect(usage.windows.single.remaining, 150);
      expect(usage.windows.single.utilization, closeTo(25, 0.001));
    });

    test('omits debug payload on non-200 responses', () async {
      final api = MiniMaxUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'base_resp': <String, dynamic>{
              'status_code': 1001,
              'status_msg': 'invalid token',
            },
          }, 401),
        ),
      );

      await expectLater(
        api.getUsage(
          apiKey: 'bad',
          accountId: 'a1',
          includeDebugPayload: true,
        ),
        throwsA(isA<ProviderUsageApiException>()),
      );
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

  group('ZaiUsageApi', () {
    test('GETs the monitor quota endpoint with a Bearer + UA', () async {
      RequestOptions? seen;
      final api = ZaiUsageApi(
        dio: _dioWith((o) {
          seen = o;
          return _json(<String, dynamic>{
            'data': <String, dynamic>{
              'limits': <Map<String, dynamic>>[],
            },
          }, 200);
        }),
      );

      await api.getUsage(apiKey: 'test-key', accountId: 'a1');

      expect(seen!.method, 'GET');
      expect(
        seen!.uri.toString(),
        'https://api.z.ai/api/monitor/usage/quota/limit',
      );
      expect(seen!.headers['Authorization'], 'Bearer test-key');
      expect(seen!.headers['User-Agent'], isNotNull);
    });

    // Mirrors the live payload documented by community tools (openusage,
    // zai-usage-tracker) — the endpoint is not in Z.AI's public API reference.
    test('parses TOKENS_LIMIT (session + weekly) and TIME_LIMIT windows',
        () async {
      final api = ZaiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'code': 200,
            'success': true,
            'data': <String, dynamic>{
              'limits': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'TOKENS_LIMIT',
                  'unit': 3,
                  'number': 5,
                  'usage': 800000000,
                  'currentValue': 127694464,
                  'remaining': 672305536,
                  'percentage': 15,
                  'nextResetTime': 1770648402389,
                },
                <String, dynamic>{
                  'type': 'TOKENS_LIMIT',
                  'unit': 6,
                  'number': 7,
                  'usage': 2000000000,
                  'currentValue': 500000000,
                  'remaining': 1500000000,
                  'percentage': 25,
                  'nextResetTime': 1770648402389,
                },
                <String, dynamic>{
                  'type': 'TIME_LIMIT',
                  'unit': 5,
                  'number': 1,
                  'usage': 4000,
                  'currentValue': 1828,
                  'remaining': 2172,
                  'percentage': 45,
                  'usageDetails': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'modelCode': 'search-prime',
                      'usage': 1433,
                    },
                  ],
                },
              ],
            },
          }, 200),
        ),
      );

      final usage = await api.getUsage(apiKey: 'k', accountId: 'a1');

      expect(usage.windows, hasLength(3));
      expect(usage.type, ProviderUsageType.zai);

      final session = usage.windows[0];
      expect(session.label, 'Session');
      expect(session.utilization, closeTo(15, 0.001));
      expect(session.used, 127694464);
      expect(session.limit, 800000000);
      expect(session.remaining, 672305536);
      expect(session.resetsAtMs, 1770648402389);

      final weekly = usage.windows[1];
      expect(weekly.label, 'Weekly');
      expect(weekly.utilization, closeTo(25, 0.001));

      // TIME_LIMIT carries no nextResetTime — parser derives next 1st-of-month.
      final searches = usage.windows[2];
      expect(searches.label, 'Web Searches');
      expect(searches.utilization, closeTo(45, 0.001));
      expect(searches.used, 1828);
      expect(searches.limit, 4000);
      expect(searches.remaining, 2172);
      expect(
        searches.resetsAtMs,
        greaterThan(DateTime.now().millisecondsSinceEpoch),
      );

      // Production default: no debug payload leaks into `extra`.
      expect(usage.extra, isEmpty);
    });

    // Mirrors the live payload returned by api.z.ai for a GLM Coding Lite plan
    // (probed 2026-06-17). Note: TOKENS_LIMIT windows carry ONLY `percentage`
    // — no usage/currentValue/remaining — which is the norm for token quotas,
    // so the card shows the % bar without a used/limit count line.
    test('parses the live production payload (percentage-only TOKENS_LIMIT)',
        () async {
      final api = ZaiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'code': 200,
            'msg': 'Operation successful',
            'data': <String, dynamic>{
              'limits': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'TIME_LIMIT',
                  'unit': 5,
                  'number': 1,
                  'usage': 100,
                  'currentValue': 96,
                  'remaining': 4,
                  'percentage': 96,
                  'nextResetTime': 1784320251987,
                  'usageDetails': <Map<String, dynamic>>[
                    <String, dynamic>{'modelCode': 'search-prime', 'usage': 88},
                    <String, dynamic>{'modelCode': 'web-reader', 'usage': 8},
                  ],
                },
                <String, dynamic>{
                  'type': 'TOKENS_LIMIT',
                  'unit': 3,
                  'number': 5,
                  'percentage': 77,
                  'nextResetTime': 1781746456175,
                },
                <String, dynamic>{
                  'type': 'TOKENS_LIMIT',
                  'unit': 6,
                  'number': 1,
                  'percentage': 15,
                  'nextResetTime': 1782333051984,
                },
              ],
              'level': 'lite',
            },
            'success': true,
          }, 200),
        ),
      );

      final usage = await api.getUsage(apiKey: 'k', accountId: 'a1');

      expect(usage.windows, hasLength(3));

      final searches = usage.windows[0];
      expect(searches.label, 'Web Searches');
      expect(searches.utilization, closeTo(96, 0.001));
      expect(searches.used, 96);
      expect(searches.limit, 100);
      expect(searches.remaining, 4);
      expect(searches.resetsAtMs, 1784320251987);

      // Token windows report only a percentage — utilization is populated but
      // there is no used/limit (card omits the count line for these).
      final session = usage.windows[1];
      expect(session.label, 'Session');
      expect(session.utilization, closeTo(77, 0.001));
      expect(session.used, isNull);
      expect(session.limit, isNull);
      expect(session.resetsAtMs, 1781746456175);

      final weekly = usage.windows[2];
      expect(weekly.label, 'Weekly');
      expect(weekly.utilization, closeTo(15, 0.001));
      expect(weekly.resetsAtMs, 1782333051984);
    });

    test('derives utilization from usage/currentValue when percentage is absent',
        () async {
      final api = ZaiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'data': <String, dynamic>{
              'limits': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'TOKENS_LIMIT',
                  'unit': 3,
                  'number': 5,
                  'usage': 1000,
                  'currentValue': 250,
                  'remaining': 750,
                },
              ],
            },
          }, 200),
        ),
      );

      final usage = await api.getUsage(apiKey: 'k', accountId: 'a1');

      expect(usage.windows.single.label, 'Session');
      expect(usage.windows.single.utilization, closeTo(25, 0.001));
      expect(usage.windows.single.used, 250);
      expect(usage.windows.single.limit, 1000);
      expect(usage.windows.single.remaining, 750);
    });

    test('skips limits that carry no usable signal', () async {
      final api = ZaiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'data': <String, dynamic>{
              'limits': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'TOKENS_LIMIT',
                  'unit': 3,
                  'number': 5,
                },
              ],
            },
          }, 200),
        ),
      );

      final usage = await api.getUsage(apiKey: 'k', accountId: 'a1');

      expect(usage.windows, isEmpty);
    });

    test('returns no windows when the data envelope is missing', () async {
      final api = ZaiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'code': 200,
            'success': true,
          }, 200),
        ),
      );

      final usage = await api.getUsage(apiKey: 'k', accountId: 'a1');

      expect(usage.windows, isEmpty);
    });

    test('attaches raw payload only when includeDebugPayload is true',
        () async {
      final api = ZaiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{
            'data': <String, dynamic>{
              'limits': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'TOKENS_LIMIT',
                  'unit': 3,
                  'number': 5,
                  'percentage': 15,
                },
              ],
            },
          }, 200),
        ),
      );

      final usage = await api.getUsage(
        apiKey: 'test-key',
        accountId: 'a1',
        includeDebugPayload: true,
      );

      expect(usage.extra['endpoint'], '/api/monitor/usage/quota/limit');
      expect(usage.extra['status'], 200);
      expect(usage.extra['window_count'], 1);
      expect(usage.extra['raw_payload'], isA<String>());
      expect(usage.extra['raw_payload_compact'], contains('TOKENS_LIMIT'));
    });

    test('honours a custom base URL', () async {
      RequestOptions? seen;
      final api = ZaiUsageApi(
        dio: _dioWith((o) {
          seen = o;
          return _json(<String, dynamic>{
            'data': <String, dynamic>{
              'limits': <Map<String, dynamic>>[],
            },
          }, 200);
        }),
      );

      await api.getUsage(
        apiKey: 'k',
        accountId: 'a1',
        baseUrl: 'https://gw.example.com/',
      );

      expect(
        seen!.uri.toString(),
        'https://gw.example.com/api/monitor/usage/quota/limit',
      );
    });

    test('surfaces the server error body on 401', () async {
      final api = ZaiUsageApi(
        dio: _dioWith(
          (o) => _json(<String, dynamic>{'msg': 'invalid api key'}, 401),
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
                allOf(contains('401'), contains('invalid api key')),
              ),
        ),
      );
    });

    // Guards the secure-storage round-trip: addAccount persists a
    // ProviderAccount as JSON, and loadAccounts reads it back. A new union
    // variant that fails to round-trip would silently drop the saved account.
    test('ProviderCredentials.zai round-trips through JSON storage', () {
      final account = ProviderAccount(
        id: 'z1',
        name: 'My Z.AI',
        type: ProviderUsageType.zai,
        credentials: ProviderCredentials.zai(
          ZaiCredentials(apiKey: 'sk.test', baseUrl: zaiDefaultBaseUrl),
        ),
      );

      final decoded = ProviderAccount.fromJson(
        Map<String, dynamic>.from(account.toJson()),
      );

      expect(decoded.id, 'z1');
      expect(decoded.type, ProviderUsageType.zai);

      late ZaiCredentials zai;
      decoded.credentials.when(
        kimi: (_) => fail('expected zai, decoded as kimi'),
        miniMax: (_) => fail('expected zai, decoded as miniMax'),
        zai: (c) => zai = c,
      );
      expect(zai.apiKey, 'sk.test');
      expect(zai.baseUrl, zaiDefaultBaseUrl);
    });
  });
}
