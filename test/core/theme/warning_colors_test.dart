import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_color_scheme.dart';

void main() {
  for (final colors in [AppColorScheme.light(), AppColorScheme.dark()]) {
    test('warning foregrounds contrast with their own surfaces: '
        '${colors.warningContainer}', () {
      expect(
        _contrastRatio(colors.onWarning, colors.warning),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(colors.onWarningContainer, colors.warningContainer),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  test(
    'warning container foreground survives theme copies and transitions',
    () {
      final light = AppColorScheme.light();
      final dark = AppColorScheme.dark();
      expect(light.copyWith().onWarningContainer, light.onWarningContainer);
      final replacement = light.onWarningContainer;
      expect(
        dark.copyWith(onWarningContainer: replacement).onWarningContainer,
        replacement,
      );
      expect(light.lerp(dark, 0).onWarningContainer, light.onWarningContainer);
      expect(light.lerp(dark, 1).onWarningContainer, dark.onWarningContainer);
      expect(
        light.lerp(dark, 0.5).onWarningContainer,
        Color.lerp(light.onWarningContainer, dark.onWarningContainer, 0.5),
      );
    },
  );
}

double _contrastRatio(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);
}
