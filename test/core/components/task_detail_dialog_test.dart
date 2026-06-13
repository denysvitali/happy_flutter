import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/task_detail_dialog.dart';
import 'package:happy_flutter/core/models/todo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('showTaskDetailDialog', () {
    TodoItem item({
      String content = 'Title',
      String? description,
      TodoState status = TodoState.pending,
    }) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return TodoItem(
        id: 't1',
        content: content,
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

    testWidgets('shows title, status and description', (tester) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTaskDetailDialog(
                context: context,
                item: item(
                  content: 'Full title',
                  description: 'Full description.',
                  status: TodoState.inProgress,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Full title'), findsOneWidget);
      expect(find.text('Full description.'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
    });

    testWidgets('shows placeholder when description is missing', (tester) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTaskDetailDialog(
                context: context,
                item: item(content: 'No details'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('No description provided.'), findsOneWidget);
    });

    testWidgets('closes when Close is tapped', (tester) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTaskDetailDialog(
                context: context,
                item: item(description: 'Text'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Text'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Text'), findsNothing);
    });
  });
}
