import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/avatar.dart';
import 'package:happy_flutter/core/ui/avatars/avatar_constellation.dart';
import 'package:happy_flutter/core/ui/avatars/avatar_geometric.dart';
import 'package:happy_flutter/core/ui/avatars/avatar_rings.dart';
import 'package:happy_flutter/core/ui/avatars/avatar_wave.dart';
import 'package:happy_flutter/core/widgets/network_avatar_image.dart';

import 'package:happy_flutter/core/ui/avatars/avatar_brutalist.dart' as canvas;
import 'package:happy_flutter/core/ui/avatars/avatar_gradient.dart'
    as canvas_gradient;

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

CustomPainter _painterOf(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(AvatarSkia),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter!;

void main() {
  group('Avatar style dispatch', () {
    testWidgets('each style renders its own implementation', (tester) async {
      const id = 'session-abc';
      final expected = <AvatarStyle, Type>{
        AvatarStyle.brutalist: canvas.AvatarBrutalist,
        AvatarStyle.gradient: canvas_gradient.AvatarGradient,
        AvatarStyle.pixelated: AvatarSkia,
        AvatarStyle.geometric: AvatarGeometric,
        AvatarStyle.rings: AvatarRings,
        AvatarStyle.constellation: AvatarConstellation,
        AvatarStyle.wave: AvatarWave,
      };

      for (final entry in expected.entries) {
        await tester.pumpWidget(
          _app(Avatar(id: id, style: entry.key, size: 40)),
        );

        expect(
          find.byType(entry.value),
          findsOneWidget,
          reason: 'style ${entry.key} should render ${entry.value}',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('an imageUrl wins over the generated style', (tester) async {
      await tester.pumpWidget(
        _app(
          const Avatar(
            id: 'session-abc',
            imageUrl: 'https://example.invalid/a.png',
          ),
        ),
      );

      expect(find.byType(NetworkAvatarImage), findsOneWidget);
      expect(find.byType(canvas.AvatarBrutalist), findsNothing);
    });

    testWidgets('renders at the requested size in both themes', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          _app(const Avatar(id: 'sizing', size: 64), brightness: brightness),
        );

        expect(
          tester.getSize(find.byType(canvas.AvatarBrutalist)),
          const Size(64, 64),
        );
      }
    });
  });

  group('initials', () {
    testWidgets('uses the first two alphanumeric characters, uppercased', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const Avatar(id: 'denys-vitali')));

      expect(find.text('DE'), findsOneWidget);
    });

    testWidgets('a single usable character renders alone', (tester) async {
      await tester.pumpWidget(_app(const Avatar(id: 'a')));

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('punctuation and emoji fall back to a question mark', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const Avatar(id: '--- 🎉 ---')));

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('an empty id renders without throwing', (tester) async {
      await tester.pumpWidget(_app(const Avatar(id: '')));

      expect(find.text('?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a very long id is truncated to two characters', (
      tester,
    ) async {
      await tester.pumpWidget(_app(Avatar(id: 'z' * 4000)));

      expect(find.text('ZZ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AvatarSkia pixel grid', () {
    testWidgets('the same id paints the same grid', (tester) async {
      await tester.pumpWidget(
        _app(const Avatar(id: 'stable', style: AvatarStyle.pixelated)),
      );
      final first = _painterOf(tester);

      await tester.pumpWidget(
        _app(
          const Avatar(
            key: ValueKey('second'),
            id: 'stable',
            style: AvatarStyle.pixelated,
          ),
        ),
      );

      expect(_painterOf(tester).shouldRepaint(first), isFalse);
    });

    testWidgets('a different id paints a different grid', (tester) async {
      await tester.pumpWidget(
        _app(const Avatar(id: 'one', style: AvatarStyle.pixelated)),
      );
      final first = _painterOf(tester);

      await tester.pumpWidget(
        _app(
          const Avatar(
            key: ValueKey('second'),
            id: 'two',
            style: AvatarStyle.pixelated,
          ),
        ),
      );

      expect(_painterOf(tester).shouldRepaint(first), isTrue);
    });

    testWidgets('monochrome repaints against the colour palette', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const Avatar(id: 'mono', style: AvatarStyle.pixelated)),
      );
      final colored = _painterOf(tester);

      await tester.pumpWidget(
        _app(
          const Avatar(
            key: ValueKey('second'),
            id: 'mono',
            monochrome: true,
            style: AvatarStyle.pixelated,
          ),
        ),
      );

      expect(_painterOf(tester).shouldRepaint(colored), isTrue);
    });

    testWidgets('square drops the circular clip radius', (tester) async {
      await tester.pumpWidget(
        _app(
          const Avatar(
            id: 'square',
            square: true,
            size: 40,
            style: AvatarStyle.pixelated,
          ),
        ),
      );

      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(AvatarSkia),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(0));
    });

    testWidgets('an empty id still paints a grid', (tester) async {
      await tester.pumpWidget(
        _app(const Avatar(id: '', style: AvatarStyle.pixelated)),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('canvas avatar styles', () {
    testWidgets('every style paints at small and large sizes', (tester) async {
      for (final style in AvatarStyle.values) {
        for (final size in <double>[20, 96]) {
          await tester.pumpWidget(
            _app(Avatar(id: 'scale-$style', style: style, size: size)),
          );
          await tester.pump();

          expect(
            tester.takeException(),
            isNull,
            reason: '$style at $size should paint cleanly',
          );
        }
      }
    });
  });
}
