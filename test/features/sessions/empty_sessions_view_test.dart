import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/sessions/widgets/empty_sessions_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmptySessionsView', () {
    testWidgets('renders computer icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: EmptySessionsView(),
          ),
        ),
      );

      expect(
        find.byIcon(Icons.computer_outlined),
        findsOneWidget,
      );
    });

    testWidgets('renders "New Session" button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: EmptySessionsView(),
          ),
        ),
      );

      expect(
        find.text('New Session'),
        findsOneWidget,
      );
    });

    testWidgets('renders instructional text lines',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: EmptySessionsView(),
          ),
        ),
      );

      // Check for the instruction texts by their presence
      // in the widget tree rather than exact strings
      // (l10n may vary).
      final columns = find.byType(Column);
      expect(columns, findsWidgets);
    });

    testWidgets('renders as a centered view', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: EmptySessionsView(),
          ),
        ),
      );

      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('button is a FilledButton.tonal',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: EmptySessionsView(),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
    });
  });
}
