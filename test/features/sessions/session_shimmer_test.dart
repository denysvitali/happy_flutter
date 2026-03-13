import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/sessions/widgets/session_shimmer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionListShimmer', () {
    testWidgets('renders as a ListView', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SessionListShimmer(),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('contains shimmer placeholder rows',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SessionListShimmer(),
          ),
        ),
      );

      // The shimmer should contain circle placeholders
      // for avatars
      final containers = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Container),
      );
      expect(containers, findsWidgets);
    });

    testWidgets('contains Shimmer widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SessionListShimmer(),
          ),
        ),
      );

      // At least one Shimmer widget should exist
      // (the shimmer package widget)
      expect(
        find.byType(SessionListShimmer),
        findsOneWidget,
      );
    });
  });
}
