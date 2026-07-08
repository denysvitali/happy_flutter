import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/grok_usage_summary.dart';

void main() {
  group('GrokUsageSummary', () {
    test('parses normalized daemon payload', () {
      final summary = GrokUsageSummary.fromJson(<String, dynamic>{
        'email': 'denys@example.com',
        'monthlyLimitCents': 15000,
        'usedCents': 269,
        'onDemandCapCents': 0,
        'billingPeriodStart': '2026-07-01T00:00:00+00:00',
        'billingPeriodEnd': '2026-08-01T00:00:00+00:00',
      });

      expect(summary.email, 'denys@example.com');
      expect(summary.monthlyLimitCents, 15000);
      expect(summary.usedCents, 269);
      expect(summary.onDemandCapCents, 0);
      expect(summary.usedDollars, closeTo(2.69, 0.001));
      expect(summary.monthlyLimitDollars, closeTo(150.0, 0.001));
      expect(summary.remainingCents, 15000 - 269);
      expect(summary.usedPercent, closeTo(269 / 15000 * 100, 0.01));
      expect(summary.hasUsageData, isTrue);
    });

    test('unwraps nested data envelope', () {
      final summary = GrokUsageSummary.fromJson(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'monthlyLimitCents': 1000,
          'usedCents': 250,
          'onDemandCapCents': 500,
        },
      });
      expect(summary.monthlyLimitCents, 1000);
      expect(summary.usedCents, 250);
      expect(summary.onDemandCapCents, 500);
      expect(summary.usedPercent, closeTo(25.0, 0.01));
    });

    test('parses raw Grok billing config shape', () {
      final summary = GrokUsageSummary.fromJson(<String, dynamic>{
        'email': 'a@b.c',
        'config': <String, dynamic>{
          'monthlyLimit': <String, dynamic>{'val': '2000'},
          'used': <String, dynamic>{'val': 400},
          'onDemandCap': <String, dynamic>{'val': '100'},
          'billingPeriodStart': '2026-01-01T00:00:00Z',
          'billingPeriodEnd': '2026-02-01T00:00:00Z',
        },
      });
      expect(summary.email, 'a@b.c');
      expect(summary.monthlyLimitCents, 2000);
      expect(summary.usedCents, 400);
      expect(summary.onDemandCapCents, 100);
      expect(summary.billingPeriodStart, '2026-01-01T00:00:00Z');
    });

    test('formatDollars pads cents', () {
      expect(GrokUsageSummary.formatDollars(2.69), r'$2.69');
      expect(GrokUsageSummary.formatDollars(150), r'$150.00');
    });

    test('clamps usedPercent over 100', () {
      final summary = GrokUsageSummary.fromJson(<String, dynamic>{
        'monthlyLimitCents': 100,
        'usedCents': 150,
        'onDemandCapCents': 0,
      });
      expect(summary.usedPercent, 100);
      expect(summary.remainingCents, 0);
    });
  });
}
