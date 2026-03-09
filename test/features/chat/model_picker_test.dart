import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/claude_model.dart';
import 'package:happy_flutter/features/chat/widgets/picker_sheets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPickerHost(
    WidgetTester tester, {
    required List<ClaudeModel> models,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showModelPickerSheet(
                    context,
                    ClaudeModel.defaultModel,
                    models,
                    (_) {},
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('codex sessions only show the default model', (tester) async {
    await pumpPickerHost(
      tester,
      models: ClaudeModel.availableForFlavor('codex'),
    );

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Sonnet'), findsNothing);
    expect(find.text('Opus'), findsNothing);
  });

  testWidgets('claude sessions still show sonnet and opus', (tester) async {
    await pumpPickerHost(
      tester,
      models: ClaudeModel.availableForFlavor('claude'),
    );

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Sonnet'), findsOneWidget);
    expect(find.text('Opus'), findsOneWidget);
  });
}
