import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/views/terminal_command_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Matches the [SelectableText] rendering the command by its exact contents.
Finder _findCommand(String text) => find.byWidgetPredicate(
  (widget) => widget is SelectableText && widget.data == text,
);

String _commandOf(int lines) =>
    List<String>.generate(lines, (i) => 'line $i').join('\n');

void main() {
  group('TerminalCommandBar truncation', () {
    testWidgets('short commands render in full with no toggle', (tester) async {
      await tester.pumpWidget(
        _wrap(TerminalCommandBar(command: _commandOf(4))),
      );

      expect(_findCommand(_commandOf(4)), findsOneWidget);
      expect(find.textContaining('Show'), findsNothing);
    });

    testWidgets('long commands are capped and expandable', (tester) async {
      await tester.pumpWidget(
        _wrap(TerminalCommandBar(command: _commandOf(40))),
      );

      // Only the first maxLines (10) lines are rendered.
      expect(_findCommand(_commandOf(10)), findsOneWidget);
      expect(find.text('Show 30 more lines'), findsOneWidget);

      await tester.tap(find.text('Show 30 more lines'));
      await tester.pump();

      expect(_findCommand(_commandOf(40)), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);
    });

    testWidgets('a new command collapses again', (tester) async {
      await tester.pumpWidget(
        _wrap(TerminalCommandBar(command: _commandOf(40))),
      );
      await tester.tap(find.text('Show 30 more lines'));
      await tester.pump();
      expect(find.text('Show less'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(TerminalCommandBar(command: '${_commandOf(40)}\nextra')),
      );
      await tester.pump();

      expect(find.text('Show 31 more lines'), findsOneWidget);
    });
  });
}
