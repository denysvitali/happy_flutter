import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_color_scheme.dart';
import 'package:happy_flutter/core/ui/shimmer/shimmer.dart';

Widget _app(
  Widget child, {
  ThemeData? theme,
  MediaQueryData media = const MediaQueryData(),
  bool visible = true,
}) => MaterialApp(
  theme: theme,
  home: MediaQuery(
    data: media,
    child: TickerMode(
      enabled: visible,
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

/// One active [AnimationController] schedules exactly one transient frame
/// callback, so this counts the live tickers under the pumped tree.
int _tickers(WidgetTester tester) => tester.binding.transientCallbackCount;

void main() {
  for (final scoped in [false, true]) {
    Widget loading({bool enabled = true, int milliseconds = 100}) {
      final duration = Duration(milliseconds: milliseconds);
      return scoped
          ? ShimmerScope(
              enabled: enabled,
              duration: duration,
              child: const Shimmer(child: Text('loading')),
            )
          : Shimmer(
              enabled: enabled,
              duration: duration,
              child: const Text('loading'),
            );
    }

    group(scoped ? 'bounded shared shimmer' : 'bounded standalone shimmer', () {
      testWidgets('settles and routine rebuilds do not restart it', (
        tester,
      ) async {
        await tester.pumpWidget(_app(loading()));
        expect(_tickers(tester), 1);
        await tester.pumpAndSettle();
        expect(_tickers(tester), 0);
        expect(find.text('loading'), findsOneWidget);
        expect(find.byType(ShaderMask), findsOneWidget);
        await tester.pumpWidget(
          _app(loading(), media: const MediaQueryData(size: Size(1200, 800))),
        );
        expect(_tickers(tester), 0);

        // A new enabled episode and a changed duration each get a fresh,
        // bounded animation; unchanged values above do not.
        await tester.pumpWidget(_app(loading(enabled: false)));
        expect(_tickers(tester), 0);
        await tester.pumpWidget(_app(loading()));
        expect(_tickers(tester), 1);
        await tester.pumpAndSettle();
        await tester.pumpWidget(_app(loading(milliseconds: 200)));
        expect(_tickers(tester), 1);
        await tester.pumpAndSettle();
        expect(_tickers(tester), 0);
      });

      for (final media in [
        const MediaQueryData(disableAnimations: true),
        const MediaQueryData(accessibleNavigation: true),
      ]) {
        testWidgets('reduced motion stays static through updates $media', (
          tester,
        ) async {
          await tester.pumpWidget(_app(loading(), media: media));
          expect(_tickers(tester), 0);
          expect(find.byType(ShaderMask), findsOneWidget);
          await tester.pumpWidget(_app(loading(enabled: false), media: media));
          await tester.pumpWidget(
            _app(loading(milliseconds: 200), media: media),
          );
          expect(_tickers(tester), 0);
          await tester.pumpWidget(_app(loading(milliseconds: 200)));
          expect(_tickers(tester), 1);
          await tester.pumpAndSettle();

          await tester.pumpWidget(_app(loading()));
          expect(_tickers(tester), 1);
          await tester.pumpWidget(_app(loading(), media: media));
          expect(_tickers(tester), 0);
        });
      }

      testWidgets('hidden loading stops and resumes with bounded motion', (
        tester,
      ) async {
        await tester.pumpWidget(_app(loading()));
        await tester.pumpWidget(_app(loading(), visible: false));
        await tester.pump(const Duration(seconds: 20));
        expect(_tickers(tester), 0);
        await tester.pumpWidget(_app(loading()));
        expect(_tickers(tester), 1);
        await tester.pumpAndSettle();
        expect(_tickers(tester), 0);
      });

      testWidgets('zero duration is static and can become animated', (
        tester,
      ) async {
        await tester.pumpWidget(_app(loading(milliseconds: 0)));
        expect(_tickers(tester), 0);
        await tester.pumpWidget(_app(loading()));
        expect(_tickers(tester), 1);
        await tester.pumpAndSettle();
      });

      testWidgets('duration changes replace an in-flight motion budget', (
        tester,
      ) async {
        await tester.pumpWidget(_app(loading(milliseconds: 1000)));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpWidget(_app(loading(milliseconds: 100)));
        await tester.pumpAndSettle(
          const Duration(milliseconds: 50),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 2),
        );
        expect(_tickers(tester), 0);
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('Shimmer', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(_app(const Shimmer(child: Text('loading'))));

      expect(find.text('loading'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('enabled: false skips the shader and the ticker', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const Shimmer(enabled: false, child: Text('loading'))),
      );

      expect(find.text('loading'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      expect(_tickers(tester), 0);
    });

    testWidgets('each unscoped shimmer owns its own ticker', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              Shimmer(child: SizedBox(width: 40, height: 10)),
              Shimmer(child: SizedBox(width: 40, height: 10)),
            ],
          ),
        ),
      );

      expect(_tickers(tester), 2);
    });

    testWidgets('unmounting stops every ticker it started', (tester) async {
      await tester.pumpWidget(
        _app(const Shimmer(child: SizedBox(width: 40, height: 10))),
      );
      expect(_tickers(tester), 1);

      await tester.pumpWidget(_app(const SizedBox.shrink()));

      expect(_tickers(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('animates without throwing across a few frames', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const Shimmer(child: SizedBox(width: 100, height: 20))),
      );

      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('paints with a custom colour list', (tester) async {
      await tester.pumpWidget(
        _app(
          const Shimmer(
            colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green],
            child: SizedBox(width: 100, height: 20),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('paints with the theme shimmer extension', (tester) async {
      final theme = ThemeData(
        extensions: <ThemeExtension<dynamic>>[AppColorScheme.dark()],
      );
      await tester.pumpWidget(
        _app(
          const Shimmer(child: SizedBox(width: 100, height: 20)),
          theme: theme,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ShaderMask), findsOneWidget);
    });
  });

  group('ShimmerScope', () {
    testWidgets('hidden or reduced-motion children ignore a live scope', (
      tester,
    ) async {
      for (final hidden in [false, true]) {
        await tester.pumpWidget(
          _app(
            ShimmerScope(
              child: MediaQuery(
                data: MediaQueryData(disableAnimations: !hidden),
                child: TickerMode(
                  enabled: !hidden,
                  child: const Shimmer(child: Text('loading')),
                ),
              ),
            ),
          ),
        );
        expect(_tickers(tester), 1);
        final before = tester.widget<ShaderMask>(find.byType(ShaderMask));
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          identical(tester.widget<ShaderMask>(find.byType(ShaderMask)), before),
          isTrue,
        );
        await tester.pumpWidget(_app(const SizedBox.shrink()));
        expect(_tickers(tester), 0);
      }
    });

    testWidgets('a retained shimmer can move in and out of a scope', (
      tester,
    ) async {
      final key = GlobalKey();
      Widget loading() => Shimmer(
        key: key,
        duration: const Duration(milliseconds: 100),
        child: const Text('loading'),
      );
      await tester.pumpWidget(_app(loading()));
      expect(_tickers(tester), 1);
      await tester.pumpWidget(
        _app(
          ShimmerScope(
            duration: const Duration(milliseconds: 100),
            child: loading(),
          ),
        ),
      );
      expect(_tickers(tester), 1);
      await tester.pumpWidget(_app(loading()));
      expect(_tickers(tester), 1);
      await tester.pumpAndSettle();
      expect(_tickers(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shares one ticker across every descendant shimmer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ShimmerScope(
            child: Column(
              children: [
                Shimmer(child: SizedBox(width: 40, height: 10)),
                Shimmer(child: SizedBox(width: 40, height: 10)),
                Shimmer(child: SizedBox(width: 40, height: 10)),
              ],
            ),
          ),
        ),
      );

      expect(_tickers(tester), 1);
    });

    testWidgets('enabled: false leaves the shared ticker idle', (tester) async {
      await tester.pumpWidget(
        _app(
          const ShimmerScope(
            enabled: false,
            child: Shimmer(child: SizedBox(width: 40, height: 10)),
          ),
        ),
      );

      expect(_tickers(tester), 0);
    });

    testWidgets('toggling enabled starts and stops the shared ticker', (
      tester,
    ) async {
      var enabled = false;
      late StateSetter setOuter;

      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return ShimmerScope(
                enabled: enabled,
                child: const Shimmer(child: SizedBox(width: 40, height: 10)),
              );
            },
          ),
        ),
      );
      expect(_tickers(tester), 0);

      setOuter(() => enabled = true);
      await tester.pump();
      expect(_tickers(tester), 1);

      setOuter(() => enabled = false);
      await tester.pump();
      expect(_tickers(tester), 0);
    });

    testWidgets('unmounting the scope disposes the shared ticker', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ShimmerScope(
            child: Shimmer(child: SizedBox(width: 40, height: 10)),
          ),
        ),
      );
      expect(_tickers(tester), 1);

      await tester.pumpWidget(_app(const SizedBox.shrink()));

      expect(_tickers(tester), 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('ShimmerPulse', () {
    testWidgets('settles at full opacity and does not restart on rebuild', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ShimmerPulse()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(const ShimmerPulse(size: 32)));
      expect(_tickers(tester), 0);
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(ShimmerPulse),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, 1);
    });

    for (final media in [
      const MediaQueryData(disableAnimations: true),
      const MediaQueryData(accessibleNavigation: true),
    ]) {
      testWidgets('honors reduced motion $media', (tester) async {
        await tester.pumpWidget(_app(const ShimmerPulse(), media: media));
        expect(_tickers(tester), 0);
        await tester.pumpWidget(_app(const ShimmerPulse()));
        expect(_tickers(tester), 1);
        await tester.pumpWidget(_app(const ShimmerPulse(), visible: false));
        await tester.pump(const Duration(seconds: 20));
        expect(_tickers(tester), 0);
        await tester.pumpWidget(_app(const ShimmerPulse()));
        await tester.pumpAndSettle();
        expect(_tickers(tester), 0);
      });
    }

    testWidgets('renders at the requested size and animates', (tester) async {
      await tester.pumpWidget(_app(const ShimmerPulse(size: 32)));

      expect(_tickers(tester), 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes its controller on unmount', (tester) async {
      await tester.pumpWidget(_app(const ShimmerPulse()));
      await tester.pumpWidget(_app(const SizedBox.shrink()));

      expect(_tickers(tester), 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('ShimmerStyles', () {
    testWidgets('every preset renders inside one shared scope', (tester) async {
      await tester.pumpWidget(
        _app(
          ShimmerScope(
            child: Builder(
              builder: (context) => Column(
                children: [
                  ShimmerStyles.avatar(context: context),
                  ShimmerStyles.textLine(context: context, width: 80),
                  ShimmerStyles.card(context: context, height: 20, width: 80),
                  ShimmerStyles.textLines(
                    context: context,
                    lines: 2,
                    width: 80,
                  ),
                  const ShimmerImagePlaceholder(width: 40, height: 20),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsNWidgets(5));
      expect(_tickers(tester), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('textLines renders one bar per requested line', (tester) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) =>
                ShimmerStyles.textLines(context: context, lines: 4, width: 80),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(Shimmer),
          matching: find.byType(Container),
        ),
        findsNWidgets(4),
      );
    });
  });
}
