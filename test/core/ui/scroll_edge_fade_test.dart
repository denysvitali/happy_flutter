import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/ui/scroll_edge_fade.dart';

/// Wraps [ScrollEdgeFade] in a MaterialApp with a configurable brightness
/// so the test can assert the fade samples `colorScheme.surface` rather
/// than a hardcoded white.
Widget _wrap({
  required Brightness brightness,
  double topExtent = 24,
  double bottomExtent = 0,
  Widget? child,
}) {
  final colorScheme = brightness == Brightness.dark
      ? ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        )
      : ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        );
  return MaterialApp(
    theme: ThemeData(colorScheme: colorScheme, useMaterial3: true),
    home: Scaffold(
      body: ScrollEdgeFade(
        topExtent: topExtent,
        bottomExtent: bottomExtent,
        child: child ??
            const SizedBox(
              height: 200,
              width: 200,
              child: ColoredBox(color: Color(0xFF123456)),
            ),
      ),
    ),
  );
}

/// The gradients painted by [ScrollEdgeFade], outermost first.
List<LinearGradient> _fadeGradients(WidgetTester tester) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(ScrollEdgeFade),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>()
      .map((decoration) => decoration.gradient)
      .whereType<LinearGradient>()
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScrollEdgeFade', () {
    testWidgets('returns child directly when both extents are zero', (
      tester,
    ) async {
      // Zero extents short-circuit the overlay entirely.
      await tester.pumpWidget(
        _wrap(
          brightness: Brightness.light,
          topExtent: 0,
          child: const Text('untouched'),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(ScrollEdgeFade),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
      expect(find.text('untouched'), findsOneWidget);
    });

    testWidgets('paints an overlay gradient, never a ShaderMask', (
      tester,
    ) async {
      // A ShaderMask around a full-screen list forces an offscreen
      // saveLayer of the whole viewport on every scrolled frame. The fade
      // is a small overlay quad instead — reverting to ShaderMask would
      // reintroduce that per-frame raster cost.
      await tester.pumpWidget(_wrap(brightness: Brightness.light));
      expect(find.byType(ShaderMask), findsNothing);
      expect(_fadeGradients(tester), hasLength(1));
    });

    testWidgets('fades from the surface color, not Colors.white', (
      tester,
    ) async {
      final lightSurface = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: Brightness.light,
      ).surface;
      expect(lightSurface, isNot(equals(Colors.white)));

      await tester.pumpWidget(_wrap(brightness: Brightness.light));
      final gradient = _fadeGradients(tester).single;
      expect(gradient.colors.first, equals(lightSurface));
      expect(gradient.colors.last.a, equals(0.0));
    });

    testWidgets('renders one gradient per enabled edge', (tester) async {
      await tester.pumpWidget(
        _wrap(brightness: Brightness.dark, bottomExtent: 16),
      );
      final gradients = _fadeGradients(tester);
      expect(gradients, hasLength(2));
      expect(gradients.first.begin, equals(Alignment.topCenter));
      expect(gradients.last.begin, equals(Alignment.bottomCenter));
    });

    testWidgets('the fade never absorbs taps meant for the list', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          brightness: Brightness.light,
          child: GestureDetector(
            onTap: () => taps++,
            child: const SizedBox.expand(
              child: ColoredBox(color: Color(0xFF123456)),
            ),
          ),
        ),
      );
      // Tap inside the top fade band — it must reach the content below.
      await tester.tapAt(const Offset(100, 10));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
