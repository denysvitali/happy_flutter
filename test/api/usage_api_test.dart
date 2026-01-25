import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/usage_api.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/models/usage.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';

@GenerateMocks([ApiClient])
import 'usage_api_test.mocks.dart';

void main() {
  group('UsageApi', () {
    late MockApiClient mockClient;
    late UsageApi usageApi;

    setUp(() {
      mockClient = MockApiClient();
      usageApi = UsageApi(client: mockClient);
    });

    group('queryUsage', () {
      test('successfully queries usage with params', () async {
        final mockResponse = {
          'usage': [
            {
              'timestamp': 1640995200,
              'tokens': {'claude-3': 1000, 'gpt-4': 500},
              'cost': {'claude-3': 0.01, 'gpt-4': 0.02},
              'reportCount': 5,
            },
          ],
        };

        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final params = UsageQueryParams(
          sessionId: 'session-123',
          startTime: 1640995200,
          endTime: 1641081600,
          groupBy: UsageGroupBy.day,
        );

        final result = await usageApi.queryUsage(params);

        expect(result.usage, hasLength(1));
        expect(result.usage.first.tokens['claude-3'], 1000);
        expect(result.usage.first.cost['gpt-4'], 0.02);
        expect(result.usage.first.reportCount, 5);

        verify(mockClient.post(
          '/v1/usage/query',
          data: {
            'sessionId': 'session-123',
            'startTime': 1640995200,
            'endTime': 1641081600,
            'groupBy': 'day',
          },
        )).called(1);
      });

      test('throws exception when session not found (404)', () async {
        when(mockClient.post(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'error': 'Session not found'},
          statusCode: 404,
          requestOptions: RequestOptions(path: ''),
        ));

        final params = UsageQueryParams(sessionId: 'non-existent');

        expect(
          () => usageApi.queryUsage(params),
          throwsA(isA<UsageApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'Session not found')),
        );
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.post(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {},
          statusCode: 500,
          requestOptions: RequestOptions(path: ''),
        ));

        final params = UsageQueryParams();

        expect(
          () => usageApi.queryUsage(params),
          throwsA(isA<UsageApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message',
                  contains('Failed to query usage'))),
        );
      });

      test('throws exception on invalid response data', () async {
        when(mockClient.post(
          any,
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'invalid': 'data'},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final params = UsageQueryParams();

        expect(
          () => usageApi.queryUsage(params),
          throwsA(isA<UsageApiException>()
              .having((e) => e.message, 'message',
                  contains('Failed to parse usage response'))),
        );
      });
    });

    group('getUsageForPeriod', () {
      test('gets usage for today with hourly grouping', () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final startTime = today.millisecondsSinceEpoch ~/ 1000;

        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'usage': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await usageApi.getUsageForPeriod(UsagePeriod.today);

        final captured = verify(mockClient.post(
          '/v1/usage/query',
          data: captureAnyNamed('data'),
        )).captured.single as Map<String, dynamic>;

        expect(captured['groupBy'], 'hour');
        expect(captured['startTime'], greaterThanOrEqualTo(startTime));
      });

      test('gets usage for 7 days with daily grouping', () async {
        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'usage': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await usageApi.getUsageForPeriod(UsagePeriod.sevenDays);

        final captured = verify(mockClient.post(
          '/v1/usage/query',
          data: captureAnyNamed('data'),
        )).captured.single as Map<String, dynamic>;

        expect(captured['groupBy'], 'day');
        final sevenDaysAgo = DateTime.now().millisecondsSinceEpoch ~/ 1000 -
            (7 * 24 * 60 * 60);
        expect(captured['startTime'],
            greaterThanOrEqualTo(sevenDaysAgo - 10)); // 10s tolerance
      });

      test('gets usage for 30 days with daily grouping', () async {
        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'usage': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await usageApi.getUsageForPeriod(UsagePeriod.thirtyDays);

        final captured = verify(mockClient.post(
          '/v1/usage/query',
          data: captureAnyNamed('data'),
        )).captured.single as Map<String, dynamic>;

        expect(captured['groupBy'], 'day');
        final thirtyDaysAgo = DateTime.now().millisecondsSinceEpoch ~/ 1000 -
            (30 * 24 * 60 * 60);
        expect(captured['startTime'],
            greaterThanOrEqualTo(thirtyDaysAgo - 10)); // 10s tolerance
      });

      test('includes session ID when provided', () async {
        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'usage': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await usageApi.getUsageForPeriod(
          UsagePeriod.today,
          sessionId: 'session-123',
        );

        final captured = verify(mockClient.post(
          '/v1/usage/query',
          data: captureAnyNamed('data'),
        )).captured.single as Map<String, dynamic>;

        expect(captured['sessionId'], 'session-123');
      });
    });

    group('Convenience methods', () {
      test('getTodayUsage calls getUsageForPeriod with today', () async {
        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'usage': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await usageApi.getTodayUsage();

        verify(mockClient.post(
          '/v1/usage/query',
          data: argThat(
            allOf([
              containsPair('groupBy', 'hour'),
              // Start of today
            ]),
            named: 'data'),
        )).called(1);
      });

      test('getSevenDayUsage calls getUsageForPeriod with 7 days', () async {
        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'usage': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await usageApi.getSevenDayUsage();

        verify(mockClient.post(
          '/v1/usage/query',
          data: argThat(
            allOf([
              containsPair('groupBy', 'day'),
            ]),
            named: 'data'),
        )).called(1);
      });

      test('getThirtyDayUsage calls getUsageForPeriod with 30 days', () async {
        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'usage': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await usageApi.getThirtyDayUsage();

        verify(mockClient.post(
          '/v1/usage/query',
          data: argThat(
            allOf([
              containsPair('groupBy', 'day'),
            ]),
            named: 'data'),
        )).called(1);
      });

      test('getSessionUsage calls getUsageForPeriod with session ID', () async {
        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'usage': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await usageApi.getSessionUsage('session-123');

        verify(mockClient.post(
          '/v1/usage/query',
          data: argThat(
            containsPair('sessionId', 'session-123'),
            named: 'data'),
        )).called(1);
      });
    });

    group('calculateTotals', () {
      test('calculates totals correctly', () {
        final dataPoints = [
          UsageDataPoint(
            timestamp: 1640995200,
            tokens: {'claude-3': 1000, 'gpt-4': 500},
            cost: {'claude-3': 0.01, 'gpt-4': 0.02},
            reportCount: 5,
          ),
          UsageDataPoint(
            timestamp: 1641081600,
            tokens: {'claude-3': 2000, 'gpt-4': 1000},
            cost: {'claude-3': 0.02, 'gpt-4': 0.04},
            reportCount: 10,
          ),
        ];

        final totals = UsageApi.calculateTotals(dataPoints);

        expect(totals.totalTokens, 4500);
        expect(totals.totalCost, 0.09);
        expect(totals.tokensByModel['claude-3'], 3000);
        expect(totals.tokensByModel['gpt-4'], 1500);
        expect(totals.costByModel['claude-3'], 0.03);
        expect(totals.costByModel['gpt-4'], 0.06);
      });

      test('handles empty data points', () {
        final totals = UsageApi.calculateTotals([]);

        expect(totals.totalTokens, 0);
        expect(totals.totalCost, 0.0);
        expect(totals.tokensByModel, isEmpty);
        expect(totals.costByModel, isEmpty);
      });
    });

    group('getUsageSummary', () {
      test('returns summary with usage and totals', () async {
        final mockResponse = {
          'usage': [
            {
              'timestamp': 1640995200,
              'tokens': {'claude-3': 1000},
              'cost': {'claude-3': 0.01},
              'reportCount': 5,
            },
            {
              'timestamp': 1641081600,
              'tokens': {'claude-3': 2000},
              'cost': {'claude-3': 0.02},
              'reportCount': 10,
            },
          ],
        };

        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: mockResponse,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        final summary = await usageApi.getUsageSummary(UsagePeriod.today);

        expect(summary.usage, hasLength(2));
        expect(summary.totals.totalTokens, 3000);
        expect(summary.totals.totalCost, 0.03);
        expect(summary.period, UsagePeriod.today);
      });

      test('includes session ID when provided', () async {
        when(mockClient.post(
          '/v1/usage/query',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'usage': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

        await usageApi.getUsageSummary(
          UsagePeriod.today,
          sessionId: 'session-123',
        );

        final captured = verify(mockClient.post(
          '/v1/usage/query',
          data: captureAnyNamed('data'),
        )).captured.single as Map<String, dynamic>;

        expect(captured['sessionId'], 'session-123');
      });
    });

    group('UsageSummary', () {
      test('provides most recent data point', () {
        final dataPoints = [
          UsageDataPoint(
            timestamp: 1640995200,
            tokens: {},
            cost: {},
            reportCount: 1,
          ),
          UsageDataPoint(
            timestamp: 1641081600,
            tokens: {},
            cost: {},
            reportCount: 2,
          ),
          UsageDataPoint(
            timestamp: 1641168000,
            tokens: {},
            cost: {},
            reportCount: 3,
          ),
        ];

        final summary = UsageSummary(
          usage: dataPoints,
          totals: UsageTotals(
            totalTokens: 0,
            totalCost: 0.0,
            tokensByModel: {},
            costByModel: {},
          ),
          period: UsagePeriod.sevenDays,
        );

        expect(summary.mostRecent?.reportCount, 3);
        expect(summary.oldest?.reportCount, 1);
      });

      test('calculates total report count', () {
        final dataPoints = [
          UsageDataPoint(
            timestamp: 1640995200,
            tokens: {},
            cost: {},
            reportCount: 5,
          ),
          UsageDataPoint(
            timestamp: 1641081600,
            tokens: {},
            cost: {},
            reportCount: 10,
          ),
        ];

        final summary = UsageSummary(
          usage: dataPoints,
          totals: UsageTotals(
            totalTokens: 0,
            totalCost: 0.0,
            tokensByModel: {},
            costByModel: {},
          ),
          period: UsagePeriod.sevenDays,
        );

        expect(summary.totalReportCount, 15);
      });

      test('calculates average cost per day', () {
        final dataPoints = [
          UsageDataPoint(
            timestamp: 1640995200,
            tokens: {},
            cost: {'model': 0.01},
            reportCount: 1,
          ),
          UsageDataPoint(
            timestamp: 1641081600,
            tokens: {},
            cost: {'model': 0.02},
            reportCount: 1,
          ),
        ];

        final totals = UsageTotals(
          totalTokens: 0,
          totalCost: 0.03,
          tokensByModel: {},
          costByModel: {},
        );

        final summary = UsageSummary(
          usage: dataPoints,
          totals: totals,
          period: UsagePeriod.sevenDays,
        );

        expect(summary.averageCostPerDay, 0.015);
      });

      test('calculates average tokens per day', () {
        final dataPoints = [
          UsageDataPoint(
            timestamp: 1640995200,
            tokens: {'model': 1000},
            cost: {},
            reportCount: 1,
          ),
          UsageDataPoint(
            timestamp: 1641081600,
            tokens: {'model': 2000},
            cost: {},
            reportCount: 1,
          ),
        ];

        final totals = UsageTotals(
          totalTokens: 3000,
          totalCost: 0.0,
          tokensByModel: {},
          costByModel: {},
        );

        final summary = UsageSummary(
          usage: dataPoints,
          totals: totals,
          period: UsagePeriod.sevenDays,
        );

        expect(summary.averageTokensPerDay, 1500.0);
      });

      test('handles empty usage data', () {
        final summary = UsageSummary(
          usage: [],
          totals: UsageTotals(
            totalTokens: 0,
            totalCost: 0.0,
            tokensByModel: {},
            costByModel: {},
          ),
          period: UsagePeriod.today,
        );

        expect(summary.mostRecent, isNull);
        expect(summary.oldest, isNull);
        expect(summary.totalReportCount, 0);
        expect(summary.averageCostPerDay, 0.0);
        expect(summary.averageTokensPerDay, 0.0);
      });
    });

    group('UsageApiException', () {
      test('has correct properties', () {
        final exception = const UsageApiException(
          'Test error',
          statusCode: 500,
        );

        expect(exception.message, 'Test error');
        expect(exception.statusCode, 500);
        expect(exception.toString(), 'UsageApiException: Test error');
      });

      test('implements equality', () {
        const exception1 = UsageApiException('Error', statusCode: 500);
        const exception2 = UsageApiException('Error', statusCode: 500);
        const exception3 = UsageApiException('Different', statusCode: 500);

        expect(exception1, equals(exception2));
        expect(exception1, isNot(equals(exception3)));
        expect(exception1.hashCode, equals(exception2.hashCode));
      });
    });
  });
}
