import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_tappable.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({required Widget child}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('AppTappable', () {
    testWidgets('exposes button semantics when tappable', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: AppTappable(
            semanticLabel: 'Open item',
            onTap: () {},
            child: const Text('Item'),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(AppTappable)),
        matchesSemantics(
          label: 'Open item\nItem',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('does not expose button semantics when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const AppTappable(
            semanticLabel: 'Disabled item',
            child: Text('Item'),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(AppTappable)),
        matchesSemantics(
          label: 'Disabled item\nItem',
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
    });
  });
}
