import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/streaming_cursor.dart';

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StreamingCursor', () {
    testWidgets('renders a FadeTransition inside StreamingCursor', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const StreamingCursor()));

      expect(
        find.descendant(
          of: find.byType(StreamingCursor),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
    });

    testWidgets('caret stem keeps its token width', (tester) async {
      await tester.pumpWidget(_app(const StreamingCursor()));

      // The gradient caret stem is keyed explicitly so this assertion does
      // not depend on Container traversal order inside the breathing wrapper.
      final cursorContainer = tester.widget<Container>(
        find.byKey(const ValueKey('streaming-cursor-stem')),
      );
      expect(cursorContainer.constraints?.maxWidth, 3.0);
    });

    testWidgets('disposes without error', (tester) async {
      await tester.pumpWidget(_app(const StreamingCursor()));
      // Replace the widget tree to trigger dispose.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SizedBox.shrink(),
        ),
      );
      // No error thrown.
    });
  });
}
