import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/features/loops/loop_card.dart';

import 'loop_notifier_test_helpers.dart';

Widget _wrap({
  required Loop loop,
  required Future<void> Function(bool paused) onPauseToggle,
  required Future<void> Function() onDelete,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: LoopCard(
        loop: loop,
        onPauseToggle: onPauseToggle,
        onDelete: onDelete,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoopCard', () {
    testWidgets('pause button requests paused=true for an active loop', (
      tester,
    ) async {
      bool? requestedPaused;
      await tester.pumpWidget(
        _wrap(
          loop: testLoop(id: 'abc12345'),
          onPauseToggle: (paused) async => requestedPaused = paused,
          onDelete: () async {},
        ),
      );

      await tester.tap(find.text('Pause'));
      await tester.pump();

      expect(requestedPaused, isTrue);
    });

    testWidgets('resume button requests paused=false for a paused loop', (
      tester,
    ) async {
      bool? requestedPaused;
      await tester.pumpWidget(
        _wrap(
          loop: testLoop(id: 'abc12345', paused: true),
          onPauseToggle: (paused) async => requestedPaused = paused,
          onDelete: () async {},
        ),
      );

      await tester.tap(find.text('Resume'));
      await tester.pump();

      expect(requestedPaused, isFalse);
    });

    testWidgets('expired loops disable pause and show expired status', (
      tester,
    ) async {
      var pauseCalled = false;
      final now = DateTime.now().millisecondsSinceEpoch;
      await tester.pumpWidget(
        _wrap(
          loop: testLoop(id: 'abc12345', expiresAt: now - 1),
          onPauseToggle: (_) async => pauseCalled = true,
          onDelete: () async {},
        ),
      );

      expect(find.text('Expired'), findsWidgets);
      final pause = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Pause'),
      );
      expect(pause.onPressed, isNull);
      expect(pauseCalled, isFalse);
    });

    testWidgets('delete confirmation calls onDelete only after confirm', (
      tester,
    ) async {
      var deleteCalls = 0;
      await tester.pumpWidget(
        _wrap(
          loop: testLoop(id: 'abc12345'),
          onPauseToggle: (_) async {},
          onDelete: () async => deleteCalls++,
        ),
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleteCalls, 0);

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(deleteCalls, 1);
    });
  });
}
