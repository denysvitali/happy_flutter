import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/send_status_indicator.dart';

Widget _buildIndicator(
  String status, {
  VoidCallback? onRetry,
  bool slow = false,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SendStatusIndicator(
        status: status,
        slow: slow,
        onRetry: onRetry ?? () {},
      ),
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

  testWidgets('retry stops being actionable after delivery', (tester) async {
    var retries = 0;
    void retry() => retries++;

    await tester.pumpWidget(_buildIndicator('failed', onRetry: retry));
    await tester.tap(find.text('Failed — tap to retry'));
    expect(retries, 1);

    await tester.pumpWidget(_buildIndicator('pending', onRetry: retry));
    expect(find.text('Failed — tap to retry'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Retry queued'), findsOneWidget);

    await tester.pumpWidget(_buildIndicator('sent', onRetry: retry));
    expect(find.text('Retry queued'), findsNothing);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
    expect(retries, 1);
  });

  testWidgets('late delivery replaces queued state without retry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      _buildIndicator('pending', onRetry: () => retries++),
    );
    await tester.pumpWidget(
      _buildIndicator('sent', slow: true, onRetry: () => retries++),
    );

    final context = tester.element(find.byType(SendStatusIndicator));
    expect(find.text(context.l10n.chatSendDeliveredSlow), findsOneWidget);
    expect(find.text('Retry queued'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(retries, 0);
  });

  testWidgets('exposes localized send-state semantics', (tester) async {
    await tester.pumpWidget(_buildIndicator('failed'));

    final semantics = tester.getSemantics(find.byType(SendStatusIndicator));
    expect(semantics.label, contains('Message not delivered'));
    expect(
      semantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
  });
}
