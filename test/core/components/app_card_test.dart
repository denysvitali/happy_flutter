import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_card.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({
    required Widget child,
    ThemeData? theme,
    MediaQueryData? mediaQueryData,
  }) {
    final content = mediaQueryData == null
        ? child
        : MediaQuery(data: mediaQueryData, child: child);
    return MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: content),
    );
  }

  group('AppCard', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const AppCard(child: Text('Hello'))),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('applies default padding when none provided', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const AppCard(child: Text('Content'))),
      );

      final paddings = tester.widgetList<Padding>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Padding),
        ),
      );

      final hasPadding = paddings.any(
        (p) => p.padding == const EdgeInsets.all(16),
      );
      expect(hasPadding, isTrue);
    });

    testWidgets('applies custom padding', (tester) async {
      const customPadding = EdgeInsets.all(8);
      await tester.pumpWidget(
        buildApp(
          child: const AppCard(padding: customPadding, child: Text('Content')),
        ),
      );

      final paddings = tester.widgetList<Padding>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Padding),
        ),
      );

      final hasPadding = paddings.any((p) => p.padding == customPadding);
      expect(hasPadding, isTrue);
    });

    testWidgets('applies margin', (tester) async {
      const margin = EdgeInsets.all(12);
      await tester.pumpWidget(
        buildApp(
          child: const AppCard(margin: margin, child: Text('Content')),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(container.margin, equals(margin));
    });

    testWidgets('shows InkWell when onTap is provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildApp(
          child: AppCard(
            onTap: () => tapped = true,
            child: const Text('Tappable'),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
      expect(find.byType(AnimatedScale), findsOneWidget);

      await tester.tap(find.text('Tappable'));
      expect(tapped, isTrue);
    });

    testWidgets('does not show InkWell when onTap is null', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const AppCard(child: Text('Static'))),
      );

      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(AnimatedScale), findsNothing);
    });

    testWidgets('does not show AnimatedScale when onTap is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(child: const AppCard(child: Text('Static'))),
      );

      expect(find.byType(AnimatedScale), findsNothing);
    });

    testWidgets('tapping triggers onTap callback', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        buildApp(
          child: AppCard(onTap: () => tapCount++, child: const Text('Tap me')),
        ),
      );

      await tester.tap(find.text('Tap me'));
      expect(tapCount, 1);

      await tester.tap(find.text('Tap me'));
      expect(tapCount, 2);
    });

    testWidgets('animates scale on press', (tester) async {
      await tester.pumpWidget(
        buildApp(
          child: AppCard(onTap: () {}, child: const Text('Animated')),
        ),
      );

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1.0);

      // Simulate tap down
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Animated')),
      );
      await tester.pump();

      final pressedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(pressedScale.scale, 0.98);

      await gesture.up();
      await tester.pump();

      final releasedScale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(releasedScale.scale, 1.0);
    });

    testWidgets('does not scale when motion is reduced', (tester) async {
      await tester.pumpWidget(
        buildApp(
          mediaQueryData: const MediaQueryData(disableAnimations: true),
          child: AppCard(onTap: () {}, child: const Text('Static press')),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Static press')),
      );
      await tester.pump();

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 1.0);
      expect(scale.duration, Duration.zero);

      await gesture.up();
    });

    testWidgets('uses flat tonal hierarchy in dark mode', (tester) async {
      final theme = ThemeData(brightness: Brightness.dark, useMaterial3: true);
      await tester.pumpWidget(
        buildApp(
          theme: theme,
          child: const AppCard(child: Text('Dark card')),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final outerDecoration = container.decoration! as BoxDecoration;
      final innerDecoration = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(AppCard),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((decoration) => decoration.color != null);

      expect(outerDecoration.boxShadow, isEmpty);
      expect(innerDecoration.color, theme.colorScheme.surfaceContainerLow);
      expect(innerDecoration.border, isNotNull);
    });

    testWidgets('preserves card shadow in light mode', (tester) async {
      await tester.pumpWidget(
        buildApp(
          theme: ThemeData(useMaterial3: true),
          child: const AppCard(child: Text('Light card')),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('ClipRRect wraps content with correct radius', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const AppCard(child: Text('Clipped'))),
      );

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, equals(BorderRadius.circular(16)));
    });

    testWidgets('has DecoratedBox with border', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const AppCard(child: Text('Bordered'))),
      );

      final decoratedWidgets = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(DecoratedBox),
        ),
      );

      final hasBorder = decoratedWidgets.any((d) {
        final decoration = d.decoration;
        if (decoration is BoxDecoration) {
          return decoration.border != null &&
              decoration.borderRadius == BorderRadius.circular(16);
        }
        return false;
      });
      expect(hasBorder, isTrue);
    });

    testWidgets('has Semantics for accessibility', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const AppCard(child: Text('Accessible'))),
      );

      expect(find.byType(AppCard), findsOneWidget);
      expect(find.text('Accessible'), findsOneWidget);
    });
  });
}
