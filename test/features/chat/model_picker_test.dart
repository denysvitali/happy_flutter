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
    // The Claude picker now has up to 13 tiles (default + sonnet/opus +
    // 5 efforts each). Use a tall viewport so every tile is hit-testable.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    // Effort sub-list shows just the effort label.
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('High'), findsNothing);

    await tester.tap(find.text('GPT-5.4 Mini'));
    await tester.pumpAndSettle();

    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Sonnet'), findsNothing);
    expect(find.text('Opus'), findsNothing);
  });

  testWidgets('claude sessions show sonnet, opus, and effort levels', (
    tester,
  ) async {
    await pumpPickerHost(
      tester,
      models: ChatModelMode.availableForFlavor('claude'),
    );

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Sonnet'), findsOneWidget);
    expect(find.text('Opus'), findsOneWidget);
    expect(find.text('Effort'), findsOneWidget);
    // Sonnet is the first slug — its effort sub-list should be visible.
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('XHigh'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);

    // Tap Opus to switch to its effort sub-list.
    await tester.tap(find.text('Opus'));
    await tester.pumpAndSettle();
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);
  });

  testWidgets('claude effort selection emits the wire-format string', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
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
                    ChatModelMode.availableForFlavor('claude'),
                    (m) => selected = m.modeString,
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
    await tester.tap(find.text('Opus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    expect(selected, 'opus:high');
  });
}
