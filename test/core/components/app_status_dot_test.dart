import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_status_dot.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({required Widget child}) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('AppStatusDot', () {
    testWidgets('renders with required color', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(color: Colors.green),
      ));

      expect(find.byType(AppStatusDot), findsOneWidget);
    });

    testWidgets('renders Container with correct default size',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(color: Colors.red),
      ));

      // Without pulse, renders a Container directly.
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppStatusDot),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.constraints?.maxWidth, AppSpacing.xs);
      expect(container.constraints?.maxHeight, AppSpacing.xs);
    });

    testWidgets('renders with custom size', (tester) async {
      const customSize = 12.0;
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.blue,
          size: customSize,
        ),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppStatusDot),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.constraints?.maxWidth, customSize);
      expect(container.constraints?.maxHeight, customSize);
    });

    testWidgets('renders dot with BoxDecoration circle shape',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(color: Colors.green),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppStatusDot),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, Colors.green);
    });

    testWidgets('non-pulsing dot has box shadow', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(color: Colors.green),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppStatusDot),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('pulse=true shows AnimatedBuilder', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          pulse: true,
        ),
      ));

      expect(find.byType(AnimatedBuilder), findsOneWidget);
    });

    testWidgets('pulse=false does not show AnimatedBuilder',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          pulse: false,
        ),
      ));

      expect(find.byType(AnimatedBuilder), findsNothing);
    });

    testWidgets('pulse=true uses Stack layout', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          pulse: true,
        ),
      ));

      expect(find.byType(Stack), findsOneWidget);
    });

    testWidgets('applies margin when provided', (tester) async {
      const margin = EdgeInsets.all(8);
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          margin: margin,
        ),
      ));

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(AppStatusDot),
          matching: find.byType(Padding),
        ).first,
      );

      expect(padding.padding, equals(margin));
    });

    testWidgets('no Padding widget when margin is null', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(color: Colors.green),
      ));

      // AppStatusDot itself is the root; no extra Padding wrapper.
      final statusDotFinder = find.byType(AppStatusDot);
      final paddingFinder = find.descendant(
        of: statusDotFinder,
        matching: find.byType(Padding),
      );

      // No padding when margin is not provided.
      expect(paddingFinder, findsNothing);
    });

    testWidgets('wraps in Semantics when semanticLabel provided',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          semanticLabel: 'Online',
        ),
      ));

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(AppStatusDot),
          matching: find.byType(Semantics),
        ),
      );

      expect(semantics.properties.label, 'Online');
    });

    testWidgets('no Semantics when semanticLabel is null',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(color: Colors.green),
      ));

      expect(
        find.descendant(
          of: find.byType(AppStatusDot),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });

    testWidgets('updating pulse from false to true starts animation',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          pulse: false,
        ),
      ));

      expect(find.byType(AnimatedBuilder), findsNothing);

      // Update to pulsing.
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          pulse: true,
        ),
      ));

      expect(find.byType(AnimatedBuilder), findsOneWidget);
    });

    testWidgets('updating pulse from true to false stops animation',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          pulse: true,
        ),
      ));

      expect(find.byType(AnimatedBuilder), findsOneWidget);

      // Update to non-pulsing.
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          pulse: false,
        ),
      ));

      expect(find.byType(AnimatedBuilder), findsNothing);
    });

    testWidgets('pulseColor overrides pulse ring color', (tester) async {
      // This is a visual property; we verify the widget builds without
      // error when pulseColor is provided.
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          pulse: true,
          pulseColor: Colors.yellow,
        ),
      ));

      expect(find.byType(AppStatusDot), findsOneWidget);
      expect(find.byType(AnimatedBuilder), findsOneWidget);
    });

    testWidgets('disposes animation controller properly',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          pulse: true,
        ),
      ));

      // Replace with different widget to trigger dispose.
      await tester.pumpWidget(buildApp(
        child: const Text('Replaced'),
      ));

      expect(find.text('Replaced'), findsOneWidget);
    });

    testWidgets('pulse dot has two Container children in Stack',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppStatusDot(
          color: Colors.green,
          pulse: true,
        ),
      ));

      // The Stack should contain a pulsing ring and a static dot.
      final stack = tester.widget<Stack>(
        find.byType(Stack),
      );

      // Stack children include Transform.scale (ring) and the static
      // dot passed via the child parameter.
      expect(stack.children.length, 2);
    });
  });
}
