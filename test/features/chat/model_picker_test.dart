import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
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
    final models = ChatModelMode.fromCodexCatalog([
      const CodexModelInfo(
        slug: 'gpt-5.5',
        displayName: 'GPT-5.5',
        supportedReasoningEfforts: ['low', 'medium'],
      ),
      const CodexModelInfo(
        slug: 'gpt-5.4-mini',
        displayName: 'GPT-5.4 Mini',
        supportedReasoningEfforts: ['medium', 'high'],
      ),
    ]);

    await pumpPickerHost(tester, models: models);

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('GPT-5.5'), findsOneWidget);
    expect(find.text('GPT-5.4 Mini'), findsOneWidget);
    expect(find.text('Effort'), findsOneWidget);
    expect(find.text('GPT-5.5 Low'), findsOneWidget);
    expect(find.text('GPT-5.5 Medium'), findsOneWidget);
    expect(find.text('GPT-5.4 Mini Medium'), findsNothing);

    await tester.tap(find.text('GPT-5.4 Mini'));
    await tester.pumpAndSettle();

    expect(find.text('GPT-5.4 Mini Medium'), findsOneWidget);
    expect(find.text('GPT-5.4 Mini High'), findsOneWidget);
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
