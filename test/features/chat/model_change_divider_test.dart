import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/model_change_divider.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders both models with display names', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ModelChangeDivider(
          fromModel: 'claude-opus-4-5-20251101',
          toModel: 'claude-sonnet-5',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Opus 4.5', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Sonnet 5', findRichText: true),
      findsOneWidget,
    );
  });
}
