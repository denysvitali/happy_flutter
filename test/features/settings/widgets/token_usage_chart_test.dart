import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/claude_local_usage.dart';
import 'package:happy_flutter/features/settings/widgets/token_usage_chart.dart';

void main() {
  group('TokenUsageChart', () {
    testWidgets('renders chart and metrics for usage data', (tester) async {
      final usage = ClaudeLocalUsage(
        totalTokens: 3500,
        totalMessages: 12,
        totalSessions: 3,
        totalToolCalls: 7,
        dailyModelTokens: [
          const ClaudeDailyModelTokens(
            date: '2026-06-14',
            tokensByModel: {'claude-opus-4-7': 500},
          ),
          const ClaudeDailyModelTokens(
            date: '2026-06-15',
            tokensByModel: {'claude-opus-4-7': 1000},
          ),
          const ClaudeDailyModelTokens(
            date: '2026-06-16',
            tokensByModel: {'claude-opus-4-7': 2000},
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  TokenUsageChart(
                    dailyModelTokens: usage.dailyModelTokens,
                  ),
                  TokenUsageMetrics(usage: usage),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TokenUsageChart), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TokenUsageChart),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('renders empty placeholder when no daily data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: TokenUsageChart(dailyModelTokens: []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TokenUsageChart), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TokenUsageChart),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });
}
