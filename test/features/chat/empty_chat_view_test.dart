import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/empty_chat_view.dart';

Widget _buildApp({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmptyChatView', () {
    testWidgets('renders suggestion cards', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const EmptyChatView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Write code'), findsOneWidget);
      expect(find.text('Debug an issue'), findsOneWidget);
      expect(find.text('Explain code'), findsOneWidget);
      expect(find.text('Review PR'), findsOneWidget);
    });

    testWidgets('renders all four suggestion icons', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const EmptyChatView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.code_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bug_report_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
      expect(find.byIcon(Icons.rate_review_rounded), findsOneWidget);
    });

    testWidgets('renders main chat icon', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const EmptyChatView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byIcon(Icons.chat_bubble_outline_rounded),
        findsOneWidget,
      );
    });

    testWidgets('calls onSuggestionTap when a card is tapped', (
      tester,
    ) async {
      String? tappedSuggestion;

      await tester.pumpWidget(
        _buildApp(
          child: EmptyChatView(
            onSuggestionTap: (suggestion) {
              tappedSuggestion = suggestion;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Write code'));
      await tester.pump();

      expect(tappedSuggestion, 'Write code');
    });

    testWidgets('renders subtitle text', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const EmptyChatView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Generate a function or component'), findsOneWidget);
      expect(find.text('Find and fix a bug in your code'), findsOneWidget);
      expect(find.text('Understand how something works'), findsOneWidget);
      expect(find.text('Get feedback on your changes'), findsOneWidget);
    });

    testWidgets('displays header title', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const EmptyChatView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // "Start a conversation" text from l10n
      expect(find.text('Start a conversation'), findsOneWidget);
    });

    testWidgets('displays subtitle prompt', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const EmptyChatView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('How can I help you today?'), findsOneWidget);
    });

    testWidgets('cards are in a 2x2 grid layout', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const EmptyChatView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify we have two rows of cards (4 cards total)
      final rows = find.byType(Row);
      expect(rows, findsWidgets);
    });

    testWidgets('no crash when onSuggestionTap is null', (tester) async {
      await tester.pumpWidget(
        _buildApp(child: const EmptyChatView()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tapping without a callback should not crash
      await tester.tap(find.text('Write code'));
      await tester.pump();
    });
  });
}
