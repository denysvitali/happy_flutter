import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/claude_usage_limits.dart';

void main() {
  group('ClaudeUsageLimits', () {
    test('parses legacy top-level windows', () {
      final limits = ClaudeUsageLimits.fromJson(
        jsonDecode('''
        {
          "five_hour": {"utilization": 12, "resets_at": "2026-07-03T18:00:00Z"},
          "seven_day": {"utilization": 40},
          "seven_day_opus": {"utilization": 55}
        }
        ''')
            as Map<String, dynamic>,
      );

      expect(limits.fiveHour?.utilization, 12);
      expect(limits.sevenDayOpus?.utilization, 55);
      expect(limits.limits, isEmpty);
      final labels = limits.activeWindows.map((w) => w.$1).toList();
      expect(labels, ['5-Hour', '7-Day', '7-Day Opus']);
    });

    test('parses model-scoped limits array (Fable and future models)', () {
      final limits = ClaudeUsageLimits.fromJson(
        jsonDecode('''
        {
          "five_hour": {"utilization": 10},
          "limits": [
            {
              "group": "weekly",
              "kind": "quota",
              "is_active": true,
              "percent": 32.5,
              "resets_at": "2026-07-08T00:00:00Z",
              "severity": "none",
              "scope": {"model": {"display_name": "Fable"}}
            },
            {
              "group": "session",
              "percent": 7,
              "scope": {"model": {"display_name": "Some Future Model"}}
            },
            {
              "group": "weekly",
              "percent": 99,
              "scope": null
            }
          ]
        }
        ''')
            as Map<String, dynamic>,
      );

      expect(limits.limits, hasLength(3));
      final windows = limits.activeWindows;
      final labels = windows.map((w) => w.$1).toList();
      // Non-model-scoped limits entries are skipped (they duplicate the
      // legacy top-level windows).
      expect(labels, ['5-Hour', '7-Day Fable', '5-Hour Some Future Model']);

      final fable = windows.firstWhere((w) => w.$1 == '7-Day Fable').$2;
      expect(fable.utilization, 32.5);
      expect(fable.resetsAt, '2026-07-08T00:00:00Z');
    });

    test('unknown group falls back to capitalized group name', () {
      final limits = ClaudeUsageLimits.fromJson({
        'limits': [
          {
            'group': 'monthly',
            'percent': 5,
            'scope': {
              'model': {'display_name': 'Fable'},
            },
          },
        ],
      });

      expect(limits.activeWindows.single.$1, 'Monthly Fable');
    });

    test('dedupes a limits entry whose label matches a legacy window', () {
      final limits = ClaudeUsageLimits.fromJson({
        'seven_day_opus': {'utilization': 55},
        'limits': [
          {
            'group': 'weekly',
            'percent': 55,
            'scope': {
              'model': {'display_name': 'Opus'},
            },
          },
        ],
      });

      final labels = limits.activeWindows.map((w) => w.$1).toList();
      expect(labels, ['7-Day Opus']);
    });

    test('tolerates malformed limits payloads', () {
      expect(
        ClaudeUsageLimits.fromJson({'limits': 'garbage'}).limits,
        isEmpty,
      );
      expect(
        ClaudeUsageLimits.fromJson({
          'limits': [
            'not-a-map',
            {'group': 'weekly', 'percent': 'NaN', 'scope': 42},
          ],
        }).limits.single.percent,
        0.0,
      );
    });
  });
}
