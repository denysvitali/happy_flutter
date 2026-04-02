import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/claude_model.dart';
import 'package:happy_flutter/features/chat/widgets/input_toolbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('single-model sessions hide the dropdown affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        InputToolbar(
          modelMode: ClaudeModel.defaultModel,
          availableModels: const [ClaudeModel.defaultModel],
          onShowModelPicker: () {},
          onShowProfilePicker: () {},
        ),
      ),
    );

    final modelChip = find.byType(ModelChip);
    expect(
      find.descendant(
        of: modelChip,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: modelChip,
        matching: find.byIcon(Icons.smart_toy_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('multi-model sessions show the dropdown affordance', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        InputToolbar(
          modelMode: ClaudeModel.sonnet,
          availableModels: ClaudeModel.availableForFlavor('claude'),
          onShowModelPicker: () {},
          onShowProfilePicker: () {},
        ),
      ),
    );

    final modelChip = find.byType(ModelChip);
    expect(
      find.descendant(
        of: modelChip,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: modelChip,
        matching: find.byIcon(Icons.auto_awesome_outlined),
      ),
      findsOneWidget,
    );
  });
}
