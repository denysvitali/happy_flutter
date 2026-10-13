import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_inline_row.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: Center(child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('inline actions wrap labels at narrow widths and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;

    Widget action(double width) => _app(
      SizedBox(
        width: width,
        child: AppInlineAction(
          label: 'Show less',
          icon: Icons.expand_less,
          onPressed: () => taps++,
        ),
      ),
    );

    await tester.pumpWidget(action(208));
    final wideLabelHeight = tester.getSize(find.text('Show less')).height;
    final wideStyle = DefaultTextStyle.of(
      tester.element(find.text('Show less')),
    ).style;

    await tester.pumpWidget(action(120));
    final label = find.text('Show less');
    expect(tester.getSize(label).height, greaterThan(wideLabelHeight));
    expect(tester.widget<Text>(label).maxLines, isNull);
    expect(
      DefaultTextStyle.of(tester.element(label)).style.fontSize,
      wideStyle.fontSize,
    );
    expect(MediaQuery.textScalerOf(tester.element(label)).scale(1), 2);
    expect(tester.takeException(), isNull);

    await tester.tap(label);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('inline actions still shrink inside an unconstrained row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineAction(label: 'Copy', onPressed: () {}),
            AppInlineAction(
              label: 'Details',
              icon: Icons.expand_more,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(Row).first).width,
      lessThan(tester.view.physicalSize.width),
    );
  });
}
