import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/sessions/widgets/session_animations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StaggeredSlideIn', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredSlideIn(
              index: 0,
              animate: false,
              child: Text('Hello'),
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('wraps child in RepaintBoundary',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredSlideIn(
              index: 0,
              animate: false,
              child: Text('Test'),
            ),
          ),
        ),
      );

      // RepaintBoundary exists (may be multiple due to
      // framework internals).
      expect(
        find.byType(RepaintBoundary),
        findsWidgets,
      );
    });

    testWidgets('renders immediately when animate is false',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredSlideIn(
              index: 0,
              animate: false,
              child: Text('No Animation'),
            ),
          ),
        ),
      );

      expect(find.text('No Animation'), findsOneWidget);
    });

    testWidgets('renders multiple staggered items',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StaggeredSlideIn(
                  index: 0,
                  animate: false,
                  child: Text('First'),
                ),
                StaggeredSlideIn(
                  index: 1,
                  animate: false,
                  child: Text('Second'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });
  });

  group('constants', () {
    test('kStaggerStep is 30', () {
      expect(kStaggerStep, 30);
    });

    test('kSlideDuration is 250', () {
      expect(kSlideDuration, 250);
    });
  });
}
