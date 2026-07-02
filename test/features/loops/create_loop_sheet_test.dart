import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/providers/loops_notifier.dart';
import 'package:happy_flutter/features/loops/create_loop_sheet.dart';

import 'loop_notifier_test_helpers.dart';

Widget _wrap({StubLoopsNotifier? notifier, CreateLoopSheet? sheet}) {
  return ProviderScope(
    overrides: [
      loopsNotifierProvider.overrideWith(() => notifier ?? StubLoopsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: sheet ?? const CreateLoopSheet(sessionId: 's1'),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CreateLoopSheet', () {
    testWidgets('pre-fills fields from initial values', (tester) async {
      await tester.pumpWidget(
        _wrap(
          sheet: const CreateLoopSheet(
            sessionId: 's1',
            initialExpression: '*/5 * * * *',
            initialPrompt: 'check the deploy',
            initialRecurring: true,
          ),
        ),
      );
      expect(find.text('*/5 * * * *'), findsOneWidget);
      expect(find.text('check the deploy'), findsOneWidget);
    });

    testWidgets('shows validation error when cron is empty', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Cron expression is required'), findsOneWidget);
    });

    testWidgets('shows validation error when cron has wrong field count',
        (tester) async {
      await tester.pumpWidget(_wrap());
      // Enter 4 fields — invalid (expected 5).
      await tester.enterText(find.byType(TextField).first, '* * * *');
      await tester.enterText(find.byType(TextField).last, 'check the deploy');
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(
        find.text('Cron expression is invalid (expected 5 fields)'),
        findsOneWidget,
      );
    });

    testWidgets('happy path creates loop and pops with Loop', (tester) async {
      Loop? popped;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsNotifierProvider.overrideWith(() => StubLoopsNotifier()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      popped = await showModalBottomSheet<Loop>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => const CreateLoopSheet(
                          sessionId: 's1',
                          initialExpression: '*/5 * * * *',
                          initialPrompt: 'check the deploy',
                          initialRecurring: true,
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(popped, isNotNull);
      expect(popped!.expression, '*/5 * * * *');
      expect(popped!.prompt, 'check the deploy');
    });

    testWidgets('shows snackbar on failure', (tester) async {
      await tester.pumpWidget(
        _wrap(notifier: StubLoopsNotifier(createError: 'daemon unavailable')),
      );
      await tester.pumpAndSettle();
      // Fill in valid values so the validator passes and the RPC fires.
      await tester.enterText(find.byType(TextField).first, '*/5 * * * *');
      await tester.enterText(find.byType(TextField).last, 'check the deploy');
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Failed to schedule loop'), findsOneWidget);
    });
  });
}
