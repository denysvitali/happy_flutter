import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/sidebar/app_sidebar.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/ui/tab_bar/tab_bar.dart';

Widget _app({
  AppTab activeTab = AppTab.sessions,
  bool collapsed = false,
  bool showCollapseToggle = true,
  Map<AppTab, int> badgeCounts = const <AppTab, int>{},
  void Function(AppTab)? onTabPress,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: AppSidebar(
        activeTab: activeTab,
        onTabPress: onTabPress ?? (_) {},
        isCollapsed: collapsed,
        onToggleCollapsed: () {},
        showCollapseToggle: showCollapseToggle,
        badgeCounts: badgeCounts,
      ),
    ),
  );
}

void main() {
  testWidgets('uses the canonical destination order and supports selection', (
    tester,
  ) async {
    AppTab? selected;
    await tester.pumpWidget(_app(onTabPress: (tab) => selected = tab));

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Loops'), findsOneWidget);
    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Providers'));
    expect(selected, AppTab.providers);
  });

  testWidgets('compact rail keeps 48px targets and badge semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        collapsed: true,
        showCollapseToggle: false,
        badgeCounts: const <AppTab, int>{AppTab.loops: 3},
      ),
    );

    final loops = find.bySemanticsLabel('Loops, 3 new items');
    expect(loops, findsOneWidget);
    expect(tester.getSize(loops).height, greaterThanOrEqualTo(44));
    expect(find.byTooltip('Collapse sidebar (Ctrl+B)'), findsNothing);
  });
}
