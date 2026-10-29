import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/command_palette/command_item.dart';
import 'package:happy_flutter/features/command_palette/command_palette_overlay.dart';

void main() {
  Future<void> showPalette(
    WidgetTester tester,
    List<CommandItem> commands,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CommandPaletteOverlay(commands: commands, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty results safely ignore navigation and execution', (
    tester,
  ) async {
    var executions = 0;
    await showPalette(tester, [
      CommandItem(
        id: 'settings',
        title: 'Settings',
        action: () => executions++,
      ),
    ]);
    await tester.enterText(find.byType(TextField), 'zzzzzzzzzz');
    await tester.pump(const Duration(milliseconds: 150));

    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.enter,
    ]) {
      await tester.sendKeyEvent(key);
      expect(tester.takeException(), isNull);
    }
    expect(executions, 0);
  });

  testWidgets('Enter flushes pending search before executing', (tester) async {
    final executed = <String>[];
    await showPalette(tester, [
      CommandItem(
        id: 'first',
        title: 'First command',
        action: () => executed.add('first'),
      ),
      CommandItem(
        id: 'settings',
        title: 'Settings',
        action: () => executed.add('settings'),
      ),
    ]);
    await tester.enterText(find.byType(TextField), 'Settings');
    // Do not advance the debounce timer before executing.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(executed, ['settings']);
  });

  testWidgets('a new query selects its first result', (tester) async {
    final executed = <String>[];
    await showPalette(tester, [
      CommandItem(
        id: 'alpha',
        title: 'Alpha',
        action: () => executed.add('alpha'),
      ),
      CommandItem(
        id: 'beta',
        title: 'Beta',
        action: () => executed.add('beta'),
      ),
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(executed, ['alpha']);
  });

  testWidgets('Enter cannot execute stale results for an unmatched query', (
    tester,
  ) async {
    var executions = 0;
    await showPalette(tester, [
      CommandItem(
        id: 'settings',
        title: 'Settings',
        action: () => executions++,
      ),
    ]);
    await tester.enterText(find.byType(TextField), 'zzzzzzzzzz');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(executions, 0);
    expect(find.text('No commands found'), findsOneWidget);
  });
}
