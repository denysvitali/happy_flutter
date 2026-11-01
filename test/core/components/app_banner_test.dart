import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_badge.dart';
import 'package:happy_flutter/core/components/app_banner.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/chat/widgets/session_info_widgets.dart';

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
  theme: dark ? ThemeHelper.buildDarkTheme() : ThemeHelper.buildLightTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('session header pills share one height', (tester) async {
    await tester.pumpWidget(
      _app(
        const Wrap(
          children: [
            StatusChip(isActive: false),
            StatusChip(isActive: true),
            SessionSandboxBadge(
              metadata: Metadata(
                host: 'h',
                sandboxRequested: false,
                sandboxEnforced: false,
              ),
            ),
            SessionSandboxBadge(
              metadata: Metadata(
                host: 'h',
                sandboxRequested: true,
                sandboxEnforced: false,
              ),
            ),
          ],
        ),
      ),
    );

    final heights = find
        .byType(AppBadge)
        .evaluate()
        .map((e) => e.size!.height)
        .toSet();
    expect(find.byType(AppBadge), findsNWidgets(4));
    expect(heights, hasLength(1));
  });

  for (final dark in [false, true]) {
    testWidgets('warning banner and warning pill share a palette '
        '(dark=$dark)', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBadge(label: 'Paused', tone: AppBadgeTone.warning),
              AppBanner(
                tone: AppBadgeTone.warning,
                title: 'CLI Version Outdated',
                message: 'Run: npm install -g happy-coder@latest',
              ),
            ],
          ),
          dark: dark,
        ),
      );

      final context = tester.element(find.byType(AppBanner));
      final colors = AppToneColors.of(context, AppBadgeTone.warning);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppBanner),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, colors.background);
      final badgeBox = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppBadge),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((badgeBox.decoration! as BoxDecoration).color, colors.background);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded).last).icon,
        Icons.warning_amber_rounded,
      );
      final title = tester.widget<Text>(find.text('CLI Version Outdated'));
      expect(title.style!.color, colors.foreground);
    });
  }

  testWidgets('tappable banner forwards taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        AppBanner(
          tone: AppBadgeTone.danger,
          title: 'Failed',
          onTap: () => taps++,
        ),
      ),
    );
    await tester.tap(find.text('Failed'));
    expect(taps, 1);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });
}
