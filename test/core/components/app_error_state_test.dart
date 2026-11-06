import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_error_state.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';

void main() {
  Widget buildApp({required Widget child}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('AppErrorState', () {
    testWidgets('renders message with the default error icon', (tester) async {
      await tester.pumpWidget(
        buildApp(child: const AppErrorState(message: 'Network down')),
      );

      expect(find.text('Network down'), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.warning_amber_rounded),
      );
      final cs = Theme.of(
        tester.element(find.byType(AppErrorState)),
      ).colorScheme;
      expect(icon.color, cs.error);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('title renders above the message as secondary detail', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildApp(
          child: const AppErrorState(
            title: "Couldn't load loops",
            message: 'boom',
          ),
        ),
      );

      final titleFinder = find.text("Couldn't load loops");
      final messageFinder = find.text('boom');
      expect(titleFinder, findsOneWidget);
      expect(messageFinder, findsOneWidget);
      expect(
        tester.getTopLeft(titleFinder).dy,
        lessThan(tester.getTopLeft(messageFinder).dy),
      );
      final cs = Theme.of(tester.element(messageFinder)).colorScheme;
      final message = tester.widget<Text>(messageFinder);
      expect(message.style?.color, cs.onSurfaceVariant);
    });

    testWidgets('announces title and message as one live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          buildApp(
            child: const AppErrorState(title: 'Load failed', message: 'boom'),
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp('Load failed.*boom')),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('retry button invokes the callback', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        buildApp(
          child: AppErrorState(
            title: 'Load failed',
            message: 'boom',
            onRetry: () => retries++,
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });
  });
}
