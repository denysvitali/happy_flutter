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

    testWidgets('categorical color tints at one fixed strength', (
      tester,
    ) async {
      const hue = Color(0xFF7C3AED);

      await tester.pumpWidget(
        buildApp(
          child: const AppBadge(
            label: 'Custom',
            leading: Icon(Icons.flag_outlined),
            color: hue,
          ),
        ),
      );

      final iconContext = tester.element(find.byIcon(Icons.flag_outlined));
      final label = tester.widget<Text>(find.text('Custom'));

      expect(badgeDecoration(tester).color, hue.withValues(alpha: 0.15));
      expect(IconTheme.of(iconContext).color, hue);
      expect(label.style?.color, hue);
    });

    testWidgets('solid counters fill with the hue and contrasting text', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const AppBadge(
            label: '3',
            color: Color(0xFF2563EB),
            solid: true,
          ),
        ),
      );

      expect(badgeDecoration(tester).color, const Color(0xFF2563EB));
      expect(tester.widget<Text>(find.text('3')).style?.color, Colors.white);
    });

    testWidgets('every variant shares one height', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBadge(label: 'a'),
              AppBadge(label: 'b', tone: AppBadgeTone.warning),
              AppBadge(label: 'c', color: Colors.teal),
              AppBadge(label: 'd', outlined: true),
              AppBadge(label: 'e', monospace: true),
              AppBadge(label: '9', solid: true, color: Colors.red),
              AppBadge(label: 'f', leading: Icon(Icons.folder_outlined)),
            ],
          ),
        ),
      );

      final heights = find
          .byType(AppBadge)
          .evaluate()
          .map((e) => e.size!.height)
          .toSet();
      expect(heights, hasLength(1));
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
