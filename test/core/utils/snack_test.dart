import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/snack.dart';

void main() {
  final theme = ThemeData(useMaterial3: true);

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return captured;
  }

  SnackBar shownSnackBar(WidgetTester tester) =>
      tester.widget<SnackBar>(find.byType(SnackBar));

  testWidgets('neutral snack keeps the default theme styling', (tester) async {
    final context = await pumpHost(tester);
    context.showSnack('Saved');
    await tester.pump();

    expect(find.text('Saved'), findsOneWidget);
    final bar = shownSnackBar(tester);
    expect(bar.backgroundColor, isNull);
    expect(bar.duration, const Duration(milliseconds: 4000));
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('error tone uses errorContainer tokens and an icon', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    final cs = theme.colorScheme;
    var retried = false;
    context.showSnack(
      'Failed',
      tone: SnackTone.error,
      duration: const Duration(seconds: 7),
      action: SnackBarAction(label: 'Retry', onPressed: () => retried = true),
    );
    await tester.pump();

    final bar = shownSnackBar(tester);
    expect(bar.backgroundColor, cs.errorContainer);
    expect(bar.duration, const Duration(seconds: 7));
    expect(bar.action?.textColor, cs.onErrorContainer);
    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(icon.color, cs.onErrorContainer);
    expect(
      tester.widget<Text>(find.text('Failed')).style?.color,
      cs.onErrorContainer,
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('error tone keeps an explicit action text color', (tester) async {
    final context = await pumpHost(tester);
    context.showSnack(
      'Failed',
      tone: SnackTone.error,
      action: SnackBarAction(
        label: 'Undo',
        textColor: Colors.purple,
        onPressed: () {},
      ),
    );
    await tester.pump();
    expect(shownSnackBar(tester).action?.textColor, Colors.purple);
  });

  testWidgets('snacks queue by default', (tester) async {
    final context = await pumpHost(tester);
    context
      ..showSnack('First')
      ..showSnack('Second');
    await tester.pump();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('replaceCurrent hides the visible snack instead of queueing', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    context.showSnack('Copied');
    await tester.pump();
    context.showSnack('Copied again', replaceCurrent: true);
    // Let the hide animation of the first snack finish.
    await tester.pumpAndSettle();

    expect(find.text('Copied'), findsNothing);
    expect(find.text('Copied again'), findsOneWidget);
  });

  testWidgets(
    'messenger helper shows a toned snack and returns its controller',
    (tester) async {
      final context = await pumpHost(tester);
      final messenger = ScaffoldMessenger.of(context);
      final controller = messenger.showSnack('Deleted', tone: SnackTone.error);
      await tester.pump();

      expect(find.text('Deleted'), findsOneWidget);
      expect(
        shownSnackBar(tester).backgroundColor,
        theme.colorScheme.errorContainer,
      );
      controller.close();
      await tester.pumpAndSettle();
      expect(find.text('Deleted'), findsNothing);
    },
  );

  testWidgets('showSnackIfMounted is a no-op once unmounted', (tester) async {
    final context = await pumpHost(tester);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    expect(context.mounted, isFalse);
    context.showSnackIfMounted('Too late', tone: SnackTone.error);
    await tester.pump();
    expect(find.text('Too late'), findsNothing);
  });
}
