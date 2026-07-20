import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/models/settings.dart';
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
    expect(find.text('Fable'), findsOneWidget);
    expect(find.text('Sonnet'), findsOneWidget);
    expect(find.text('Opus'), findsOneWidget);
    expect(find.text('Effort'), findsOneWidget);
    // The effort levels are rendered as labels under a slider.
    expect(find.byType(Slider), findsOneWidget);
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
    // Drag the effort slider fully to the right → Max.
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(selected, 'opus:max');
  });

  testWidgets('fable effort selection emits the wire-format string', (
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
    await tester.tap(find.text('Fable'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(selected, 'fable:max');
  });

  test('fromString round-trips the fable tier and its effort variants', () {
    expect(ChatModelMode.fromString('fable'), ChatModelMode.fable);
    final fableHigh = ChatModelMode.fromString('fable:high');
    expect(fableHigh.modeString, 'fable:high');
    expect(fableHigh.modelSlug, 'fable');
    expect(fableHigh.reasoningEffort, 'high');
    expect(fableHigh.isClaude, isTrue);
    expect(fableHigh.isCustom, isFalse);
  });

  testWidgets('custom models can be removed from the picker', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = Settings()
      ..customModelModes = ['claude-opus-4-8', 'claude-sonnet-4-6'];
    List<String>? lastSaved;

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
                    (_) {},
                    settings: settings,
                    onCustomModelsChanged: (models) => lastSaved = models,
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

    expect(find.text('claude-opus-4-8'), findsOneWidget);
    expect(find.text('claude-sonnet-4-6'), findsOneWidget);

    // Each custom row exposes a remove button.
    final removeButtons = find.byIcon(Icons.close_rounded);
    expect(removeButtons, findsNWidgets(2));

    await tester.tap(removeButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('claude-opus-4-8'), findsNothing);
    expect(find.text('claude-sonnet-4-6'), findsOneWidget);
    expect(lastSaved, ['claude-sonnet-4-6']);
  });

  test('raw model normalization drops Claude effort modes for Codex', () {
    expect(ChatModelMode.normalizeRawForFlavor('opus:max', 'codex'), 'default');
    expect(
      ChatModelMode.normalizeRawForFlavor('MiniMax-M3', 'codex'),
      'default',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor('MiniMax-M3:high', 'codex'),
      'default',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor('claude-fable-5', 'codex'),
      'default',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor('anthropic/claude-opus-4-6', 'codex'),
      'default',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor('sonnet:high', 'codex'),
      'default',
    );
  });

  test('raw model normalization preserves known Codex models', () {
    expect(
      ChatModelMode.normalizeRawForFlavor('gpt-5.5:high', 'codex'),
      'gpt-5.5:high',
    );
    expect(ChatModelMode.fromString('gpt-5-codex').isCodex, isTrue);
    expect(
      ChatModelMode.normalizeRawForFlavor('gpt-5-codex', 'codex'),
      'gpt-5-codex',
    );
  });

  test('raw model normalization preserves Qwen Token Plan slugs for Codex',
      () {
        // The daemon's get-codex-models catalog only reports gpt-*; the
        // Token Plan slugs must survive normalization via the static
        // catalog extension, with and without a reasoning-effort suffix.
        for (final slug in qwenTokenPlanCodexModels) {
          expect(ChatModelMode.isKnownCodexModelString(slug), isTrue);
          expect(ChatModelMode.fromString(slug).isCodex, isTrue);
          expect(ChatModelMode.normalizeRawForFlavor(slug, 'codex'), slug);
          expect(
            ChatModelMode.normalizeRawForFlavor('$slug:high', 'codex'),
            '$slug:high',
          );
        }
      });

  test('raw model normalization preserves provider-owned strings', () {
    expect(
      ChatModelMode.normalizeRawForFlavor('claude-fable-5', 'claude'),
      'claude-fable-5',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor(
        'anthropic/claude-opus-4-6',
        'claude',
      ),
      'anthropic/claude-opus-4-6',
    );
    expect(ChatModelMode.normalizeRawForFlavor('GLM-5', 'claude'), 'GLM-5');
    expect(
      ChatModelMode.normalizeRawForFlavor('MiniMax-Text-01', 'claude'),
      'MiniMax-Text-01',
    );
  });
}
