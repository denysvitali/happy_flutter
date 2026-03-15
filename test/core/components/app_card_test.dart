import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({required Widget child}) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('AppCard', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppCard(child: Text('Hello')),
      ));

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('applies default padding when none provided',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppCard(child: Text('Content')),
      ));

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
      await tester.pumpWidget(buildApp(
        child: const AppCard(
          padding: customPadding,
          child: Text('Content'),
        ),
      ));

      final paddings = tester.widgetList<Padding>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Padding),
        ),
      );

      final hasPadding = paddings.any(
        (p) => p.padding == customPadding,
      );
      expect(hasPadding, isTrue);
    });

    testWidgets('applies margin', (tester) async {
      const margin = EdgeInsets.all(12);
      await tester.pumpWidget(buildApp(
        child: const AppCard(
          margin: margin,
          child: Text('Content'),
        ),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.margin, equals(margin));
    });

    testWidgets('shows InkWell when onTap is provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildApp(
        child: AppCard(
          onTap: () => tapped = true,
          child: const Text('Tappable'),
        ),
      ));

      expect(find.byType(InkWell), findsOneWidget);
      expect(find.byType(AnimatedScale), findsOneWidget);

      await tester.tap(find.text('Tappable'));
      expect(tapped, isTrue);
    });

    testWidgets('does not show InkWell when onTap is null',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppCard(child: Text('Static')),
      ));

      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(AnimatedScale), findsNothing);
    });

    testWidgets('does not show AnimatedScale when onTap is null',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppCard(child: Text('Static')),
      ));

      expect(find.byType(AnimatedScale), findsNothing);
    });

    testWidgets('tapping triggers onTap callback', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(buildApp(
        child: AppCard(
          onTap: () => tapCount++,
          child: const Text('Tap me'),
        ),
      ));

      await tester.tap(find.text('Tap me'));
      expect(tapCount, 1);

      await tester.tap(find.text('Tap me'));
      expect(tapCount, 2);
    });

    testWidgets('animates scale on press', (tester) async {
      await tester.pumpWidget(buildApp(
        child: AppCard(
          onTap: () {},
          child: const Text('Animated'),
        ),
      ));

      final scale = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
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

    testWidgets('ClipRRect wraps content with correct radius',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppCard(child: Text('Clipped')),
      ));

      final clipRRect = tester.widget<ClipRRect>(
        find.byType(ClipRRect),
      );
      expect(clipRRect.borderRadius, equals(BorderRadius.circular(16)));
    });

    testWidgets('has DecoratedBox with border', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppCard(child: Text('Bordered')),
      ));

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
      await tester.pumpWidget(buildApp(
        child: const AppCard(child: Text('Accessible')),
      ));

      expect(find.byType(AppCard), findsOneWidget);
      expect(find.text('Accessible'), findsOneWidget);
    });
  });
}
