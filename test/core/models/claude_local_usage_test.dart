import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/claude_local_usage.dart';

void main() {
  group('ClaudeLocalUsage', () {
    test('parses full payload from daemon JSON', () {
      final usage = ClaudeLocalUsage.fromJson({
        'version': 4,
        'lastComputedDate': '2026-06-09',
        'totalTokens': 7000000,
        'totalMessages': 1234,
        'totalSessions': 5,
        'totalToolCalls': 567,
        'tokensByModel': {
          'claude-opus-4-7': 5000000,
          'kimi-for-coding': 2000000,
        },
        'longestSession': {'date': '2026-05-27', 'messageCount': 14648},
        'dailyModelTokens': [
          {
            'date': '2026-06-08',
            'tokensByModel': {'claude-opus-4-7': 1000, 'kimi-for-coding': 500}
          },
          {
            'date': '2026-06-09',
            'tokensByModel': {'claude-opus-4-7': 2000}
          },
        ],
      });

      expect(usage.version, 4);
      expect(usage.lastComputedDate, '2026-06-09');
      expect(usage.totalTokens, 7000000);
      expect(usage.totalMessages, 1234);
      expect(usage.totalSessions, 5);
      expect(usage.totalToolCalls, 567);
      expect(usage.tokensByModel, {
        'claude-opus-4-7': 5000000,
        'kimi-for-coding': 2000000,
      });
      expect(usage.longestSession, isNotNull);
      expect(usage.longestSession!.date, '2026-05-27');
      expect(usage.longestSession!.messageCount, 14648);
      expect(usage.dailyModelTokens, hasLength(2));
      expect(usage.dailyModelTokens.first.date, '2026-06-08');
    });

    test('handles empty payload with all defaults', () {
      final usage = ClaudeLocalUsage.fromJson({});

      expect(usage.version, 0);
      expect(usage.lastComputedDate, isNull);
      expect(usage.totalTokens, 0);
      expect(usage.totalMessages, 0);
      expect(usage.totalSessions, 0);
      expect(usage.totalToolCalls, 0);
      expect(usage.tokensByModel, isEmpty);
      expect(usage.longestSession, isNull);
      expect(usage.dailyModelTokens, isEmpty);
    });

    test('handles null longestSession explicitly', () {
      final usage = ClaudeLocalUsage.fromJson({
        'longestSession': null,
      });
      expect(usage.longestSession, isNull);
    });

    test('sortedTokensByModel returns entries sorted by value desc', () {
      final usage = ClaudeLocalUsage.fromJson({
        'tokensByModel': {
          'a': 100,
          'b': 500,
          'c': 300,
        },
      });

      final sorted = usage.sortedTokensByModel;
      expect(sorted.map((e) => e.key).toList(), ['b', 'c', 'a']);
      expect(sorted.map((e) => e.value).toList(), [500, 300, 100]);
    });

    test('sortedTokensByModel returns empty list when no models', () {
      final usage = ClaudeLocalUsage.fromJson({});
      expect(usage.sortedTokensByModel, isEmpty);
    });

    test('roundtrips through toJson and fromJson', () {
      final original = ClaudeLocalUsage(
        version: 4,
        lastComputedDate: '2026-06-09',
        totalTokens: 100,
        totalMessages: 5,
        totalSessions: 2,
        totalToolCalls: 10,
        tokensByModel: {'claude-opus-4-7': 100},
        longestSession: const ClaudeLongestSession(
          date: '2026-06-09',
          messageCount: 5,
        ),
        dailyModelTokens: const [
          ClaudeDailyModelTokens(
            date: '2026-06-09',
            tokensByModel: {'claude-opus-4-7': 100},
          ),
        ],
      );

      final json = original.toJson();
      final restored = ClaudeLocalUsage.fromJson(json);

      expect(restored.version, original.version);
      expect(restored.lastComputedDate, original.lastComputedDate);
      expect(restored.totalTokens, original.totalTokens);
      expect(restored.tokensByModel, original.tokensByModel);
      expect(restored.longestSession?.date, '2026-06-09');
      expect(restored.dailyModelTokens.first.date, '2026-06-09');
    });
  });

  group('ClaudeLocalUsage.formatModelName', () {
    test('strips claude- prefix and title-cases segments', () {
      expect(
        ClaudeLocalUsage.formatModelName('claude-opus-4-7'),
        'Opus 4 7',
      );
    });

    test('handles non-claude model ids', () {
      expect(
        ClaudeLocalUsage.formatModelName('kimi-for-coding'),
        'Kimi For Coding',
      );
    });

    test('handles dated model ids', () {
      expect(
        ClaudeLocalUsage.formatModelName('claude-haiku-4-5-20251001'),
        'Haiku 4 5 20251001',
      );
    });
  });

  group('ClaudeLocalUsage.formatTokenCount', () {
    test('returns raw integer under 1000', () {
      expect(ClaudeLocalUsage.formatTokenCount(0), '0');
      expect(ClaudeLocalUsage.formatTokenCount(1), '1');
      expect(ClaudeLocalUsage.formatTokenCount(999), '999');
    });

    test('formats thousands with K suffix', () {
      expect(ClaudeLocalUsage.formatTokenCount(1000), '1K');
      expect(ClaudeLocalUsage.formatTokenCount(1500), '1.5K');
      expect(ClaudeLocalUsage.formatTokenCount(123456), '123.5K');
    });

    test('formats millions with M suffix', () {
      expect(ClaudeLocalUsage.formatTokenCount(1000000), '1M');
      expect(ClaudeLocalUsage.formatTokenCount(2500000), '2.5M');
      expect(ClaudeLocalUsage.formatTokenCount(12345678), '12.3M');
    });

    test('formats billions with B suffix', () {
      expect(ClaudeLocalUsage.formatTokenCount(1000000000), '1B');
      expect(ClaudeLocalUsage.formatTokenCount(7500000000), '7.5B');
    });

    test('rounds to integer when decimal is .0', () {
      expect(ClaudeLocalUsage.formatTokenCount(2000), '2K');
      expect(ClaudeLocalUsage.formatTokenCount(3000000), '3M');
    });
  });
}
