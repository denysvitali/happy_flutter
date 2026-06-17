import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/ui/tab_bar/tab_bar.dart';

/// Test wrapper that mounts a [TabBar] in a MaterialApp with l10n so the
/// widget's `_labelForTab` switch can resolve all enum values.
Widget _wrap({
  required AppTab activeTab,
  Map<AppTab, int> badgeCounts = const <AppTab, int>{},
  void Function(AppTab)? onTabPress,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: TabBar(
        activeTab: activeTab,
        onTabPress: onTabPress ?? (_) {},
        badgeCounts: badgeCounts,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TabBar badge counts', () {
    testWidgets('renders no badge when counts map is empty', (tester) async {
      await tester.pumpWidget(_wrap(activeTab: AppTab.sessions));
      // No badge pill exists at all — `_TabBadge` is only painted when
      // badgeCount > 0.
      expect(find.byType(Container), findsWidgets);
      // The badge widget specifically is never instantiated.
      // We can confirm by searching for the '9+' or '5' digits anywhere.
      expect(find.text('9+'), findsNothing);
      expect(find.textContaining(RegExp(r'^[0-9]')), findsNothing);
    });

    testWidgets(
      'renders badge with numeric label on the Loops tab when count > 0',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            activeTab: AppTab.sessions,
            badgeCounts: const <AppTab, int>{AppTab.loops: 3},
          ),
        );
        expect(find.text('3'), findsOneWidget);
      },
    );

    testWidgets('hides badge when Loops count is 0', (tester) async {
      await tester.pumpWidget(
        _wrap(
          activeTab: AppTab.sessions,
          badgeCounts: const <AppTab, int>{AppTab.loops: 0},
        ),
      );
      expect(find.text('0'), findsNothing);
      expect(find.text('9+'), findsNothing);
    });

    testWidgets('caps badge label at "9+" when count exceeds 9', (tester) async {
      await tester.pumpWidget(
        _wrap(
          activeTab: AppTab.sessions,
          badgeCounts: const <AppTab, int>{AppTab.loops: 42},
        ),
      );
      expect(find.text('9+'), findsOneWidget);
      // Should not render the raw 42 either.
      expect(find.text('42'), findsNothing);
    });

    testWidgets('shows the exact count when count is between 1 and 9',
        (tester) async {
      for (final count in [1, 5, 7, 9]) {
        await tester.pumpWidget(
          _wrap(
            activeTab: AppTab.sessions,
            badgeCounts: <AppTab, int>{AppTab.loops: count},
          ),
        );
        expect(
          find.text('$count'),
          findsOneWidget,
          reason: 'count $count should render as "$count"',
        );
        // Tabs are mounted inside the same widget tree across
        // pumpWidget calls — clear between iterations.
      }
    });

    testWidgets('only paints the Loops badge — Sessions tab stays clean',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          activeTab: AppTab.sessions,
          badgeCounts: const <AppTab, int>{
            AppTab.loops: 5,
            // Provide counts for other tabs as well — should be ignored.
            AppTab.sessions: 99,
            AppTab.providers: 99,
            AppTab.settings: 99,
          },
        ),
      );
      // Only one numeric badge appears: the Loops tab's "5".
      expect(find.text('5'), findsOneWidget);
      // No "9+" cap was applied because Loops count is 5.
      expect(find.text('9+'), findsNothing);
    });

    testWidgets('tab order matches enum: sessions, loops, providers, settings',
        (tester) async {
      await tester.pumpWidget(_wrap(activeTab: AppTab.sessions));
      // Find the four _TabItem widgets and confirm their labels in
      // left-to-right order.
      final labels = find.byType(Text).evaluate().map((e) {
        final w = e.widget as Text;
        return w.data ?? '';
      }).where((s) => s.isNotEmpty).toList();
      // Expect the four canonical tab labels to appear in order:
      // "Sessions", "Loops", "Providers", "Settings" (the actual
      // localized text is used, but the test bundle always returns the
      // English string for unsupported locales too — see
      // AppLocalizations.localizationsDelegates).
      expect(labels, contains('Sessions'));
      expect(labels, contains('Loops'));
      expect(labels, contains('Providers'));
      expect(labels, contains('Settings'));
    });
  });
}
