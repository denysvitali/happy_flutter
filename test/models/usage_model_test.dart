import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/usage.dart';

void main() {
  group('UsageDataPoint', () {
    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'timestamp': 1700000000,
          'tokens': {'claude-3': 1500, 'gpt-4': 500},
          'cost': {'claude-3': 0.045, 'gpt-4': 0.02},
          'reportCount': 3,
        };

        final point = UsageDataPoint.fromJson(json);

        expect(point.timestamp, 1700000000);
        expect(point.tokens, {'claude-3': 1500, 'gpt-4': 500});
        expect(point.cost, {'claude-3': 0.045, 'gpt-4': 0.02});
        expect(point.reportCount, 3);
      });

      test('handles double timestamp via _asUsageInt', () {
        final json = {
          'timestamp': 1700000000.0,
          'tokens': {},
          'cost': {},
          'reportCount': 0,
        };

        final point = UsageDataPoint.fromJson(json);
        expect(point.timestamp, 1700000000);
      });

      test('handles int cost via _asUsageDouble', () {
        final json = {
          'timestamp': 0,
          'tokens': {},
          'cost': {'model': 5},
          'reportCount': 0,
        };

        final point = UsageDataPoint.fromJson(json);
        expect(point.cost['model'], 5.0);
      });

      test('handles missing tokens and cost as empty', () {
        final json = {
          'timestamp': 0,
          'reportCount': 0,
        };

        final point = UsageDataPoint.fromJson(json);
        expect(point.tokens, isEmpty);
        expect(point.cost, isEmpty);
      });

      test('handles non-map tokens gracefully', () {
        final json = {
          'timestamp': 0,
          'tokens': 'invalid',
          'cost': 'invalid',
          'reportCount': 0,
        };

        final point = UsageDataPoint.fromJson(json);
        expect(point.tokens, isEmpty);
        expect(point.cost, isEmpty);
      });

      test('defaults missing numeric fields to zero', () {
        final json = <String, dynamic>{};

        final point = UsageDataPoint.fromJson(json);
        expect(point.timestamp, 0);
        expect(point.reportCount, 0);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final point = UsageDataPoint(
          timestamp: 1700000000,
          tokens: {'model-a': 100},
          cost: {'model-a': 0.01},
          reportCount: 1,
        );

        final json = point.toJson();

        expect(json['timestamp'], 1700000000);
        expect(json['tokens'], {'model-a': 100});
        expect(json['cost'], {'model-a': 0.01});
        expect(json['reportCount'], 1);
      });
    });
  });

  group('UsageResponse', () {
    group('fromJson', () {
      test('parses list of usage data points', () {
        final json = {
          'usage': [
            {
              'timestamp': 1000,
              'tokens': {'m': 50},
              'cost': {'m': 0.005},
              'reportCount': 1,
            },
            {
              'timestamp': 2000,
              'tokens': {'m': 100},
              'cost': {'m': 0.01},
              'reportCount': 2,
            },
          ],
        };

        final response = UsageResponse.fromJson(json);

        expect(response.usage.length, 2);
        expect(response.usage.first.timestamp, 1000);
        expect(response.usage.last.timestamp, 2000);
      });

      test('handles empty usage list', () {
        final json = {'usage': <dynamic>[]};

        final response = UsageResponse.fromJson(json);
        expect(response.usage, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes usage list', () {
        final response = UsageResponse(
          usage: [
            UsageDataPoint(
              timestamp: 1000,
              tokens: {'m': 50},
              cost: {'m': 0.005},
              reportCount: 1,
            ),
          ],
        );

        final json = response.toJson();
        expect(json['usage'], isA<List>());
        expect((json['usage'] as List).length, 1);
      });
    });
  });

  group('UsageQueryParams', () {
    group('toJson', () {
      test('includes all set fields', () {
        final params = UsageQueryParams(
          sessionId: 'sess-1',
          startTime: 1000,
          endTime: 2000,
          groupBy: UsageGroupBy.day,
        );

        final json = params.toJson();

        expect(json['sessionId'], 'sess-1');
        expect(json['startTime'], 1000);
        expect(json['endTime'], 2000);
        expect(json['groupBy'], 'day');
      });

      test('omits null fields', () {
        final params = UsageQueryParams();

        final json = params.toJson();

        expect(json.containsKey('sessionId'), isFalse);
        expect(json.containsKey('startTime'), isFalse);
        expect(json.containsKey('endTime'), isFalse);
        expect(json.containsKey('groupBy'), isFalse);
      });

      test('groupBy hour serializes correctly', () {
        final params = UsageQueryParams(groupBy: UsageGroupBy.hour);
        final json = params.toJson();
        expect(json['groupBy'], 'hour');
      });
    });
  });

  group('UsageGroupBy', () {
    test('has correct name values', () {
      expect(UsageGroupBy.hour.name, 'hour');
      expect(UsageGroupBy.day.name, 'day');
    });
  });

  group('UsageTotals', () {
    group('fromDataPoints', () {
      test('aggregates tokens and costs across data points', () {
        final dataPoints = [
          UsageDataPoint(
            timestamp: 1000,
            tokens: {'model-a': 100, 'model-b': 50},
            cost: {'model-a': 0.01, 'model-b': 0.005},
            reportCount: 1,
          ),
          UsageDataPoint(
            timestamp: 2000,
            tokens: {'model-a': 200, 'model-c': 75},
            cost: {'model-a': 0.02, 'model-c': 0.008},
            reportCount: 1,
          ),
        ];

        final totals = UsageTotals.fromDataPoints(dataPoints);

        expect(totals.totalTokens, 425);
        expect(totals.totalCost, closeTo(0.043, 0.0001));
        expect(totals.tokensByModel['model-a'], 300);
        expect(totals.tokensByModel['model-b'], 50);
        expect(totals.tokensByModel['model-c'], 75);
        expect(totals.costByModel['model-a'], closeTo(0.03, 0.0001));
      });

      test('handles empty data points', () {
        final totals = UsageTotals.fromDataPoints([]);

        expect(totals.totalTokens, 0);
        expect(totals.totalCost, 0.0);
        expect(totals.tokensByModel, isEmpty);
        expect(totals.costByModel, isEmpty);
      });

      test('handles single data point', () {
        final dataPoints = [
          UsageDataPoint(
            timestamp: 1000,
            tokens: {'m': 100},
            cost: {'m': 0.01},
            reportCount: 5,
          ),
        ];

        final totals = UsageTotals.fromDataPoints(dataPoints);

        expect(totals.totalTokens, 100);
        expect(totals.totalCost, 0.01);
      });
    });
  });

  group('UsagePeriod', () {
    test('has expected values', () {
      expect(UsagePeriod.values.length, 3);
      expect(UsagePeriod.values, contains(UsagePeriod.today));
      expect(UsagePeriod.values, contains(UsagePeriod.sevenDays));
      expect(UsagePeriod.values, contains(UsagePeriod.thirtyDays));
    });
  });
}
