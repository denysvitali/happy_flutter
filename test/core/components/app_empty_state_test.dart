import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_empty_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({required Widget child}) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('AppEmptyState', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.inbox,
          title: 'No items',
        ),
      ));

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('No items'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.inbox,
          title: 'No items',
          subtitle: 'Try adding some',
        ),
      ));

      expect(find.text('No items'), findsOneWidget);
      expect(find.text('Try adding some'), findsOneWidget);
    });

    testWidgets('does not render subtitle when null', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.inbox,
          title: 'No items',
        ),
      ));

      expect(find.text('No items'), findsOneWidget);
      // Should only have one Text widget (the title).
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders action widget when provided', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.inbox,
          title: 'No items',
          action: ElevatedButton(
            onPressed: null,
            child: Text('Add Item'),
          ),
        ),
      ));

      expect(find.text('Add Item'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('does not render action when null', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.inbox,
          title: 'No items',
        ),
      ));

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('is centered in parent', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.inbox,
          title: 'Centered',
        ),
      ));

      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('has breathing animation controller', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.inbox,
          title: 'Animated',
        ),
      ));

      // AnimatedBuilder is used for the breathing animation.
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });

    testWidgets('icon is inside gradient container', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.inbox,
          title: 'Gradient',
        ),
      ));

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(AppEmptyState),
          matching: find.byType(Container),
        ),
      );

      // At least one container should have a BoxDecoration with gradient.
      final hasGradient = containers.any((c) {
        if (c.decoration is BoxDecoration) {
          return (c.decoration as BoxDecoration).gradient != null;
        }
        return false;
      });
      expect(hasGradient, isTrue);
    });

    testWidgets('renders with all optional parameters', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.search,
          title: 'No results',
          subtitle: 'Try a different search',
          action: TextButton(
            onPressed: null,
            child: Text('Clear'),
          ),
        ),
      ));

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('No results'), findsOneWidget);
      expect(find.text('Try a different search'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('disposes animation controller properly',
        (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.inbox,
          title: 'Disposable',
        ),
      ));

      // Replace with different widget to trigger dispose.
      await tester.pumpWidget(buildApp(
        child: const Text('Replaced'),
      ));

      // If dispose is broken, this would throw.
      expect(find.text('Replaced'), findsOneWidget);
    });

    testWidgets('Column has MainAxisSize.min', (tester) async {
      await tester.pumpWidget(buildApp(
        child: const AppEmptyState(
          icon: Icons.inbox,
          title: 'Compact',
        ),
      ));

      final column = tester.widget<Column>(
        find.descendant(
          of: find.byType(AppEmptyState),
          matching: find.byType(Column),
        ).first,
      );

      expect(column.mainAxisSize, MainAxisSize.min);
    });
  });
}
