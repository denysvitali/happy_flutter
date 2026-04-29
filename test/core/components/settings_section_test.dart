import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/settings_section.dart';
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

  group('settings rows', () {
    testWidgets('SettingsRow exposes button semantics when tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: SettingsRow(
            icon: Icons.settings,
            title: 'General',
            onTap: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(SettingsRow)),
        matchesSemantics(
          label: 'General',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    });

    testWidgets('SettingsToggleRow exposes one toggled control', (
      tester,
    ) async {
      var value = true;
      await tester.pumpWidget(
        buildApp(
          child: StatefulBuilder(
            builder: (context, setState) {
              return SettingsToggleRow(
                icon: Icons.notifications,
                title: 'Alerts',
                value: value,
                onChanged: (next) => setState(() => value = next),
              );
            },
          ),
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.toggled == true,
        ),
      );
      expect(semantics.properties.button, isTrue);
      expect(semantics.properties.toggled, isTrue);
      expect(semantics.properties.enabled, isTrue);
      expect(semantics.properties.onTap, isNotNull);

      await tester.tap(find.byType(SettingsToggleRow));
      await tester.pump();

      expect(value, isFalse);
    });
  });
}
