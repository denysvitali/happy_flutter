import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/components/app_status_dot.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/elapsed_time.dart';
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
  for (final textVariant in [false, true]) {
    Widget elapsed(int? startTime) => textVariant
        ? ElapsedTimeWidget(startTime: startTime)
        : ElapsedTime(
            startTime: startTime,
            builder: (context, seconds) => Text('${seconds}s'),
          );

    group(textVariant ? 'elapsed text' : 'elapsed builder', () {
      testWidgets('hidden timers do not rebuild while a sibling is active', (
        tester,
      ) async {
        final startTime = DateTime.now().millisecondsSinceEpoch;
        const hiddenKey = ValueKey('hidden elapsed');
        const visibleKey = ValueKey('visible elapsed');
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                TickerMode(
                  enabled: false,
                  child: KeyedSubtree(
                    key: hiddenKey,
                    child: elapsed(startTime),
                  ),
                ),
                KeyedSubtree(key: visibleKey, child: elapsed(startTime)),
              ],
            ),
          ),
        );
        final hidden = find.descendant(
          of: find.byKey(hiddenKey),
          matching: find.byType(Text),
        );
        final visible = find.descendant(
          of: find.byKey(visibleKey),
          matching: find.byType(Text),
        );
        final hiddenBefore = tester.widget<Text>(hidden);
        final visibleBefore = tester.widget<Text>(visible);
        await tester.pump(const Duration(seconds: 2));
        expect(identical(tester.widget<Text>(hidden), hiddenBefore), isTrue);
        expect(identical(tester.widget<Text>(visible), visibleBefore), isFalse);
        await tester.pumpWidget(_app(const SizedBox.shrink()));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('resuming catches up immediately from wall time', (
        tester,
      ) async {
        final startTime = DateTime.now().millisecondsSinceEpoch;
        final child = elapsed(startTime);
        await tester.pumpWidget(_app(child));
        await tester.pumpWidget(_app(child, tickerEnabled: false));
        final before = tester.widget<Text>(find.byType(Text));
        // Timer pumps advance Flutter's fake time, not DateTime.now(). Use
        // real wall time here to pin catch-up without changing the start ID.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1100)),
        );
        await tester.pump(const Duration(seconds: 10));
        expect(
          identical(tester.widget<Text>(find.byType(Text)), before),
          isTrue,
        );
        await tester.pumpWidget(_app(child));
        final after = tester.widget<Text>(find.byType(Text));
        expect(
          int.parse(after.data!.replaceAll('s', '')),
          greaterThanOrEqualTo(1),
        );
        await tester.pumpWidget(_app(const SizedBox.shrink()));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'null and changed start times remain safe across visibility',
        (tester) async {
          await tester.pumpWidget(_app(elapsed(null)));
          expect(find.text('0s'), findsOneWidget);
          final now = DateTime.now().millisecondsSinceEpoch;
          await tester.pumpWidget(_app(elapsed(now - 5000)));
          expect(find.text('5s'), findsOneWidget);
          await tester.pumpWidget(_app(elapsed(null), tickerEnabled: false));
          expect(find.text('0s'), findsOneWidget);
          await tester.pumpWidget(_app(elapsed(now + 60000)));
          expect(find.text('0s'), findsOneWidget);
          await tester.pumpWidget(_app(const SizedBox.shrink()));
          expect(tester.takeException(), isNull);
        },
      );
    });
  }

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
