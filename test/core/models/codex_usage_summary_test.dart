import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/codex_usage_summary.dart';

void main() {
  group('CodexUsageSummary', () {
    test('parses totals and by-model rows', () {
      final summary = CodexUsageSummary.fromJson({
        'totalTokens': 12345,
        'threadCount': 7,
        'firstSeenAt': 100,
        'lastSeenAt': 200,
        'databasePath': '/tmp/state.sqlite',
        'byModel': [
          {'model': 'gpt-5.4', 'totalTokens': 12000, 'threadCount': 6},
          {'model': 'unknown', 'totalTokens': 345, 'threadCount': 1},
        ],
      });

      expect(summary.totalTokens, 12345);
      expect(summary.threadCount, 7);
      expect(summary.firstSeenAt, 100);
      expect(summary.lastSeenAt, 200);
      expect(summary.databasePath, '/tmp/state.sqlite');
      expect(summary.byModel, hasLength(2));
      expect(summary.byModel.first.model, 'gpt-5.4');
      expect(summary.byModel.first.totalTokens, 12000);
      expect(summary.byModel.first.threadCount, 6);
    });

    test('falls back for invalid values', () {
      final summary = CodexUsageSummary.fromJson({
        'totalTokens': 'bad',
        'threadCount': null,
        'firstSeenAt': 0.0,
        'lastSeenAt': 10.8,
        'databasePath': '',
        'byModel': [
          {'model': '', 'totalTokens': 1.9, 'threadCount': 'bad'},
        ],
      });

      expect(summary.totalTokens, 0);
      expect(summary.threadCount, 0);
      expect(summary.firstSeenAt, 0);
      expect(summary.lastSeenAt, 10);
      expect(summary.databasePath, '');
      expect(summary.byModel.single.model, 'unknown');
      expect(summary.byModel.single.totalTokens, 1);
      expect(summary.byModel.single.threadCount, 0);
    });
  });
}
