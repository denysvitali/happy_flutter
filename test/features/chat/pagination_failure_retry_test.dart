import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/pagination_failure_retry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('history failure row explains the error and retries', (
    tester,
  ) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PaginationFailureRetry(onRetry: () => retryCount++),
        ),
      ),
    );

    expect(find.text('Failed to load messages'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retryCount, 1);
  });
}
