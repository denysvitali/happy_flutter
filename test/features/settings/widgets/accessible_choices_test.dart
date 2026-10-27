import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/views/ask_user_question_view.dart';
import 'package:happy_flutter/features/chat/tools/views/ask_user_question_widgets.dart';
import 'package:happy_flutter/features/settings/widgets/inline_theme_picker.dart';

void main() {
  testWidgets('theme choice exposes selection and supports keyboard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InlineThemePicker(
            currentMode: 'adaptive',
            onChanged: (value) => chosen = value,
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Auto')),
      matchesSemantics(
        label: 'Auto',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(chosen, 'adaptive');
    semantics.dispose();
  });

  testWidgets('question option exposes state and keyboard activation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptionChip(
            option: QuestionOption(
              label: 'Postgres',
              description: 'Relational',
            ),
            isSelected: true,
            isMultiSelect: false,
            isInteractive: true,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Postgres, Relational')),
      matchesSemantics(
        label: 'Postgres, Relational',
        isButton: true,
        isSelected: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
    semantics.dispose();
  });
}
