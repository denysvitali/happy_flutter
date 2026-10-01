import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/components/app_status_dot.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/streaming_cursor.dart';
import 'package:happy_flutter/features/chat/widgets/thinking_stop_bar.dart';
import 'package:happy_flutter/features/sessions/widgets/connection_status_badge.dart';

Widget _app(
  Widget child, {
  MediaQueryData media = const MediaQueryData(),
  bool tickerEnabled = true,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: media,
      child: TickerMode(
        enabled: tickerEnabled,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 8),
  );
  expect(tester.binding.transientCallbackCount, 0);
}

void main() {
  final indicators = <String, Widget Function()>{
    'status dot': () => const AppStatusDot(color: Colors.green, pulse: true),
    'thinking dot': () => ThinkingStopBar(onStop: () {}),
    'streaming cursor': () => const StreamingCursor(),
    'connection badge': () =>
        const ConnectionStatusBadge(status: ConnectionStatus.connecting),
  };

  for (final entry in indicators.entries) {
    group(entry.key, () {
      testWidgets('pulses briefly then stays visible without frames', (
        tester,
      ) async {
        await tester.pumpWidget(_app(entry.value()));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        await _settle(tester);

        // A routine rebuild (including a MediaQuery size update) must not
        // restart decorative activity while the logical state is unchanged.
        await tester.pumpWidget(
          _app(
            entry.value(),
            media: const MediaQueryData(size: Size(1200, 800)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.binding.transientCallbackCount, 0);
        final fades = tester.widgetList<FadeTransition>(
          find.descendant(
            of: find.byType(entry.value().runtimeType),
            matching: find.byType(FadeTransition),
          ),
        );
        for (final fade in fades) {
          expect(fade.opacity.value, 1);
        }
        expect(find.byType(entry.value().runtimeType), findsOneWidget);
      });

      for (final media in [
        const MediaQueryData(disableAnimations: true),
        const MediaQueryData(accessibleNavigation: true),
      ]) {
        testWidgets('remains static for reduced motion $media', (tester) async {
          await tester.pumpWidget(_app(entry.value(), media: media));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.binding.transientCallbackCount, 0);

          // A status update while accessibility is enabled must not start
          // a controller via didUpdateWidget.
          await tester.pumpWidget(_app(entry.value(), media: media));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.binding.transientCallbackCount, 0);
        });
      }

      testWidgets('stops when hidden and resumes with a bounded pulse', (
        tester,
      ) async {
        await tester.pumpWidget(_app(entry.value()));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(_app(entry.value(), tickerEnabled: false));
        await tester.pump(const Duration(seconds: 20));
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpWidget(_app(entry.value()));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        await _settle(tester);
      });

      testWidgets('stops immediately when reduced motion is enabled', (
        tester,
      ) async {
        await tester.pumpWidget(_app(entry.value()));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(
          _app(
            entry.value(),
            media: const MediaQueryData(disableAnimations: true),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpWidget(_app(entry.value()));
        await _settle(tester);
      });
    });
  }

  testWidgets('new status activity restarts the bounded animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AppStatusDot(color: Colors.green, pulse: true)),
    );
    await _settle(tester);
    await tester.pumpWidget(_app(const AppStatusDot(color: Colors.green)));
    await tester.pumpWidget(
      _app(const AppStatusDot(color: Colors.green, pulse: true)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await _settle(tester);
  });

  testWidgets('connecting after reduced motion stays static', (tester) async {
    const media = MediaQueryData(accessibleNavigation: true);
    await tester.pumpWidget(
      _app(
        const ConnectionStatusBadge(status: ConnectionStatus.connected),
        media: media,
      ),
    );
    await tester.pumpWidget(
      _app(
        const ConnectionStatusBadge(status: ConnectionStatus.connecting),
        media: media,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
