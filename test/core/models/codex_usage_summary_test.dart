import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/codex_usage_summary.dart';

void main() {
  group('CodexUsageSummary', () {
    test('parses account, rate limit, and credits fields', () {
      final summary = CodexUsageSummary.fromJson({
        'email': 'dev@example.com',
        'plan_type': 'pro',
        'rate_limit': {
          'allowed': true,
          'limit_reached': false,
          'primary_window': {
            'used_percent': 25,
            'limit_window_seconds': 18000,
            'reset_after_seconds': 60,
            'reset_at': 1700000000,
          },
        },
        'code_review_rate_limit': {'allowed': false, 'limit_reached': true},
        'credits': {
          'has_credits': true,
          'unlimited': false,
          'balance': '12.34',
        },
      });

      expect(summary.email, 'dev@example.com');
      expect(summary.planType, 'pro');
      expect(summary.rateLimit, isNotNull);
      expect(summary.rateLimit!.allowed, isTrue);
      expect(summary.rateLimit!.limitReached, isFalse);
      expect(summary.rateLimit!.primaryWindow, isNotNull);
      expect(summary.rateLimit!.primaryWindow!.usedPercent, 25);
      expect(summary.rateLimit!.primaryWindow!.limitWindowSeconds, 18000);
      expect(summary.rateLimit!.primaryWindow!.resetAfterSeconds, 60);
      expect(summary.rateLimit!.primaryWindow!.resetAt, 1700000000);
      expect(summary.codeReviewRateLimit, isNotNull);
      expect(summary.codeReviewRateLimit!.allowed, isFalse);
      expect(summary.codeReviewRateLimit!.limitReached, isTrue);
      expect(summary.credits, isNotNull);
      expect(summary.credits!.hasCredits, isTrue);
      expect(summary.credits!.unlimited, isFalse);
      expect(summary.credits!.balance, '12.34');
    });

    test('falls back for invalid values', () {
      final summary = CodexUsageSummary.fromJson({
        'email': 123,
        'plan_type': null,
        'rate_limit': {
          'allowed': 'yes',
          'limit_reached': 1,
          'primary_window': {
            'used_percent': 1.9,
            'limit_window_seconds': 'bad',
            'reset_after_seconds': null,
            'reset_at': 10.8,
          },
        },
        'credits': {'has_credits': null, 'unlimited': true, 'balance': 99},
      });

      expect(summary.email, isNull);
      expect(summary.planType, isNull);
      expect(summary.rateLimit, isNotNull);
      expect(summary.rateLimit!.allowed, isFalse);
      expect(summary.rateLimit!.limitReached, isFalse);
      expect(summary.rateLimit!.primaryWindow, isNotNull);
      expect(summary.rateLimit!.primaryWindow!.usedPercent, 1);
      expect(summary.rateLimit!.primaryWindow!.limitWindowSeconds, 0);
      expect(summary.rateLimit!.primaryWindow!.resetAfterSeconds, 0);
      expect(summary.rateLimit!.primaryWindow!.resetAt, 10);
      expect(summary.credits, isNotNull);
      expect(summary.credits!.hasCredits, isFalse);
      expect(summary.credits!.unlimited, isTrue);
      expect(summary.credits!.balance, isNull);
    });
  });
}
