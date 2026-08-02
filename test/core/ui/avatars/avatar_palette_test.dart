import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/ui/avatars/avatar_palette.dart';

/// Relative luminance contrast ratio per WCAG 2.1.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('avatarHash', () {
    test('is stable for the same id', () {
      expect(avatarHash('session-abc'), avatarHash('session-abc'));
    });

    test('separates ids that differ only in the last character', () {
      // The old additive fold put these one degree apart on the hue
      // wheel, which is what made every session card look identical.
      final indices = <int>{
        for (var i = 1; i <= 5; i++) avatarPaletteIndex('session$i'),
      };
      expect(indices.length, greaterThanOrEqualTo(4));
    });

    test('spreads a realistic batch of ids across the palette', () {
      final indices = <int>{
        for (var i = 0; i < 60; i++)
          avatarPaletteIndex('c948d14cf2c6fc05733${i.toString()}'),
      };
      expect(indices.length, greaterThanOrEqualTo(8));
    });

    test('is not sensitive to character order', () {
      expect(avatarHash('ab'), isNot(avatarHash('ba')));
    });
  });

  group('avatar colours', () {
    test('are deterministic per id and brightness', () {
      expect(
        avatarBackgroundColor('abc', Brightness.dark),
        avatarBackgroundColor('abc', Brightness.dark),
      );
      expect(
        avatarBackgroundColor('abc', Brightness.light),
        isNot(avatarBackgroundColor('abc', Brightness.dark)),
      );
    });

    test('initials keep readable contrast in both themes', () {
      for (var i = 0; i < kAvatarHues.length; i++) {
        final id = 'contrast-probe-$i';
        for (final brightness in Brightness.values) {
          final bg = avatarBackgroundColor(id, brightness);
          final fg = avatarForegroundColor(bg);
          expect(
            _contrast(bg, fg),
            greaterThanOrEqualTo(4.5),
            reason: 'id=$id brightness=$brightness',
          );
        }
      }
    });

    test('surface ink stays legible on the card surface', () {
      const lightSurface = Color(0xFFFFFBFE);
      const darkSurface = Color(0xFF141218);
      for (var i = 0; i < kAvatarHues.length; i++) {
        final id = 'ink-probe-$i';
        expect(
          _contrast(avatarInkOnSurface(id, Brightness.light), lightSurface),
          greaterThanOrEqualTo(4.5),
          reason: 'light id=$id',
        );
        expect(
          _contrast(avatarInkOnSurface(id, Brightness.dark), darkSurface),
          greaterThanOrEqualTo(4.5),
          reason: 'dark id=$id',
        );
      }
    });
  });
}
