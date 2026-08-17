import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/thinking_stop_bar.dart';

Widget _app(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Column(children: [child])),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThinkingStopBar', () {
    testWidgets('thinking state offers an enabled Stop action', (tester) async {
      var stops = 0;
      await tester.pumpWidget(
        _app(ThinkingStopBar(onStop: () => stops++)),
      );

      expect(find.text('Thinking…'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      expect(stops, 1);
    });

    testWidgets('stopping state disables Stop and keeps one indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ThinkingStopBar(
            activity: ChatAgentActivity.stopping,
            onStop: () {},
          ),
        ),
      );

      expect(find.text('Stopping…'), findsOneWidget);
      expect(find.text('Thinking…'), findsNothing);
      // No spinner: the row swaps text and mutes its dot rather than
      // introducing a second animation primitive mid-turn.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('unconfirmed stop re-offers the action', (tester) async {
      var stops = 0;
      await tester.pumpWidget(
        _app(
          ThinkingStopBar(
            activity: ChatAgentActivity.stopUnconfirmed,
            onStop: () => stops++,
          ),
        ),
      );

      expect(find.text('Stop not confirmed — still running'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      expect(stops, 1);
    });

    testWidgets('height is stable across every activity state', (
      tester,
    ) async {
      final heights = <double>[];
      for (final activity in ChatAgentActivity.values) {
        await tester.pumpWidget(
          _app(ThinkingStopBar(activity: activity, onStop: () {})),
        );
        heights.add(tester.getSize(find.byType(ThinkingStopBar)).height);
      }

      // A stop request must not resize the chrome under the message list.
      expect(heights.toSet(), hasLength(1));
    });

    testWidgets('honours reduced motion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: ThinkingStopBar(onStop: () {})),
          ),
        ),
      );

      // No repeating ticker left running when animations are disabled.
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
