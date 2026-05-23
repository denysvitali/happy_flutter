import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/send_status_indicator.dart';

Widget _buildIndicator(String status) {
  return MaterialApp(
    home: Scaffold(
      body: SendStatusIndicator(status: status, onRetry: () {}),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders queued retry state', (tester) async {
    await tester.pumpWidget(_buildIndicator('pending'));

    expect(find.text('Retry queued'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
  });

  testWidgets('renders delivered state', (tester) async {
    await tester.pumpWidget(_buildIndicator('sent'));

    expect(find.text('Delivered'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('renders failed retry affordance', (tester) async {
    await tester.pumpWidget(_buildIndicator('failed'));

    expect(find.text('Failed — tap to retry'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });
}
