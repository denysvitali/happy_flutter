import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/widgets/app_linear_progress_indicator.dart';

void main() {
  testWidgets('owns animation without resolving a theme controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: AppLinearProgressIndicator()),
      ),
    );

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    final controller = indicator.controller!;
    expect(controller.isAnimating, isTrue);
    var ticks = 0;
    controller.addListener(() => ticks++);
    await tester.pump(const Duration(milliseconds: 30));
    expect(ticks, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    final ticksAtRemoval = ticks;
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, ticksAtRemoval);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('determinate updates stop animation and preserve progress', (
    tester,
  ) async {
    Widget tree(double? value) => MaterialApp(
      home: Center(
        child: AppLinearProgressIndicator(
          value: value,
          color: Colors.orange,
          backgroundColor: Colors.black,
          minHeight: 3,
          borderRadius: BorderRadius.all(Radius.circular(5)),
          semanticsLabel: 'Download',
          semanticsValue: 'Half complete',
        ),
      ),
    );

    await tester.pumpWidget(tree(null));
    final controller = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .controller!;

    await tester.pumpWidget(tree(0.5));
    final determinate = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(determinate.value, 0.5);
    expect(determinate.controller, isNull);
    expect(controller.isAnimating, isFalse);
    expect(determinate.color, Colors.orange);
    expect(determinate.backgroundColor, Colors.black);
    expect(determinate.minHeight, 3);
    expect(determinate.borderRadius, BorderRadius.circular(5));
    expect(determinate.semanticsLabel, 'Download');
    expect(determinate.semanticsValue, 'Half complete');

    await tester.pumpWidget(tree(null));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .controller,
      same(controller),
    );
    expect(controller.isAnimating, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives reparenting and respects TickerMode', (tester) async {
    final indicatorKey = GlobalKey();
    Widget tree({required bool moved, required bool enabled}) => MaterialApp(
      home: TickerMode(
        enabled: enabled,
        child: Row(
          children: [
            Expanded(
              child: moved
                  ? const SizedBox.shrink()
                  : AppLinearProgressIndicator(key: indicatorKey),
            ),
            Expanded(
              child: moved
                  ? AppLinearProgressIndicator(key: indicatorKey)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(tree(moved: false, enabled: true));
    final controller = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .controller!;
    var ticks = 0;
    controller.addListener(() => ticks++);

    await tester.pumpWidget(tree(moved: true, enabled: true));
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .controller,
      same(controller),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(ticks, greaterThan(0));

    await tester.pumpWidget(tree(moved: true, enabled: false));
    final mutedTicks = ticks;
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, mutedTicks);

    await tester.pumpWidget(tree(moved: true, enabled: true));
    await tester.pump(const Duration(milliseconds: 30));
    expect(ticks, greaterThan(mutedTicks));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route pop and interrupted switcher dispose spinning children', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final loading = ValueNotifier(true);
    addTearDown(loading.dispose);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    unawaited(
      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: loading,
              builder: (_, isLoading, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isLoading
                    ? const AppLinearProgressIndicator()
                    : const Text('Loaded'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    loading.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
