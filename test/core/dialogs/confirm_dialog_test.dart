import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/dialogs/confirm_dialog.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';

/// Pumps a button that opens [showConfirmDialog] with the given options and
/// records the resolved value in [results].
Future<void> _pumpLauncher(
  WidgetTester tester, {
  required List<bool> results,
  String? content,
  Widget? body,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                results.add(
                  await showConfirmDialog(
                    context,
                    title: 'Delete item',
                    content: content,
                    body: body,
                    confirmLabel: confirmLabel,
                    cancelLabel: cancelLabel,
                    isDestructive: isDestructive,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('places Cancel before a filled confirm verb', (tester) async {
    final results = <bool>[];
    await _pumpLauncher(
      tester,
      results: results,
      content: 'This cannot be undone.',
      confirmLabel: 'Delete',
    );

    expect(find.text('Delete item'), findsOneWidget);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    final cancel = find.widgetWithText(TextButton, 'Cancel');
    final confirm = find.widgetWithText(FilledButton, 'Delete');
    expect(cancel, findsOneWidget);
    expect(confirm, findsOneWidget);
    // Confirm sits on the right (trailing) side of Cancel.
    expect(
      tester.getCenter(confirm).dx,
      greaterThan(tester.getCenter(cancel).dx),
    );

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(results, [true]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Cancel and barrier dismissal resolve to false', (tester) async {
    final results = <bool>[];
    await _pumpLauncher(tester, results: results, confirmLabel: 'Delete');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(results, [false, false]);
  });

  testWidgets('destructive confirm is painted with ColorScheme.error', (
    tester,
  ) async {
    final results = <bool>[];
    await _pumpLauncher(
      tester,
      results: results,
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    final context = tester.element(find.byType(AlertDialog));
    final cs = Theme.of(context).colorScheme;
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Delete'),
    );
    expect(button.style?.foregroundColor?.resolve(<WidgetState>{}), cs.onError);
  });

  testWidgets('non-destructive confirm keeps the themed style', (tester) async {
    final results = <bool>[];
    await _pumpLauncher(tester, results: results);

    // Without a label the confirm verb falls back to the localized default.
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm'),
    );
    expect(button.style, isNull);
  });

  testWidgets('custom body and cancel label render', (tester) async {
    final results = <bool>[];
    await _pumpLauncher(
      tester,
      results: results,
      body: const Text('custom body', key: ValueKey('body')),
      cancelLabel: 'Stay',
      confirmLabel: 'Leave',
    );

    expect(find.byKey(const ValueKey('body')), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Stay'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });
}
