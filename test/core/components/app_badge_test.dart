import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_badge.dart';
import 'package:happy_flutter/core/theme/app_color_scheme.dart';

void main() {
  Widget buildApp({
    required Widget child,
    Brightness brightness = Brightness.light,
    MediaQueryData? mediaQueryData,
  }) {
    final appColors = brightness == Brightness.dark
        ? AppColorScheme.dark()
        : AppColorScheme.light();
    final content = mediaQueryData == null
        ? child
        : MediaQuery(data: mediaQueryData, child: child);

    return MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
        extensions: [appColors],
      ),
      home: Scaffold(body: Center(child: content)),
    );
  }

  BoxDecoration badgeDecoration(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppBadge),
        matching: find.byType(Container),
      ),
    );
    return container.decoration! as BoxDecoration;
  }

  group('AppBadge', () {
    testWidgets('neutral tone preserves the original defaults', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const AppBadge(label: 'Neutral')),
      );

      final context = tester.element(find.byType(AppBadge));
      final colors = Theme.of(context).colorScheme;
      final label = tester.widget<Text>(find.text('Neutral'));

      expect(find.byType(Icon), findsNothing);
      expect(badgeDecoration(tester).color, colors.surfaceContainerHighest);
      expect(label.style?.color, colors.onSurfaceVariant);
    });

    testWidgets('semantic tones include distinct default icons', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBadge(label: 'Info', tone: AppBadgeTone.info),
              AppBadge(label: 'Success', tone: AppBadgeTone.success),
              AppBadge(label: 'Warning', tone: AppBadgeTone.warning),
              AppBadge(label: 'Danger', tone: AppBadgeTone.danger),
            ],
          ),
        ),
      );

      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('explicit colors and leading widget override tone defaults', (
      tester,
    ) async {
      const background = Color(0xFF102030);
      const foreground = Color(0xFFF0E0D0);

      await tester.pumpWidget(
        buildApp(
          child: const AppBadge(
            label: 'Custom',
            tone: AppBadgeTone.danger,
            leading: Icon(Icons.flag_outlined),
            backgroundColor: background,
            foregroundColor: foreground,
          ),
        ),
      );

      final iconContext = tester.element(find.byIcon(Icons.flag_outlined));
      final label = tester.widget<Text>(find.text('Custom'));

      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
      expect(badgeDecoration(tester).color, background);
      expect(IconTheme.of(iconContext).color, foreground);
      expect(label.style?.color, foreground);
    });

    testWidgets('semantic tone uses dark theme container and readable text', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          brightness: Brightness.dark,
          child: const AppBadge(label: 'Danger', tone: AppBadgeTone.danger),
        ),
      );

      final appColors = AppColorScheme.dark();
      final label = tester.widget<Text>(find.text('Danger'));

      expect(badgeDecoration(tester).color, appColors.dangerContainer);
      expect(label.style?.color, appColors.textPrimary);
    });

    testWidgets('disables label transition when motion is reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          mediaQueryData: const MediaQueryData(disableAnimations: true),
          child: const AppBadge(label: 'Static'),
        ),
      );

      final switcher = tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher),
      );
      expect(switcher.duration, Duration.zero);
    });
  });
}
