import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/features/zen/widgets/todo_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZenTodoItem', () {
    TodoItem item({String? description, TodoState status = TodoState.pending}) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return TodoItem(
        id: 't1',
        content: 'Task title',
        status: status,
        priority: 'medium',
        order: 0,
        description: description,
        createdAt: now,
        updatedAt: now,
      );
    }

    Widget wrap(Widget child) {
      return MaterialApp(home: Scaffold(body: child));
    }

    testWidgets('renders title and abbreviated description', (tester) async {
      final longDesc = 'A'.padLeft(120, 'A');
      await tester.pumpWidget(
        wrap(
          ZenTodoItem(
            item: item(description: longDesc),
            onToggleComplete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task title'), findsOneWidget);
      expect(find.text(longDesc), findsNothing);
      expect(find.textContaining('A'.padLeft(80, 'A')), findsOneWidget);
    });

    testWidgets('does not render description when absent', (tester) async {
      await tester.pumpWidget(
        wrap(
          ZenTodoItem(
            item: item(),
            onToggleComplete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task title'), findsOneWidget);
      expect(find.textContaining('A'), findsNothing);
    });

    testWidgets('tap opens detail dialog with full description', (tester) async {
      // Use a long description so the row abbreviates it; the full text
      // only appears inside the dialog.
      final longDesc = 'A'.padLeft(120, 'A');
      await tester.pumpWidget(
        wrap(
          ZenTodoItem(
            item: item(description: longDesc),
            onToggleComplete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Task title'));
      await tester.pumpAndSettle();

      // Dialog shows the full description and a close action.
      expect(find.text(longDesc), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('swipe still toggles completion', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        wrap(
          ZenTodoItem(
            item: item(status: TodoState.pending),
            onToggleComplete: () => toggled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fling left-to-right far enough to trigger the Dismissible.
      await tester.fling(
        find.text('Task title'),
        const Offset(500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
    });
  });
}
