import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/components.dart'
    show NoSessionSelectedView;
import 'package:happy_flutter/core/i18n/app_localizations.dart';

Widget _harness({VoidCallback? onCreate}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: NoSessionSelectedView(onCreateSession: onCreate)),
);

void main() {
  testWidgets('names the empty state and offers the create action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_harness(onCreate: () => taps++));
    await tester.pump();

    expect(find.text('No session selected'), findsOneWidget);
    expect(
      find.textContaining('Choose a session from the list'),
      findsOneWidget,
    );

    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);
  });

  testWidgets('hides the action when no callback is provided', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.text('No session selected'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
