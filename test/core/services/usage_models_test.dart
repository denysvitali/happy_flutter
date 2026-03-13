import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/usage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UsageDataPoint', () {
    test('fromJson creates correct instance', () {
      final json = {
        'timestamp': 1710297600,
        'tokens': {'claude': 1000, 'gpt4': 500},
        'cost': {'claude': 0.03, 'gpt4': 0.05},
        'reportCount': 2,
      };

      final point = UsageDataPoint.fromJson(json);

      expect(point.timestamp, equals(1710297600));
      expect(point.tokens['claude'], equals(1000));
      expect(point.tokens['gpt4'], equals(500));
      expect(point.cost['claude'], equals(0.03));
      expect(point.reportCount, equals(2));
    });

    test('fromJson handles missing tokens and cost', () {
      final json = {
        'timestamp': 100,
        'reportCount': 0,
      };

      final point = UsageDataPoint.fromJson(json);

      expect(point.tokens, isEmpty);
      expect(point.cost, isEmpty);
    });

    test('fromJson handles double tokens via truncation', () {
      final json = {
        'timestamp': 100,
        'tokens': {'model': 10.7},
        'cost': {},
        'reportCount': 0,
      };

      final point = UsageDataPoint.fromJson(json);

      expect(point.tokens['model'], equals(10));
    });

    test('toJson produces correct map', () {
      final point = UsageDataPoint(
        timestamp: 500,
        tokens: {'m1': 100},
        cost: {'m1': 0.5},
        reportCount: 1,
      );

      final json = point.toJson();

      expect(json['timestamp'], equals(500));
      expect(json['tokens'], equals({'m1': 100}));
      expect(json['cost'], equals({'m1': 0.5}));
      expect(json['reportCount'], equals(1));
    });

    test('fromJson and toJson are symmetric', () {
      final original = {
        'timestamp': 999,
        'tokens': {'a': 10, 'b': 20},
        'cost': {'a': 1.5, 'b': 2.5},
        'reportCount': 3,
      };

      final point = UsageDataPoint.fromJson(original);
      final roundTrip = point.toJson();

      expect(roundTrip['timestamp'], equals(original['timestamp']));
      expect(roundTrip['tokens'], equals(original['tokens']));
      expect(roundTrip['cost'], equals(original['cost']));
      expect(roundTrip['reportCount'], equals(original['reportCount']));
    });
  });

  group('UsageResponse', () {
    test('fromJson creates correct instance', () {
      final json = {
        'usage': [
          {
            'timestamp': 100,
            'tokens': {'m': 10},
            'cost': {'m': 0.1},
            'reportCount': 1,
          },
          {
            'timestamp': 200,
            'tokens': {'m': 20},
            'cost': {'m': 0.2},
            'reportCount': 1,
          },
        ],
      };

      final response = UsageResponse.fromJson(json);

      expect(response.usage, hasLength(2));
      expect(response.usage[0].timestamp, equals(100));
      expect(response.usage[1].timestamp, equals(200));
    });

    test('fromJson handles empty usage list', () {
      final json = {'usage': <dynamic>[]};

      final response = UsageResponse.fromJson(json);

      expect(response.usage, isEmpty);
    });

    test('toJson produces correct structure', () {
      final response = UsageResponse(usage: [
        UsageDataPoint(
          timestamp: 100,
          tokens: {'m': 10},
          cost: {'m': 0.1},
          reportCount: 1,
        ),
      ]);

      final json = response.toJson();

      expect(json['usage'], hasLength(1));
      expect(json['usage'][0]['timestamp'], equals(100));
    });
  });

  group('UsageQueryParams', () {
    test('toJson includes all set fields', () {
      final params = UsageQueryParams(
        sessionId: 'session-1',
        startTime: 100,
        endTime: 200,
        groupBy: UsageGroupBy.day,
      );

      final json = params.toJson();

      expect(json['sessionId'], equals('session-1'));
      expect(json['startTime'], equals(100));
      expect(json['endTime'], equals(200));
      expect(json['groupBy'], equals('day'));
    });

    test('toJson omits null fields', () {
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

      expect(json['groupBy'], equals('hour'));
    });
  });

  group('UsageTotals', () {
    test('fromDataPoints aggregates tokens and costs', () {
      final dataPoints = [
        UsageDataPoint(
          timestamp: 100,
          tokens: {'claude': 100, 'gpt4': 50},
          cost: {'claude': 0.01, 'gpt4': 0.02},
          reportCount: 2,
        ),
        UsageDataPoint(
          timestamp: 200,
          tokens: {'claude': 200, 'gpt4': 75},
          cost: {'claude': 0.03, 'gpt4': 0.04},
          reportCount: 2,
        ),
      ];

      final totals = UsageTotals.fromDataPoints(dataPoints);

      expect(totals.totalTokens, equals(425));
      expect(totals.totalCost, closeTo(0.10, 0.001));
      expect(totals.tokensByModel['claude'], equals(300));
      expect(totals.tokensByModel['gpt4'], equals(125));
      expect(totals.costByModel['claude'], closeTo(0.04, 0.001));
      expect(totals.costByModel['gpt4'], closeTo(0.06, 0.001));
    });

    test('fromDataPoints handles empty list', () {
      final totals = UsageTotals.fromDataPoints([]);

      expect(totals.totalTokens, equals(0));
      expect(totals.totalCost, equals(0.0));
      expect(totals.tokensByModel, isEmpty);
      expect(totals.costByModel, isEmpty);
    });

    test('fromDataPoints handles single data point', () {
      final dataPoints = [
        UsageDataPoint(
          timestamp: 100,
          tokens: {'model-a': 500},
          cost: {'model-a': 0.05},
          reportCount: 1,
        ),
      ];

      final totals = UsageTotals.fromDataPoints(dataPoints);

      expect(totals.totalTokens, equals(500));
      expect(totals.totalCost, equals(0.05));
      expect(totals.tokensByModel['model-a'], equals(500));
    });
  });

  group('UsageGroupBy', () {
    test('has expected values', () {
      expect(UsageGroupBy.values, hasLength(2));
      expect(UsageGroupBy.hour.name, equals('hour'));
      expect(UsageGroupBy.day.name, equals('day'));
    });
  });

  group('UsagePeriod', () {
    test('has expected values', () {
      expect(UsagePeriod.values, hasLength(3));
    });
  });
}
