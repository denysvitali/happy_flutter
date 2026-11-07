import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/frosted_bottom_dock.dart';

void main() {
  testWidgets('publishes the dock height and lays the body under it', (
    tester,
  ) async {
    final inset = ValueNotifier<double>(0);
    addTearDown(inset.dispose);
    final dockHeight = ValueNotifier<double>(120);
    addTearDown(dockHeight.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FrostedBottomDock(
            inset: inset,
            body: const ColoredBox(
              key: ValueKey<String>('body'),
              color: Colors.blue,
            ),
            dock: ValueListenableBuilder<double>(
              valueListenable: dockHeight,
              builder: (context, h, _) => SizedBox(height: h),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(inset.value, 120);
    // The body fills the whole pane, including the area behind the dock.
    final body = tester.getRect(find.byKey(const ValueKey<String>('body')));
    final screen = tester.getRect(find.byType(FrostedBottomDock));
    expect(body.bottom, screen.bottom);
    expect(
      find.byKey(const ValueKey<String>('chat-frosted-dock')),
      findsOneWidget,
    );

    // A growing composer updates the inset after layout.
    dockHeight.value = 180;
    await tester.pump();
    await tester.pump();
    expect(inset.value, 180);
  });
}
