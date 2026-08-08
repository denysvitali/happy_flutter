import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

void main() {
  Future<({bool reduceMotion, Duration duration})> resolveMotion(
    WidgetTester tester,
    MediaQueryData mediaQueryData,
  ) async {
    var reduceMotion = false;
    var duration = Duration.zero;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: mediaQueryData,
          child: Builder(
            builder: (context) {
              reduceMotion = AppMotion.reduceMotion(context);
              duration = AppMotion.duration(context, AppDuration.normal);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    return (reduceMotion: reduceMotion, duration: duration);
  }

  group('AppMotion accessibility helpers', () {
    testWidgets('keeps the requested duration by default', (tester) async {
      final result = await resolveMotion(tester, const MediaQueryData());

      expect(result.reduceMotion, isFalse);
      expect(result.duration, AppDuration.normal);
    });

    testWidgets('reduces motion when animations are disabled', (tester) async {
      final result = await resolveMotion(
        tester,
        const MediaQueryData(disableAnimations: true),
      );

      expect(result.reduceMotion, isTrue);
      expect(result.duration, Duration.zero);
    });

    testWidgets('reduces motion for accessible navigation', (tester) async {
      final result = await resolveMotion(
        tester,
        const MediaQueryData(accessibleNavigation: true),
      );

      expect(result.reduceMotion, isTrue);
      expect(result.duration, Duration.zero);
    });
  });
}
