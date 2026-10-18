import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_color_scheme.dart';
import 'package:happy_flutter/core/ui/shimmer/shimmer.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: child)),
);

/// One active [AnimationController] schedules exactly one transient frame
/// callback, so this counts the live tickers under the pumped tree.
int _tickers(WidgetTester tester) => tester.binding.transientCallbackCount;

void main() {
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
