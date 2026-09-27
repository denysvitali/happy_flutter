import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/app_visibility_coordinator.dart';
import 'package:happy_flutter/core/widgets/app_circular_progress_indicator.dart';
import 'package:happy_flutter/core/widgets/app_focus_ticker_mode.dart';

void main() {
  setUp(() => AppFocusState.instance.setFocused(true));
  tearDown(() => AppFocusState.instance.setFocused(true));

  testWidgets('desktop focus loss mutes route animations without suspending', (
    tester,
  ) async {
    final coordinator = AppVisibilityCoordinator();
    var networkEdges = 0;
    void lifecycle(AppLifecycleState state) {
      coordinator.handleLifecycleState(
        state,
        onSuspend: () => networkEdges++,
        onResume: () => networkEdges++,
      );
    }

    await tester.pumpWidget(
      const AppFocusTickerMode(
        child: MaterialApp(home: Center(child: AppCircularProgressIndicator())),
      ),
    );
    final controller = tester
        .widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .controller!;
    var ticks = 0;
    controller.addListener(() => ticks++);
    await tester.pump(const Duration(milliseconds: 30));
    expect(ticks, greaterThan(0));

    lifecycle(AppLifecycleState.inactive);
    await tester.pump();
    final mutedTicks = ticks;
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, mutedTicks);
    expect(tester.binding.transientCallbackCount, 0);
    expect(coordinator.isSuspended, isFalse);
    expect(networkEdges, 0);

    lifecycle(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(ticks, greaterThan(mutedTicks));
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .controller,
      same(controller),
    );
    expect(networkEdges, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    lifecycle(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('starts muted when mounted in an unfocused app', (tester) async {
    AppFocusState.instance.setFocused(false);
    await tester.pumpWidget(
      const AppFocusTickerMode(
        child: MaterialApp(home: Center(child: AppCircularProgressIndicator())),
      ),
    );
    final controller = tester
        .widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .controller!;
    var ticks = 0;
    controller.addListener(() => ticks++);
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, 0);
    expect(tester.binding.transientCallbackCount, 0);

    AppFocusState.instance.setFocused(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(ticks, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
