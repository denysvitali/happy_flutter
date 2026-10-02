import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/provider_usage_api.dart';

/// Supplies already-decoded bodies or raw strings at the API's Dio boundary.
Dio _dioWithBody(
  Object? Function(RequestOptions options) body, {
  int statusCode = 200,
}) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: statusCode,
          data: body(options),
        ),
      ),
    ),
  );
  addTearDown(() => dio.close(force: true));
  return dio;
}

void main() {
  group('Provider usage payload contracts', () {
    test('Kimi data rows take precedence even when none are usable', () async {
      final api = KimiUsageApi(
        dio: _dioWithBody(
          (_) => <String, dynamic>{
            'data': <dynamic>[
              null,
              4,
              <String, dynamic>{'used': 'invalid'},
            ],
            'usage': <String, dynamic>{'limit': 100, 'used': 20},
          },
        ),
      );

      final usage = await api.getUsage(apiKey: 'key', accountId: 'kimi');

      expect(usage.windows, isEmpty);
      expect(usage.error, isNull);
    });

    test('Kimi malformed success fails without requesting fallback', () async {
      final requests = <String>[];
      final api = KimiUsageApi(
        dio: _dioWithBody((options) {
          requests.add(options.path);
          return '{broken';
        }),
      );

      await expectLater(
        api.getUsage(apiKey: 'key', accountId: 'kimi'),
        throwsFormatException,
      );
      expect(requests, hasLength(1));
      expect(requests.single, endsWith('/usages'));
    });

    test('MiniMax invalid model rows fall through to package totals', () async {
      final api = MiniMaxUsageApi(
        dio: _dioWithBody(
          (_) => <String, dynamic>{
            'model_remains': <dynamic>[
              false,
              <String, dynamic>{'model_name': 'missing quota'},
            ],
            'package_remain': <String, dynamic>{
              'total_count': '100',
              'remain_count': '25',
              'reset_at': '2099-01-01T00:00:00Z',
            },
            'total_count': 50,
            'usage_count': 0,
          },
        ),
      );

      final usage = await api.getUsage(apiKey: 'key', accountId: 'minimax');

      expect(usage.windows, hasLength(1));
      expect(usage.windows.single.label, 'Token Plan');
      expect(usage.windows.single.used, 75);
      expect(usage.windows.single.remaining, 25);
      expect(
        usage.windows.single.resetsAtMs,
        DateTime.utc(2099).millisecondsSinceEpoch,
      );
    });

    test('MiniMax percent and count paths retain distinct clamping', () async {
      final api = MiniMaxUsageApi(
        dio: _dioWithBody(
          (_) => <String, dynamic>{
            'model_remains': <Map<String, dynamic>>[
              <String, dynamic>{
                'current_interval_remaining_percent': -20,
                'current_interval_total_count': 100,
                'current_interval_usage_count': 2,
                'current_weekly_total_count': 100,
                'current_weekly_usage_count': 150,
                'weekly_end_time': '1893456000',
              },
            ],
          },
        ),
      );

      final usage = await api.getUsage(apiKey: 'key', accountId: 'minimax');

      expect(usage.windows, hasLength(2));
      expect(usage.windows[0].utilization, 100);
      expect(usage.windows[0].used, 100);
      expect(usage.windows[1].utilization, 150);
      expect(usage.windows[1].used, 150);
      expect(usage.windows[1].remaining, 0);
      expect(usage.windows[1].resetsAtMs, 1893456000000);
    });

    test('MiniMax malformed success remains an empty usage response', () async {
      final api = MiniMaxUsageApi(dio: _dioWithBody((_) => '{broken'));

      final usage = await api.getUsage(
        apiKey: 'key',
        accountId: 'minimax',
        includeDebugPayload: true,
      );

      expect(usage.windows, isEmpty);
      expect(usage.error, isNull);
      expect(usage.extra['raw_payload_compact'], jsonEncode('{broken'));
    });

    test('Zai ignores malformed rows and preserves count overflow', () async {
      final api = ZaiUsageApi(
        dio: _dioWithBody(
          (_) => <String, dynamic>{
            'data': <String, dynamic>{
              'limits': <dynamic>[
                'invalid',
                <String, dynamic>{'percentage': 'invalid'},
                <String, dynamic>{
                  'type': 'TOKENS_LIMIT',
                  'unit': '6.0',
                  'usage': 100,
                  'currentValue': 125,
                  'nextResetTime': '1893456000',
                },
              ],
            },
          },
        ),
      );

      final usage = await api.getUsage(apiKey: 'key', accountId: 'zai');

      expect(usage.windows, hasLength(1));
      expect(usage.windows.single.label, 'Weekly');
      expect(usage.windows.single.utilization, 125);
      expect(usage.windows.single.resetsAtMs, 1893456000000);
    });

    test('Grok unwraps account and cents without mutating either', () async {
      final user = <String, dynamic>{
        'data': <String, dynamic>{
          'user': <String, dynamic>{'user_id': 42, 'email_address': 'a@b.c'},
        },
      };
      final billing = <String, dynamic>{
        'credits': <String, dynamic>{
          'billing': <String, dynamic>{
            'config': <String, dynamic>{
              'monthly_limit': <String, dynamic>{'val': '1000'},
              'used': <String, dynamic>{'val': '1500'},
              'on_demand_cap': 0,
              'current_period': <String, dynamic>{
                'end': '2099-01-01T00:00:00Z',
              },
            },
          },
        },
      };
      final originalUser = jsonEncode(user);
      final originalBilling = jsonEncode(billing);
      RequestOptions? billingRequest;
      final api = GrokUsageApi(
        dio: _dioWithBody((options) {
          if (options.uri.path.endsWith('/user')) return user;
          billingRequest = options;
          return billing;
        }),
      );

      final usage = await api.getUsage(accessToken: 'token', accountId: 'grok');

      expect(billingRequest!.headers['x-userid'], '42');
      expect(usage.extra['email'], 'a@b.c');
      expect(usage.windows.single.limit, 10);
      expect(usage.windows.single.used, 15);
      expect(usage.windows.single.remaining, 0);
      expect(usage.windows.single.utilization, 100);
      expect(
        usage.windows.single.resetsAtMs,
        DateTime.utc(2099).millisecondsSinceEpoch,
      );
      expect(jsonEncode(user), originalUser);
      expect(jsonEncode(billing), originalBilling);
    });

    test(
      'Grok keeps JWT identity when successful account body is invalid',
      () async {
        final claims = base64Url.encode(utf8.encode('{"sub":"jwt-user"}'));
        RequestOptions? billingRequest;
        final api = GrokUsageApi(
          dio: _dioWithBody((options) {
            if (options.uri.path.endsWith('/user')) return 'not json';
            billingRequest = options;
            return <dynamic>[];
          }),
        );

        final usage = await api.getUsage(
          accessToken: 'header.$claims.signature',
          accountId: 'grok',
        );

        expect(billingRequest!.headers['x-userid'], 'jwt-user');
        expect(usage.windows, isEmpty);
        expect(usage.error, isNull);
      },
    );

    test('Grok stops at failed account lookup without JWT identity', () async {
      var requests = 0;
      final api = GrokUsageApi(
        dio: _dioWithBody((_) {
          requests++;
          return <String, dynamic>{
            'error': <String, dynamic>{'message': 'expired'},
          };
        }, statusCode: 401),
      );

      await expectLater(
        api.getUsage(accessToken: 'invalid', accountId: 'grok'),
        throwsA(
          isA<ProviderUsageApiException>()
              .having((error) => error.statusCode, 'status', 401)
              .having((error) => error.message, 'detail', contains('expired')),
        ),
      );
      expect(requests, 1);
    });

    test('Qwen unusable row lists fall through to the next list', () async {
      final api = QwenUsageApi(
        dio: _dioWithBody(
          (_) => <String, dynamic>{
            'result': <String, dynamic>{
              'credits': <String, dynamic>{
                'limits': <dynamic>[
                  false,
                  <String, dynamic>{'name': 'empty'},
                ],
                'quotas': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'plan': 'monthly',
                    'percentage': 25,
                    'total_credits': <String, dynamic>{'invalid': true},
                    'limit': 80,
                    'used': 70,
                  },
                ],
                'percentage': 90,
              },
            },
          },
        ),
      );

      final usage = await api.getUsage(apiKey: 'key', accountId: 'qwen');

      expect(usage.windows, hasLength(1));
      expect(usage.windows.single.label, 'monthly');
      expect(usage.windows.single.limit, 80);
      expect(usage.windows.single.used, 20);
      expect(usage.windows.single.remaining, 60);
      expect(usage.windows.single.utilization, 25);
    });

    test(
      'Qwen falls back to totals after every row list is unusable',
      () async {
        final api = QwenUsageApi(
          dio: _dioWithBody(
            (_) => <String, dynamic>{
              'data': <String, dynamic>{
                'limits': <dynamic>[null, false],
                'limit': 10,
                'used': 15,
                'reset_time': 'invalid',
                'reset_in': '1.5',
              },
            },
          ),
        );
        final before = DateTime.now().millisecondsSinceEpoch;

        final usage = await api.getUsage(apiKey: 'key', accountId: 'qwen');

        final after = DateTime.now().millisecondsSinceEpoch;
        expect(usage.windows.single.used, 15);
        expect(usage.windows.single.utilization, 100);
        expect(
          usage.windows.single.resetsAtMs,
          inInclusiveRange(before + 1000, after + 1000),
        );
      },
    );

    test('Qwen rejects successful JSON arrays as non-object bodies', () async {
      final api = QwenUsageApi(dio: _dioWithBody((_) => <dynamic>[]));

      final usage = await api.getUsage(apiKey: 'key', accountId: 'qwen');

      expect(usage.windows, isEmpty);
      expect(usage.error, contains('non-JSON'));
      expect(usage.extra, isEmpty);
    });
  });
}
