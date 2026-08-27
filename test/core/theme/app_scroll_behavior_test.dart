import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_scroll_behavior.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Future<ScrollPhysics> resolvePhysics(WidgetTester tester) async {
    late ScrollPhysics physics;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            physics = const AppScrollBehavior().getScrollPhysics(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return physics;
  }

  testWidgets('uses clamping physics on Linux', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    final physics = await resolvePhysics(tester);

    expect(physics, isA<ClampingScrollPhysics>());
    expect(physics.parent, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets('keeps bouncing physics on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final physics = await resolvePhysics(tester);

    expect(physics, isA<BouncingScrollPhysics>());
    expect(physics.parent, isA<AlwaysScrollableScrollPhysics>());
  });
}
