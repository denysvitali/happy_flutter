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
      expect(
        summary.rateLimit!.primaryWindow!.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );
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
      expect(summary.rateLimit!.primaryWindow!.resetAfterSeconds, isNull);
      expect(summary.rateLimit!.primaryWindow!.resetAt, 10);
      expect(summary.credits, isNotNull);
      expect(summary.credits!.hasCredits, isFalse);
      expect(summary.credits!.unlimited, isTrue);
      expect(summary.credits!.balance, isNull);
    });

    test('keeps missing reset metadata absent', () {
      final summary = CodexUsageSummary.fromJson({
        'rate_limit': {
          'allowed': true,
          'limit_reached': false,
          'primary_window': {'used_percent': 10},
        },
      });

      final window = summary.rateLimit!.primaryWindow!;
      expect(window.resetAfterSeconds, isNull);
      expect(window.resetAt, isNull);
      expect(window.expiresAt, isNull);
    });

    test('parses Spark limits from dedicated key', () {
      final summary = CodexUsageSummary.fromJson({
        'email': 'spark@example.com',
        'plan_type': 'team',
        'spark': {
          'allowed': true,
          'limit_reached': false,
          'primary_window': {
            'used_percent': 50,
            'limit_window_seconds': 3600,
            'reset_after_seconds': 120,
            'reset_at': 1700000100,
          },
          'secondary_window': {
            'used_percent': 70,
            'limit_window_seconds': 86400,
            'reset_after_seconds': 860,
            'reset_at': 1700000999,
          },
        },
      });

      expect(summary.sparkRateLimit, isNotNull);
      expect(summary.sparkRateLimit!.allowed, isTrue);
      expect(summary.sparkRateLimit!.limitReached, isFalse);
      expect(summary.sparkRateLimit!.primaryWindow, isNotNull);
      expect(summary.sparkRateLimit!.primaryWindow!.usedPercent, 50);
      expect(summary.sparkRateLimit!.primaryWindow!.resetAt, 1700000100);
      expect(summary.sparkRateLimit!.secondaryWindow, isNotNull);
      expect(summary.sparkRateLimit!.secondaryWindow!.usedPercent, 70);
    });

    test('parses dynamic additional rate limits', () {
      final summary = CodexUsageSummary.fromJson({
        'additional_rate_limits': [
          {
            'limit_name': 'GPT-5.3-Codex-Spark',
            'metered_feature': 'codex_bengalfox',
            'rate_limit': {
              'allowed': true,
              'limit_reached': false,
              'primary_window': {
                'used_percent': 15,
                'limit_window_seconds': 18000,
                'reset_after_seconds': 10792,
                'reset_at': 1777977286,
              },
              'secondary_window': {
                'used_percent': 85,
                'limit_window_seconds': 604800,
                'reset_after_seconds': 370390,
                'reset_at': 1778336883,
              },
            },
          },
          {
            'limit_name': 'GPT-5.4-Codex',
            'metered_feature': 'codex_future',
            'rate_limit': {'allowed': false, 'limit_reached': true},
          },
          {'limit_name': 'Ignored without rate limit'},
        ],
      });

      expect(summary.additionalRateLimits, hasLength(2));
      expect(
        summary.additionalRateLimits.first.displayName,
        'GPT-5.3-Codex-Spark',
      );
      expect(
        summary.additionalRateLimits.first.meteredFeature,
        'codex_bengalfox',
      );
      expect(summary.additionalRateLimits.first.rateLimit, isNotNull);
      expect(summary.additionalRateLimits.first.rateLimit!.allowed, isTrue);
      expect(
        summary.additionalRateLimits.first.rateLimit!.primaryWindow,
        isNotNull,
      );
      expect(
        summary
            .additionalRateLimits
            .first
            .rateLimit!
            .primaryWindow!
            .usedPercent,
        15,
      );
      expect(
        summary.additionalRateLimits.first.rateLimit!.secondaryWindow,
        isNotNull,
      );
      expect(
        summary
            .additionalRateLimits
            .first
            .rateLimit!
            .secondaryWindow!
            .usedPercent,
        85,
      );
      expect(
        summary.sparkRateLimit,
        summary.additionalRateLimits.first.rateLimit,
      );
      expect(summary.additionalRateLimits.last.displayName, 'GPT-5.4-Codex');
      expect(summary.additionalRateLimits.last.rateLimit!.allowed, isFalse);
    });

    test('parses Codex payload from happy usage command output', () {
      final summary = CodexUsageSummary.fromJson({
        'exitCode': 0,
        'status': 'completed',
        'stdout': '''
Machine Usage
Machine ID: machine-1

Codex
  {
    "data": {
      "additional_rate_limits": [
        {
          "limit_name": "GPT-5.3-Codex-Spark",
          "rate_limit": {
            "allowed": true,
            "limit_reached": false,
            "primary_window": {
              "limit_window_seconds": 18000,
              "reset_after_seconds": 10792,
              "reset_at": 1777977286,
              "used_percent": 15
            }
          }
        }
      ],
      "email": "dev@example.com",
      "plan_type": "prolite",
      "rate_limit": {
        "allowed": true,
        "limit_reached": false
      }
    },
    "provider": "codex",
    "success": true
  }

Claude
  {"provider": "claude", "success": false}
''',
      });

      expect(summary.hasUsageData, isTrue);
      expect(summary.email, 'dev@example.com');
      expect(summary.planType, 'prolite');
      expect(summary.rateLimit, isNotNull);
      expect(summary.additionalRateLimits, hasLength(1));
      expect(
        summary.additionalRateLimits.single.displayName,
        'GPT-5.3-Codex-Spark',
      );
      expect(
        summary
            .additionalRateLimits
            .single
            .rateLimit!
            .primaryWindow!
            .usedPercent,
        15,
      );
    });

    test('parses Spark limits from nested rate_limit key', () {
      final summary = CodexUsageSummary.fromJson({
        'spark_rate_limit': {
          'rate_limit': {'allowed': false, 'limit_reached': true},
        },
      });

      expect(summary.sparkRateLimit, isNotNull);
      expect(summary.sparkRateLimit!.allowed, isFalse);
      expect(summary.sparkRateLimit!.limitReached, isTrue);
    });
  });
}
