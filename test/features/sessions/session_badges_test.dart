import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/sessions/widgets/session_badges.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── SelectionCheckbox ───────────────────────────────────

  group('SelectionCheckbox', () {
    testWidgets('shows check icon when selected',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: SelectionCheckbox(
                isSelected: true,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('hides check icon when not selected',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: SelectionCheckbox(
                isSelected: false,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('renders with correct width',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: SelectionCheckbox(
                isSelected: false,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
        ),
      );

      // The SelectionCheckbox container has width 36
      final containers = find.byType(Container);
      final container = tester.widget<Container>(
        containers.first,
      );
      expect(
        container.constraints?.maxWidth ?? container.constraints?.minWidth ?? 0,
        36,
      );
    });
  });

  // ─── DraftBadge ──────────────────────────────────────────

  group('DraftBadge', () {
    testWidgets('renders draft icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                children: [
                  const DraftBadge(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(
        find.byIcon(Icons.drive_file_rename_outline),
        findsOneWidget,
      );
    });
  });

  // ─── TodoProgressBadge ───────────────────────────────────

  group('TodoProgressBadge', () {
    testWidgets('displays completed/total text',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TodoProgressBadge(
              completed: 2,
              total: 5,
            ),
          ),
        ),
      );

      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('displays zero progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TodoProgressBadge(
              completed: 0,
              total: 3,
            ),
          ),
        ),
      );

      expect(find.text('0/3'), findsOneWidget);
    });

    testWidgets('renders lightbulb icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TodoProgressBadge(
              completed: 1,
              total: 2,
            ),
          ),
        ),
      );

      expect(
        find.byIcon(Icons.lightbulb_outline),
        findsOneWidget,
      );
    });
  });
}
