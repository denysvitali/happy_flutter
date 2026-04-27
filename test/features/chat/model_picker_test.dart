import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';
import 'package:happy_flutter/features/chat/widgets/picker_sheets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPickerHost(
    WidgetTester tester, {
    required List<ChatModelMode> models,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showModelPickerSheet(
                    context,
                    ChatModelMode.defaultModel,
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

  testWidgets('codex sessions show OpenAI model and effort choices', (
    tester,
  ) async {
    await pumpPickerHost(
      tester,
      models: ChatModelMode.availableForFlavor('codex'),
    );

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('GPT-5.5 Medium'), findsOneWidget);
    expect(find.text('GPT-5.4 Medium'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('GPT-5.4 Mini Medium'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('GPT-5.4 Mini Medium'), findsOneWidget);
    expect(find.text('Sonnet'), findsNothing);
    expect(find.text('Opus'), findsNothing);
  });

  testWidgets('claude sessions still show sonnet and opus', (tester) async {
    await pumpPickerHost(
      tester,
      models: ChatModelMode.availableForFlavor('claude'),
    );

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Sonnet'), findsOneWidget);
    expect(find.text('Opus'), findsOneWidget);
  });
}
